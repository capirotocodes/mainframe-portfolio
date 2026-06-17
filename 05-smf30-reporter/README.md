# 05 — SMF Type-30 Generator + Reporter

A two-program HLASM pair for working with **SMF type 30, subtype 5**
(job-termination) records using the IBM-supplied `IFASMFR (30)` DSECTs:

- **`MKSMF30`** builds a small `RECFM=VB` dataset of synthetic type-30
  records (header + identification + processor sections), so the reporter can
  be exercised without live SMF data.
- **`SMFRPT30`** reads that dataset with QSAM, walks each record's
  self-defining sections via their **triplets**, and prints one line per job:
  job name, CPU seconds, elapsed seconds.

## Purpose

Demonstrate disciplined **SMF record mapping** — self-defining sections
located by header triplets, every field referenced through an IBM DSECT name
rather than a hardcoded offset. Pairs a generator with a consumer so the data
path is fully self-contained and reproducible.

## Control blocks / services used

- **`IFASMFR (30)`** — one assembly yields the `SMFRCD30` (header),
  `SMF30ID` (identification), and `SMF30CAS` (processor accounting) DSECTs.
- **Triplets** — `SMF30IOF/ILN/ION` and `SMF30COF/CLN/CON` give the
  offset / length / count of each section; sections are reached by
  `ICM` of the offset, `AR` the record base, then `USING` the section DSECT.
- **QSAM** — `PUT` move-mode out (MKSMF30); `GET` locate-mode in with an
  `EODAD` (SMFRPT30).
- IBM macros: `IFASMFR`, `DCB`/`DCBD`, `OPEN`/`CLOSE`/`GET`/`PUT`.

## HLASM techniques demonstrated

- Building a self-defining record: write the sections, then fill the header
  triplets so a consumer can find them.
- Navigating self-defining sections by triplet (offset/length/count) instead
  of constant offsets.
- Multi-DSECT addressability (three concurrent `USING`s, three base regs).
- Binary CPU/elapsed arithmetic from SMF hundredths-of-a-second fields, with
  `CVD` + `ED` formatting into an ANSI (`FBA`) report.
- Deliberate `AMODE 31, RMODE 24` so the in-CSECT QSAM DCBs OPEN below the
  16 MB line (avoids the S0C4-on-OPEN `AL3`-truncation trap).

## Return codes

| Program | RC | Meaning |
|---------|----|---------|
| MKSMF30 | 0  | Records written. (`ABEND U0201` if OUTDD fails to OPEN.) |
| SMFRPT30| 0  | Dataset read and report produced. |

## Dependencies

- **Artifact 1 macros** (`01-macro-library/`): `@ENTER` / `@LEAVE` standard
  linkage, resolved from `ANDRE.EPE.MACLIB` on the assembler `SYSLIB`.
- `IFASMFR` from `SYS1.MACLIB` (SMF record mappings).

> **Note on `@ENTER`:** code the `CSECT`/`AMODE`/`RMODE` header lines *before*
> a **bare** `@ENTER` — the macro bases addressability off the active control
> section (`USING &SYSECT,&BASE`) and takes only `BASE=`, not `CSECT=`.

## Build instructions

Sources: `src/MKSMF30.asm`, `src/SMFRPT30.asm`. Build JCL:
`jcl/BUILDSMF.jcl` (assemble + link both into `ANDRE.EPE.LOAD`). Run JCL:
`jcl/RUNSMF.jcl` (scratch prior dataset → MKSMF30 builds `ANDRE.EPE.SMF30`
→ SMFRPT30 reports).

```
zowe files upload ftds "src/MKSMF30.asm"  "ANDRE.EPE.ASM(MKSMF30)"
zowe files upload ftds "src/SMFRPT30.asm" "ANDRE.EPE.ASM(SMFRPT30)"
zowe jobs submit local-file "jcl/BUILDSMF.jcl" --wait-for-output --rfj
zowe jobs submit local-file "jcl/RUNSMF.jcl"   --wait-for-output --rfj
```

Verified run (system ZS31, all steps RC 0); report (`RPTDD`):

```
SMF TYPE 30 SUBTYPE 5 - JOB CPU/ELAPSED RPT
  JOB NAME        CPU (SEC)    ELAPSED (SEC)
  ANDREJ1            130.23          500.00
  PAYROLL           2515.00         3600.00
  BACKUP             100.00          120.00
```

## Design notes

See `docs/DESIGN.md` for the record/triplet layout, the AMODE/RMODE
rationale, and the two bugs found while reassembling on the real system (the
`@ENTER` addressability cascade and the `USING SMF30ID,R82` typo it masked).

> Status: **Complete** — assembled, linked, and run on system ZS31 (RC 0).
