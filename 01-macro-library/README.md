# 01 — Personal Macro Library

A curated set of structured-programming and utility macros for HLASM,
packaged as a macro library (SYSLIB PDS members on z/OS).

## Purpose

Provide reusable, readable macros that make HLASM source look and behave
like structured code, plus a couple of everyday utilities — and in doing so
demonstrate command of the macro language itself.

## Macros provided

| Macro | Role |
|-------|------|
| `@ENTER` / `@LEAVE` | Standard entry/exit linkage (save area, base, return). |
| `@IF` / `@ELSE` / `@ENDIF` | Structured conditional execution. |
| `@DO` / `@ENDDO` | Structured loop construct. |
| `@HEXOUT` | Convert a value to printable hex. |
| `@PCALL` | Parameterized call with standard linkage. |

## HLASM techniques demonstrated

- Macro definition and expansion (`MACRO`/`MEND`).
- Conditional assembly (`AIF`/`AGO`, `SETA`/`SETB`/`SETC`).
- Unique label generation with `&SYSNDX`.
- Nesting state tracked via `GBLA` global counters (for matched
  `@IF`/`@ENDIF`, `@DO`/`@ENDDO`).
- Diagnostics with `MNOTE` (severity 8 = error, 4 = warning).

## Control blocks / services used

None directly — this artifact is pure macro/conditional-assembly work.
Generated code uses standard OS linkage conventions.

## Contents

- `src/` — the macro members: `@ENTER`, `@LEAVE`, `@IF`, `@ELSE`,
  `@ENDIF`, `@DO`, `@ENDDO`, `@HEXOUT`, `@PCALL`, and the internal helper
  `@XINVB`.
- `examples/DEMOSP.asm` — a demo that uses every macro: sums 1..10 with a
  top-tested `@DO WHILE`, tallies even/odd with `@IF`/`@ELSE`/`@ENDIF`,
  runs a bottom-tested `@DO`/`@ENDDO UNTIL`, formats results with
  `@HEXOUT`, calls an external `DOUBLE` routine via `@PCALL`, and reports
  with `WTO`.
- `jcl/BUILDEX.jcl` — assemble + link-edit + run for the demo.
- `docs/DESIGN.md` — design rationale and the conditional-assembly mechanics.

## Build instructions

1. Upload each `src/*.mac` member into a macro PDS as a member **without
   extension** (e.g. `ANDRE.EPE.MACLIB(@ENTER)`). FB 80.
2. Upload `examples/DEMOSP.asm` as `ANDRE.EPE.ASM(DEMOSP)`.
3. Pre-allocate a load library `ANDRE.EPE.LOAD`.
4. Edit the HLQ datasets in `jcl/BUILDEX.jcl` to match your system and
   submit it. The macro PDS is concatenated ahead of `SYS1.MACLIB` on the
   assembler `SYSLIB` DD.

Verified run (system ZS31, all steps RC 0): `WTO` of
`DEMOSP: SUM=00000037 DBL=0000006E` (sum of 1..10 = 55 = `X'37'`, doubled
= 110 = `X'6E'`) in the job log. This exercises every macro, including the
structured `@IF`/`@ELSE`/`@DO`/`@ENDDO` and `@PCALL`'s external call.

> Status: **Complete** — all 10 macros in `ANDRE.EPE.MACLIB`; `DEMOSP`
> assembled, linked, and run on system ZS31 (RC 0).
