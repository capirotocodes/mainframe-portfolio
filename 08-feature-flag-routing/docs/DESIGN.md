# Design — Feature-Flag Routing (FEATFLAG)

## Goal

A single batch load module that selects one of two execution paths —
**LEGACY** (current stable behaviour) or **NEW** (candidate behaviour) —
based purely on the EXEC `PARM`, with **no relink** needed to switch. This
is the z/OS-batch expression of a *feature flag* / progressive-delivery
pattern: the same module ships once, and operations turn the new path on
or off per run.

```
   PARM absent / anything else        -> LEGACY route  (flag off)
   PARM='NEW_BULK_EXTRACT=Y'           -> NEW route     (flag on)
```

The chosen route is announced with `WTO ... ROUTCDE=(11)` so it is visible
in JESMSGLG; both routes end RC 0 (both are "success" — the flag chooses
behaviour, not pass/fail).

## Why this artifact exists (honest lineage)

This grew out of an earlier skeleton named `FLAGDB2`, which was *intended*
to carry embedded DB2 (`EXEC SQL`) but never did — no DB2 subsystem was
available, so the SQL was stubbed out. Worse, its feature flag **did not
work**: it issued `GETMAIN RU` (which returns the acquired address in R1)
*before* reading the EXEC parm — and the parm pointer lives in R1 on entry.
By the time it inspected the parm it was reading the freshly-zeroed work
area, so the length was always 0 and it **always took the legacy path**,
regardless of the flag. Its "validated RC 0" proved nothing, because both
paths returned 0 unconditionally.

`FEATFLAG` is the rehabilitated version: honestly named for what it does,
with the bug fixed and each path producing observable output.

## The bug, and the fix

The rule it violated: **the EXEC parm pointer is in R1 at entry, and any
service that loads R1 (GETMAIN, many macros) destroys it.** Save R1 into a
non-volatile register *first*.

```
         @ENTER
         LR    R10,R1        preserve parm pointer BEFORE any service
         WTO   'FEATFLAG STARTING',ROUTCDE=(11)   (WTO clobbers R1; R10 safe)
         ...
         L     R2,0(,R10)    R2 -> parm string (length halfword + text)
         LH    R3,0(,R2)     parm length
```

`FEATFLAG` also drops the `GETMAIN`/dynamic-save-area machinery entirely —
routing on a parm needs no work area. It uses the portfolio's standard
`@ENTER`/`@LEAVE` linkage (artifact 1), which removes the unsafe prolog
that caused the original's earlier S0C4 abends as well.

## Flow

1. `@ENTER` (R12 base, R13 → save area). `LR R10,R1` to keep the parm
   pointer. WTO a start banner.
2. If no parm list (R10 = 0) → LEGACY.
3. Load the parm string (`0(R10)`), read its halfword length. If shorter
   than the 18-byte flag value → LEGACY.
4. `CLC` the parm text against `NEW_BULK_EXTRACT=Y`. Equal → NEW; else →
   LEGACY.
5. Each path WTOs its name and `@LEAVE RC=0`.

## Register / addressing conventions

- R12 base, R13 → save area (standard `@ENTER` linkage).
- R10 → parm list (preserved across the banner WTO), R2 → parm text,
  R3 = parm length.
- `AMODE 31 / RMODE ANY`; non-reentrant, consistent with the portfolio.

## Edge cases / what could go wrong

- **No PARM** — `R10 = 0` guard routes to LEGACY rather than dereferencing
  a null parm list.
- **Short PARM** — a length below 18 cannot hold the flag value, so the
  `CLC` is skipped and LEGACY is taken (no read past the parm text).
- **R1 lifetime** — the defining lesson: the parm pointer is captured
  before any R1-clobbering service runs.
- **Both paths succeed** — RC 0 each; the routing decision is reported by
  WTO, not by the return code (a feature flag selects behaviour, not
  outcome).

## What this is — and isn't

It **is** a clean, working demonstration of parm-driven routing / feature
flagging in z/OS batch: one module, two paths, switched by JCL with no
rebuild. It is deliberately small. It is **not** a DB2 application and no
longer pretends to be; the NEW path is the place real new logic (DB2 or
otherwise) would go once the surrounding flow is in place.

## Verified run

Assembled + linked clean (`ASMA90` RC 0, `IEWL` RC 0) and run both ways on
the author's z/OS system. The job log (JESMSGLG, `ROUTCDE=11`):

```
+FEATFLAG STARTING
+FEATFLAG ROUTE=LEGACY (flag off)
 IEF142I FFRUN LEGACY - STEP WAS EXECUTED - COND CODE 0000
+FEATFLAG STARTING
+FEATFLAG ROUTE=NEW (flag on)
 IEF142I FFRUN NEW - STEP WAS EXECUTED - COND CODE 0000
```

STEP1 (no PARM) takes LEGACY; STEP2 (`PARM='NEW_BULK_EXTRACT=Y'`) takes
NEW — proving the flag now actually routes (the original's defect).

## On-system build and run

`jcl/BUILDFF.jcl` — assemble (`ASMA90`; `SYSLIB` = `ANDRE.EPE.MACLIB` +
`SYS1.MACLIB` + `SYS1.MODGEN`) and bind (`IEWL` → `ANDRE.EPE.LOAD`,
`MODE AMODE(31),RMODE(ANY)`).

`jcl/RUNFF.jcl` — STEP1 runs `PGM=FEATFLAG` with no PARM (LEGACY), STEP2
with `PARM='NEW_BULK_EXTRACT=Y'` (NEW); both expect RC 0 and announce their
route by WTO.
