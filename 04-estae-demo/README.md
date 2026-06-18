# 04 — ESTAE Recovery Demo

A batch HLASM program that deliberately triggers an abend, recovers in an
ESTAE recovery routine, formats key SDWA fields, and reports what
happened — with both RETRY and PERCOLATE variants.

## Purpose

Demonstrate recovery routine design and SDWA analysis — pairing directly
with deep dump/listing debugging skills — by causing a controlled failure
(e.g., S0C7 data exception) and handling it cleanly.

## Control blocks / services used

- **`ESTAE`** — establish the recovery routine.
- **SDWA** — System Diagnostic Work Area; the recovery routine inspects
  abend code, PSW, registers, and failing instruction address.
- **`SETRP`** — set return parameters to choose RETRY vs PERCOLATE.
- IBM macros: `ESTAE`, `SETRP`, `IHASDWA` (SDWA DSECT).

## Variants

- **RETRY** — recovery routine requests a retry at a clean resume point and
  the program continues.
- **PERCOLATE** — recovery routine reports, then lets the abend percolate
  so the failure is not suppressed.

## HLASM techniques demonstrated

- Establishing an `ESTAEX` recovery exit and cancelling it (`ESTAEX 0`) on
  the clean-resume path.
- Mapping and reading the SDWA with `IHASDWA` (`SDWACMPC`, `SDWAEC1`).
- Driving recovery flow with `SETRP`: `RC=4` retry-to-resume-point vs
  `RC=0,DUMP=NO` percolate.
- Re-establishing a base in a recovery routine that gets control with none,
  via PC-relative `LARL` (see `docs/DESIGN.md` for why the classical
  `PARAM=`/`SDWAPARM` route was abandoned on this system).
- Formatting diagnostics to `WTO` (`@HEXOUT` for hex) rather than a dump —
  SVC dumps are suppressed installation-wide here.

## Return codes / outcomes

| PARM | Outcome |
|------|---------|
| `RETRY` | Recovery formats the SDWA, retries at a clean resume point, continues — step ends **RC 0**. |
| `PERCOLATE` | Recovery formats the SDWA, then lets the abend stand — step ends **ABEND S0C7** (failure not suppressed). |
| missing / bad | `WTO` diagnostic, **RC 8**, no recovery established. |

## Build and run

Source: `src/ESTDEMO.asm` (AMODE 31, RMODE ANY). Build JCL:
`jcl/BUILDEST.jcl` (assemble `ASMA90` + link `IEWL` into `ANDRE.EPE.LOAD`;
SYSLIB = `ANDRE.EPE.MACLIB` + `SYS1.MACLIB` + `SYS1.MODGEN`). Run JCL:
`jcl/RUNEST.jcl` — two steps, `RETRY` then `PERCOLATE`.

```
zowe files upload ftds "src/ESTDEMO.asm" "ANDRE.EPE.ASM(ESTDEMO)"
zowe jobs submit local-file "jcl/BUILDEST.jcl" --wait-for-output --rfj
zowe jobs submit local-file "jcl/RUNEST.jcl"   --wait-for-output --rfj
```

Verified run (system ZS31): `RETRY` step COND CODE 0000, `PERC` step
ABEND S0C7. JESMSGLG:

```
ESTDEMO: ABOUT TO RUN CVB ON BAD PACKED DATA
ESTDEMO SDWA  COMPCODE=0C7000
ESTDEMO SDWA  PSW=078D000090900B4E
ESTDEMO: RECOVERED VIA ESTAE, CONTINUING         <- RETRY step (RC 0)
ESTDEMO: ABOUT TO RUN CVB ON BAD PACKED DATA
ESTDEMO SDWA  COMPCODE=0C7000
ESTDEMO SDWA  PSW=078D000090900B4E
ESTDEMO: PERCOLATING - ABEND NOT SUPPRESSED       <- PERC step (S0C7)
```

The program-reported `COMPCODE=0C7000` (system 0C7) matches the
`IEF472I ... SYSTEM=0C7` the system records for the percolate step,
confirming the SDWA was read correctly.

> Status: **Complete** — assembled, linked, and run on system ZS31
> (RETRY RC 0, PERCOLATE S0C7).
