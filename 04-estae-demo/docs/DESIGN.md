# Design — ESTAE Recovery Demo (ESTDEMO)

## Goal

A batch HLASM program (`ESTDEMO`) that **deliberately triggers an abend**,
catches it in an **ESTAE recovery routine**, formats the key **SDWA** fields
into a readable diagnostic, and then either **retries** to a clean resume
point or **percolates** the abend — selected at run time by a PARM. It pairs
directly with the author's dump/listing debugging strength: instead of
reading the SDWA out of a dump, the program reads it live and reports it.

```
   PARM='RETRY' | 'PERCOLATE'
        |
        v
   @ENTER  ->  parse PARM  ->  ESTAEX (establish RECVEXIT, PARAM=workarea)
        |
        v
   set up invalid packed data  ->  CVB/AP  ->  S0C7  (data exception)
        |
        v   (control -> RECVEXIT, R1 -> SDWA)
   RECVEXIT: re-establish addressability (SDWAPARM) -> format SDWA -> WTO
             SETRP RETRY  : RC=4, RETADDR=RETRYPT, restore regs
             SETRP PERCOL : RC=0  (do not suppress), DUMP=NO
        |
        +-- RETRY     -> RETRYPT: WTO "RECOVERED" -> @LEAVE RC=0  (step RC 0)
        +-- PERCOLATE -> abend not suppressed       (step ends S0C7)
```

## Conventions

- z/OS HLASM, **AMODE 31, RMODE ANY**, problem state, key 8.
- Single CSECT `ESTDEMO`. Standard OS linkage via `@ENTER`/`@LEAVE`
  (artifact 1); hex formatting via `@HEXOUT`.
- No data-set I/O: all output is **`WTO`** (see "Why WTO"). This is what lets
  the program stay cleanly `RMODE ANY` — there is no below-the-line DCB to
  GETMAIN/copy as in artifacts 2 and 3.
- SYSLIB concatenation: `ANDRE.EPE.MACLIB` (personal macros) ahead of
  `SYS1.MACLIB` + `SYS1.MODGEN` (IBM `ESTAEX`/`SETRP`/`IHASDWA`).

## PARM selection

`EXEC PGM=ESTDEMO,PARM='RETRY'` or `PARM='PERCOLATE'`.

- R1 -> parm pointer -> halfword length + text.
- Match on the first character, case as supplied: `R` -> RETRY, `P` ->
  PERCOLATE. A single byte `MODEFLAG` records the chosen path so both the
  recovery routine and the mainline can test it.
- Missing / empty / unrecognized PARM -> `WTO` diagnostic and **RC 8**, no
  abend established (nothing to demonstrate without a valid mode).

## Register plan

| Reg | Role |
|-----|------|
| R12 | program base (established by `@ENTER`) |
| R13 | save area (chained by `@ENTER`) |
| R11 | recovery routine's base (re-established from `SDWAPARM`) |
| R2  | SDWA base in the recovery routine (`USING SDWA,R2`) |
| R3-R5 | scratch for formatting SDWA fields |
| R6  | link register for the WTO helper |
| R0,R1,R14,R15 | volatile across `@HEXOUT`, `WTO`, `ESTAEX`, `SETRP` |

## Establishing the recovery routine

`ESTAEX RECVEXIT,PARAM=WORKAREA,...` is used in preference to plain `ESTAE`
because the program is AMODE 31: `ESTAEX` is the current macro, callable in
31-bit mode, and supported for above-the-line callers.

- **PARAM=WORKAREA** — the address passed is delivered to the exit in the
  SDWA field `SDWAPARM`. The exit uses it to re-establish its own
  addressability. This is the central teaching point: a recovery routine
  gets control with an **unknown** base register, so it must not assume the
  mainline's `R12` survived — it loads its base from the parameter it was
  given.
- The exit address `RECVEXIT` is `AL4`-resolvable in the same CSECT.
- The token returned by `ESTAEX` is saved so the mainline can cancel the
  recovery (`ESTAEX 0`) on the normal RETRY exit before `@LEAVE`.

## Triggering the abend (S0C7)

A small static area holds **invalid packed-decimal** data — a field whose
digit nibbles are not all valid decimal digits (e.g.
`BADPACK DC X'1234ABCD'`, where `A`/`B`/`C` are not `0`-`9`). A `CVB` (or
`AP`) against that field raises a **data exception (S0C7)**. The failing
instruction is isolated on its own line so the listing offset is obvious and
matches the address the recovery routine reports.

## The recovery routine (RECVEXIT)

Entered by RTM with R0/R1 conventions per `ESTAEX`: **R1 -> SDWA** (when one
is provided). Steps:

1. **Addressability** — `USING SDWA,R2` (R2 from R1); load R11 (recovery
   base) from `SDWAPARM` so labels and the WTO helper resolve. Handle the
   "no SDWA" case (R0 = X'0C' / R15 flag per the macro) defensively with a
   bare `WTO` and percolate.
2. **Format the SDWA** (with `@HEXOUT`) into a WTO report — intended fields
   (exact `IHASDWA` spellings pinned against the live macro at
   implementation):
   - completion (abend) code — `SDWACMPC`
   - reason code — `SDWACRC`
   - PSW at error — `SDWAEC1`
   - failing instruction address — derived from the PSW
   - interruption code / ILC — `SDWAINC1` / `SDWAILC1`
   - GPRs 0-15 at the time of error — `SDWAGRSV`
3. **Decide** via `SETRP` on `MODEFLAG`:
   - **RETRY**: `SETRP RC=4,RETADDR=RETRYPT,RETREGS=YES,FRESDWA=YES`
     (request retry, restore registers, free the SDWA).
   - **PERCOLATE**: `SETRP RC=0,DUMP=NO` (let RTM continue abend
     processing; do not request a dump — installation suppresses dumps, and
     the point of the artifact is the program's own report).
4. Return to RTM (`@LEAVE`-style restore of the exit's caller regs, `BR 14`).

## Retry resume point (RETRYPT)

Reached only on the RETRY path. With `RETREGS=YES`, registers are restored
from the SDWA, so `RETRYPT` first re-establishes the mainline base, cancels
the ESTAE (`ESTAEX 0`), issues `WTO 'ESTDEMO: RECOVERED, CONTINUING'`, and
falls into `@LEAVE RC=0`. The step ends **RC 0**, proving the abend was
fully handled and execution continued past the failure.

## Why WTO (not a report dataset)

- A recovery routine runs in a constrained environment; opening QSAM inside
  it (needed for the percolate path, which never returns to the mainline) is
  fragile. `WTO` is always available.
- On this system `TPUT` abends **S15D** under the TMP; `WTO` is the proven
  reliable output path. Each `WTO` uses **`ROUTCDE=(11)`** so the lines
  appear in the job log (JESMSGLG); without it they route to console only.
- No DCB means no below-the-line storage dance — the program stays
  `RMODE ANY` with no `MODE=31`/`GETMAIN LOC=BELOW` machinery.
- Multi-line output: either a multi-line `WTO` (connected lines) or a short
  series of single-line `WTO`s through one helper; the register block is the
  widest part and is split across lines that each fit the WTO text limit.

## Return codes / step outcomes

| Mode | Outcome |
|------|---------|
| RETRY | Recovery formats SDWA, retries, continues; step ends **RC 0**. |
| PERCOLATE | Recovery formats SDWA, percolates; step ends with **S0C7** (abend not suppressed — the failure is reported, not hidden). |
| Bad/again | Invalid PARM -> WTO + **RC 8**, no recovery established. |

## Edge cases / what could go wrong

- **No SDWA provided** — RTM may enter the exit without an SDWA (storage
  shortage). The exit checks the macro's "no SDWA" indicator and percolates
  with a bare `WTO` rather than dereferencing R1.
- **Recurring abend in the exit** — the recovery routine does the minimum
  (format + WTO + SETRP) and touches only its own work area, so it cannot
  re-drive itself into a recursion RTM would have to break.
- **PERCOLATE leaves the ESTAE active** — that is correct; RTM removes the
  recovery on percolate as it unwinds.
- **RETRY register state** — `RETREGS=YES` restores the GPRs from the SDWA,
  so `RETRYPT` must re-establish its base explicitly (it does) rather than
  trust whatever was live at the abend.
- **Dumps suppressed** — `IEA848I NO DUMP` is installation policy here;
  `DUMP=NO` on percolate avoids requesting one that would not be produced.
  The program's own SDWA report is the diagnostic.
- **Wrong SDWA field name** — fails at **assembly** (clean `ASMAxxxE`), never
  as a runtime surprise; field spellings are pinned against the live
  `IHASDWA` during implementation.

## On-system build

JCL in `../jcl/` (to be written):

1. **ASM** — `ASMA90`, `PARM='OBJECT,NODECK,LIST,XREF(SHORT)'`; SYSLIB =
   `ANDRE.EPE.MACLIB` + `SYS1.MACLIB` + `SYS1.MODGEN`; SYSIN =
   `ANDRE.EPE.ASM(ESTDEMO)`.
2. **LKED** — `IEWL`, AMODE 31 / RMODE ANY, link to
   `ANDRE.EPE.LOAD(ESTDEMO)`.
3. **RUN** — two steps so one job shows both paths:
   - `//RETRY  EXEC PGM=ESTDEMO,PARM='RETRY'`
   - `//PERC   EXEC PGM=ESTDEMO,PARM='PERCOLATE',COND=EVEN`
   each with `SYSUDUMP DD SYSOUT=*` (harmless though suppressed).

Built and run via the Zowe loop (upload `src/ESTDEMO.asm` as member
`ESTDEMO`, submit, read the spool). Cannot be assembled locally.

### Verification

- Assemble clean (severity 0-4), link RC=0.
- **RETRY step**: completes **RC 0**; JESMSGLG shows the formatted SDWA WTO
  followed by the "RECOVERED, CONTINUING" line.
- **PERCOLATE step**: ends with **S0C7**; JESMSGLG shows the same formatted
  SDWA WTO, and the system abend confirms the recovery let the failure
  percolate rather than swallowing it.
- **Cross-check the report against truth:** the abend code reported by the
  program (`SDWACMPC`) must read as `0C7`, and the failing-instruction
  address it formats must match the offset of the `CVB`/`AP` in the assembly
  listing — confirming the SDWA was read correctly, not just plausibly.
