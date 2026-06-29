# Design — ESTAE Recovery Demo (ESTDEMO)

## Goal

A single batch HLASM program that **deliberately abends, recovers in an
ESTAEX recovery routine, formats the key SDWA diagnostic fields, and
reports them** — then takes one of three recovery actions chosen at run
time by the EXEC `PARM`:

```
   PARM=RETRY  (default)  abend -> recover -> retry once -> step RC 0
   PARM=PERC              abend -> recover -> percolate   -> step S0C7
   PARM=LOOP              abend -> recover -> re-drive the failing
                          instruction under a BOUNDED retry counter;
                          after MAXRETRY attempts, stop and percolate
```

One program demonstrates the halves of recovery-routine design and pairs
directly with the author's debugging strength: the same SDWA fields a
sysprog reads in a dump are read here in code, live, at the moment of
failure. The LOOP mode demonstrates the **production-critical** part — a
retry that re-drives a *persistent* failure must be bounded, or it loops
forever; see "Bounded retry" below.

## Why these choices

- **ESTAEX, not ESTAE.** ESTAEX is the modern form: AMODE-31 and
  cross-memory clean, and IBM-preferred for new code. The program is
  `AMODE 31`, so ESTAEX is the natural fit; ESTAE's addressing
  restrictions would be a step backwards.
- **WTO, not QSAM, for output.** The recovery routine runs in a
  restricted environment; doing QSAM `PUT` inside a recovery exit is
  fragile. `WTO ROUTCDE=(11)` is the conventional, robust way for a
  recovery routine to talk, and it writes to JESMSGLG where the evidence
  survives even on a system that suppresses dumps (an installation-wide
  reality on the author's box, where `TPUT` also abends S15D). The WTO is
  therefore the real deliverable, not a fallback.
- **One CSECT, `AMODE 31 / RMODE ANY`.** There is no DCB, so none of the
  OPEN-above-the-line / S0C4 trap that forces RMODE 24 in artifacts 3 and
  5 applies here. The module is free to load above the 16M line.
- **Base register passed through `PARAM`.** A recovery exit gets control
  with the registers RTM hands it — not the mainline base. Rather than
  rederive addressability from the entry point, the mainline stashes its
  base (R12) and the retry resume address in a parameter area and points
  ESTAEX's `PARAM=` at it. The exit reloads R12 from there and regains
  full addressability to every program constant and message with one
  `USING`.

## Control blocks / services used

| Item | Role |
|------|------|
| `ESTAEX` | Establish (and later cancel) the recovery routine; `TERM=YES` so the exit also covers task/address-space termination. |
| **SDWA** (`IHASDWA`) | System Diagnostic Work Area — the recovery routine reads the abend code, PSW, and reason code from it. |
| `SETRP` | Set return parameters in the SDWA: `RC=4` + `RETADDR` + `RETREGS=YES` to retry, or `RC=0` to percolate; `FRESDWA=YES` on retry. |
| `WTO` | Report the diagnostics (`ROUTCDE=(11)` → JESMSGLG); list/execute form for the lines that carry variable hex. |
| `@ENTER`/`@LEAVE`/`@HEXOUT` | Portfolio macros (artifact 1) — mainline linkage and binary-to-EBCDIC-hex formatting. |

## Mainline flow

1. `@ENTER` (base R12, R13 → save area). Parse `PARM`: R1 → parm list,
   the parm string is a halfword length followed by text. `PARM=PERC` →
   mode `P`; `PARM=LOOP` → mode `L`; blank or anything else → mode `R`
   (retry once). WTO a start banner naming the mode.
2. Build the recovery parameter area `RECAREA` (mapped by the `RECPARM`
   DSECT): eyecatcher, mode, **saved base (R12)**, the retry-once resume
   address `A(RESUME)`, the loop resume address `A(ABENDPT)`, and a zeroed
   retry counter.
3. `ESTAEX RECEXIT,PARAM=RECAREA,TERM=YES`. Check R15 — nonzero ⇒ WTO an
   error and `@LEAVE RC=8` (establish failed).
4. Force a **S0C7 data exception** at label `ABENDPT`: `AP` a field
   preloaded with invalid packed data (`X'C1C2C3C4'`). This is the abend,
   and `ABENDPT` is where LOOP mode resumes to re-fail.
5. `RESUME` (retry-once lands here, registers restored): cancel the
   recovery with `ESTAEX 0`, WTO "recovered via retry", `@LEAVE RC=0`.

## Recovery exit (RECEXIT)

Entry is the RTM protocol, **not** `@ENTER`:

- R0 = 0 if an SDWA is present, 12 if not; R1 → SDWA; R2 → the `PARAM`
  area; R13 → a 200-byte work area provided by RTM; R15 = entry point.
- `USING RECPARM,R2` → reload `L R12,RPBASE` → `USING ESTDEMO,R12`, which
  re-establishes addressability to the whole program.
- **No-SDWA guard:** the *only* documented no-SDWA indicator is
  **R0 = 12** (R1 then holds the abend code, not an address). The test is
  `C R0,=F'12' / BE`, **not** "any nonzero R0" — RTM also passes other
  SDWA-present codes (0 and, observed on this system, **16**), all of
  which carry a valid SDWA address in R1. When there is no SDWA, `SETRP`
  is impossible, so the exit WTOs a note and percolates (R15 = 0)
  regardless of the requested mode.
- With an SDWA, format and WTO three diagnostics via `@HEXOUT`:
  - `SDWAABCC` — abend completion code (observed `840C7000`: the `0C7`
    system completion code with RTM flags in the high byte),
  - `SDWAEC1` — the PSW at the error; its low 31 bits are the failing
    instruction address,
  - `SDWAGR14` — GPRs 14 and 15 at the time of error (two contiguous
    fullwords from `SDWAGRSV`).

  The raw diagnostic words are shown and each is labelled with the
  IHASDWA field it came from, rather than bit-decoding every subfield.
  All 16 time-of-error GPRs are available in `SDWAGRSV` (a talking point;
  only R14–R15 are printed). The abend *reason* code (`SDWACRC`) is
  deliberately not shown: it lives in an IHASDWA recording-extension
  DSECT, not the base `SDWA`, so `USING SDWA` does not reach it — and for
  a program check it is zero anyway.
- Decide from the mode:
  - **RETRY (R):** `SETRP RC=4,RETADDR=(A(RESUME)),RETREGS=YES,FRESDWA=YES,
    WKAREA=(Rsdwa)` — RTM restores the registers from `SDWAGRSV` (so R12
    base and R13 save area are valid again at `RESUME`) and resumes there,
    *past* the failing instruction. One clean retry, then RC 0.
  - **PERCOLATE (P):** WTO a note, `SETRP RC=0,WKAREA=(Rsdwa)` — RTM
    continues the abend and the step ends S0C7.
  - **LOOP (L):** bump the retry counter in `RECAREA`; WTO it. If it is
    still within `MAXRETRY`, `SETRP RC=4,RETADDR=(A(ABENDPT))` to re-drive
    the *same* failing instruction — which fails again, re-entering the
    exit. Once the counter exceeds `MAXRETRY`, WTO "retry limit hit" and
    `SETRP RC=0` to percolate. The counter lives in the (static) `RECAREA`
    so it survives across retries.
- Return to RTM via `BR R14`.

## Bounded retry (the production-safety point)

A recovery routine that retries by resuming at the instruction that just
failed will loop **forever** if the failure is persistent — a runaway abend
loop that burns CPU until the job is cancelled or hits its time limit. LOOP
mode demonstrates the fix every production recovery routine needs: a
**retry counter** (here in the parameter area, capped at `MAXRETRY=3`).
Within the limit it re-drives the failure; past it, it stops retrying and
percolates. RETRY mode doesn't hit this because it resumes *past* the
failure (one clean retry) — but any routine that retries the failing
operation itself must bound it. Real recovery code would also cut a LOGREC
record (`SETRP RECORD=YES`) on each pass.

## Return-code / outcome contract

| Run | Outcome |
|-----|---------|
| `PARM=RETRY` (or blank) | recover → retry once → step **RC 0** |
| `PARM=PERC` | recover → percolate → step **abends S0C7** (diagnostics already in the joblog) |
| `PARM=LOOP` | re-drive the failure `MAXRETRY` times → guard stops → percolate → step **abends S0C7** |
| No SDWA at recovery | forced percolate (cannot retry without an SDWA) |
| ESTAEX establish fails | WTO error, `@LEAVE RC=8` (no abend forced) |

## Register / addressing conventions

- Mainline: R12 base, R13 → save area (standard `@ENTER` linkage), R5 →
  `RECAREA` while it is built.
- Recovery exit: R3 → SDWA, R12 → reloaded program base, R4 → retry
  resume address. The exit manages its own registers; it issues no
  `@ENTER` and chains no save area (it runs to a `SETRP` + `BR R14`).

## Edge cases / what could go wrong

- **No SDWA** — guarded; the exit percolates rather than touch a
  non-existent SDWA or attempt an impossible retry.
- **ESTAEX establish failure** — checked on R15 before the abend is
  forced, so the program never abends without a recovery routine in place.
- **Recovery routine must not itself abend** — it does only WTO and
  storage-to-storage `@HEXOUT`; no I/O, no callable services that could
  fail and percolate through the very routine meant to recover.
- **Retry register validity** — `RETREGS=YES` restores the mainline
  registers from `SDWAGRSV`, so `RESUME` runs with a valid base and save
  area; the program does not assume them.
- **Non-reentrant** — static save area, flag, and WTO list forms,
  consistent with the rest of the portfolio (documented choice).
- **`TERM=YES`** — the exit is also driven for task / address-space
  termination, not only program checks.

## On-system build and run

`jcl/BUILDEST.jcl` — assemble (`ASMA90`; `SYSLIB` = `ANDRE.EPE.MACLIB` +
`SYS1.MACLIB` + `SYS1.MODGEN`) and bind (`IEWL` → `ANDRE.EPE.LOAD`,
`MODE AMODE(31),RMODE(ANY)`).

`jcl/RUNEST.jcl` — STEP1 `PARM=RETRY` (expect RC 0), STEP2 `PARM=PERC`
(expect abend S0C7), STEP3 `PARM=LOOP` (expect bounded retries then abend
S0C7). Each step has a `SYSUDUMP` DD for portability; note that on the
author's system dumps are suppressed installation-wide, so the WTO
diagnostics in JESMSGLG carry the real evidence.

## Verified run

Assembled + linked clean (`ASMA90` RC 0, `IEWL` RC 0) and run on the
author's z/OS system. The job log (JESMSGLG, `ROUTCDE=11`), diagnostic
lines elided for brevity:

```
+ESTDEMO STARTING - RETRY MODE
+ESTDEMO - FORCING S0C7 NOW
+ESTDEMO - RECOVERED VIA RETRY, CONTINUING
 IEF142I ESTRUN RETRY - STEP WAS EXECUTED - COND CODE 0000
+ESTDEMO STARTING - PERCOLATE MODE
+ESTDEMO - FORCING S0C7 NOW
+ESTDEMO RECOVERY - PERCOLATING ABEND
 IEF450I ESTRUN PERC - ABEND=S0C7 U0000 REASON=00000000
+ESTDEMO STARTING - LOOP MODE
+ESTDEMO - FORCING S0C7 NOW
+00000001=RETRY COUNT (LOOP MODE)
+00000002=RETRY COUNT (LOOP MODE)
+00000003=RETRY COUNT (LOOP MODE)
+00000004=RETRY COUNT (LOOP MODE)
+ESTDEMO RECOVERY - RETRY LIMIT HIT
 IEF450I ESTRUN LOOP - ABEND=S0C7 U0000 REASON=00000000
```

RETRY ends `COND CODE 0000`; PERC ends `ABEND=S0C7`. LOOP re-drives the
failing `AP` three times (the timestamps advance, confirming it actually
re-fails each pass), then the guard fires at attempt 4 (`> MAXRETRY`) and
percolates — a runaway abend loop, bounded. Each recovery entry also prints
`SDWAABCC`=`840C7000` (the `0C7`), the PSW (`…90900C16`, pointing at the
`AP`), and the GPRs (elided above).

## Debugging lessons (shaken out on the real system)

1. **The no-SDWA test must check for 12, not "nonzero."** The first
   working build percolated *both* ways and never printed the SDWA fields:
   the recovery routine was entered with **R0 = 16**, and a `BNZ` no-SDWA
   test treated that as "no SDWA." RTM actually passes 16 (and other
   codes) *with* a valid SDWA in R1; only **R0 = 12** means no SDWA.
   Instrumenting the exit to WTO R0/R1 made it obvious (R0=`00000010`,
   R1=`109016D8`, a real address). Fix: `C R0,=F'12' / BE NOSDWA`.
2. **`SDWACRC` is not in the base SDWA DSECT.** Referencing the reason
   code gave `ASMA307E No active USING for SDWACRC` — it is mapped in a
   recording-extension DSECT, not the base `SDWA` covered by `USING SDWA`.
   Replaced with `SDWAGR14` (base SDWA); reason code is 0 for a program
   check regardless.
3. **A trailing comment bled into column 72.** A clarifying comment on a
   `BE` line ran past column 71, so HLASM read column 72 as a continuation
   indicator and flagged `ASMA144E Begin-to-continue columns not blank` —
   which silently dropped the build to **RC 8**, skipped the link
   (`COND=(4,LE,ASM)`), and left the *previous* load module in place so a
   rerun looked fine. Always confirm the build is RC 0 (link ran) before
   trusting a run. Fix: move prose onto `*` comment lines.
4. **`DROP` what you still use.** An early version dropped the `RECPARM`
   base register right after reloading the program base, then referenced
   `RPFLAG`/`RPRESUME` — `ASMA307E No active USING`. The parameter area
   stays addressed (via R2) for the life of the exit.
