# Design — SMF Type-30 Generator + Reporter (MKSMF30 / SMFRPT30)

## Goal

A two-program pair that demonstrates **reading and mapping real SMF
records** without needing live SMF data:

- **MKSMF30** writes a small dataset of synthetic **SMF type 30, subtype 5**
  (job-termination) records, built field-by-field through the IBM-supplied
  `IFASMFR (30)` DSECTs.
- **SMFRPT30** reads that dataset back with QSAM, navigates each record's
  self-defining sections via their **triplets**, and prints one line per
  job: job name, CPU seconds, elapsed seconds.

```
   MKSMF30  --(RECFM=VB dataset, ANDRE.EPE.SMF30)-->  SMFRPT30  --> report
   (build N records from a table)                     (GET locate, map, print)
```

The point is the **mapping discipline**: never hardcode an SMF offset, walk
the record exactly the way a real type-30 consumer would — header triplet →
section base register → IBM DSECT field name.

## The SMF type-30 record and its DSECTs

A type-30 record is **self-defining**: a fixed header carries *triplets*
(offset / length / count) that locate each optional section elsewhere in the
record. All three layouts come from one assembly of `IFASMFR (30)`:

| DSECT | Section | Key fields used |
|-------|---------|-----------------|
| `SMFRCD30` | Record header (incl. RDW) | `SMF30LEN` (RDW len), `SMF30RTY`=30, `SMF30STP`=5, `SMF30SID`, `SMF30TME`/`SMF30DTE`, and the triplets `SMF30IOF/ILN/ION` (identification) and `SMF30COF/CLN/CON` (processor) |
| `SMF30ID` | Identification | `SMF30JBN` (job name), `SMF30PGM`, `SMF30STM`, `SMF30RST`/`SMF30RSD` (reader-in time/date) |
| `SMF30CAS` | Processor accounting | `SMF30CPT` (TCB CPU), `SMF30CPS` (SRB CPU) |

A **triplet** is the three header fields `xOF` (offset from record start),
`xLN` (section length), `xON` (number of sections). To reach a section you
read its `xOF`, add the record base, and `USING` the section DSECT there.

## MKSMF30 — the generator

- Opens `OUTDD` (`RECFM=VB, LRECL=4096`) move-mode and verifies the open
  with `TM OUTDCB+48,X'10'` (DCBOFOPN); a failed OPEN issues `ABEND 201`.
- Drives a 3-entry table (`JOBTBL`: `ANDREJ1`, `PAYROLL`, `BACKUP`), one
  record per entry (`NJOBS EQU 3`).
- For each record it clears a build area (`MVCL`), then establishes three
  bases over the contiguous sections:

  ```
  RECBUF                              -> SMFRCD30  (R7)
  RECBUF + RHDRLEN                    -> SMF30ID   (R8)
  RECBUF + RHDRLEN + RIDLEN           -> SMF30CAS  (R9)
  ```

  with `RHDRLEN=228`, `RIDLEN=72`, `RCASLEN=16`, so
  `RECLEN = 228+72+16 = 316` (the RDW length written into `SMF30LEN`).
- Fills the header (type/subtype/system id/time/date) **and the two
  triplets** so the sections it just wrote are discoverable, then the ID and
  processor fields from the table entry, and `PUT`s the record.

The synthetic times are chosen so CPU < elapsed for every job and so the
arithmetic in the reporter has obvious expected answers.

## SMFRPT30 — the reporter

- Opens `INDD` (QSAM **GET locate**, `MACRF=GL`, `EODAD=RATEOF`) and `RPTDD`
  (`RECFM=FBA, LRECL=133`) and writes a title + column headings.
- Main loop: `GET` returns R1 → the logical record; base `SMFRCD30` on R1.
  Filter on `SMF30RTY=30` and `SMF30STP=5`.
- **Locate each section by its triplet, not by a constant:**

  ```
  ICM  R8,B'1111',SMF30IOF   ; offset to ID section (0 = absent -> skip)
  AR   R8,R7                 ; + record base = absolute address
  USING SMF30ID,R8
  ICM  R9,B'1111',SMF30COF   ; offset to processor section
  AR   R9,R7
  USING SMF30CAS,R9
  ```

- Computes, in hundredths of a second:
  - `CPU     = SMF30CPT + SMF30CPS`
  - `ELAPSED = SMF30TME - SMF30RST` (same-day; no date carry)
  - SMF fields are copied to fullword-aligned work fields first
    (`WCPT/WCPS/WTME/WRST`) before the binary arithmetic.
- Formats each value with `CVD` + `ED` against a mask
  (`X'402020...214B2020'` = 9 integer digits, `.`, 2 decimals) into a `FBA`
  detail line, and `PUT`s it. `EODAD` closes both DCBs and returns RC 0.

## Register / addressing conventions

- `@ENTER`/`@LEAVE` standard linkage (artifact 1): R12 base, R13 → save
  area, R15 entry, R14 return.
- MKSMF30: R5 → current table entry, R6 = record counter (`BCT`), R7/R8/R9
  the three section bases.
- SMFRPT30: R7 = record base, R8 = ID base, R9 = processor base, R2/R3 hold
  the CPU/elapsed sums.

## Addressing mode: AMODE 31, RMODE 24 (deliberate)

Both modules are linked `MODE AMODE(31),RMODE(24)` (binder control statement
in `BUILDSMF.jcl`). Like artifact 3, they load **below the 16 MB line** on
purpose so the in-CSECT QSAM DCBs OPEN directly with no GETMAIN/copy dance.
This is the documented fix for the **S0C4-on-OPEN** trap: when a module that
contains a DCB is allowed above the line, OPEN's `AL3(dcb)` parameter address
is truncated to 24 bits and faults. The `CSECT`/`AMODE 31`/`RMODE 24` header
lines are coded explicitly before `@ENTER` because `@ENTER` bases
addressability off the **active** control section (`USING &SYSECT,&BASE`).

## Edge cases / what could go wrong

- **Absent section** — if a triplet offset is zero, SMFRPT30 skips the
  record (`BZ RLOOP`) rather than dereferencing a null section.
- **Wrong record type/subtype** — filtered out before any section access.
- **Move mode + RECFM** — the output is `RECFM=VB` (not VBS); VBS spanned
  records do not support QSAM move mode (`MACRF=PM`), which would leave the
  PUT routine pointer zero. VB move mode is correct here.
- **Same-day elapsed only** — `SMF30TME - SMF30RST` assumes the job started
  and ended on the same day; a real reporter would carry `SMF30DTE`/
  `SMF30RSD` across midnight.
- **Non-reentrant** — static DCB models and build areas, consistent with the
  rest of the portfolio (documented choice).

## Debugging lessons (verified on system ZS31)

Two bugs were shaken out by reassembling on the real system; both are
instructive because the **first one masked the second**:

1. **`@ENTER` misuse — addressability cascade.** The sources called
   `@ENTER CSECT=name`, but the `@ENTER` macro accepts only `&BASE` and
   bases addressability off the *active* CSECT (`USING &SYSECT,&BASE`). With
   no `name CSECT` statement coded first, `&SYSECT` was the unnamed section,
   so the macro emitted `USING ,12` (empty operand → `ASMA074E`), and **every
   subsequent label reference failed** `ASMA307E No active USING`. `END name`
   then failed `ASMA044E` because the CSECT was never defined. Fix: code the
   `CSECT`/`AMODE 31`/`RMODE 24` header lines and call a **bare `@ENTER`**.
2. **`USING SMF30ID,R82` typo.** Only visible once bug 1 cleared. R8 holds
   the ID-section address; `R82` is undefined, so the `USING` failed
   (`ASMA044E`) and the two referenced `SMF30ID` fields (`SMF30RST`,
   `SMF30JBN`) reported `ASMA307E`. Fix: `R82` → `R8`. A clean illustration
   of how one broken `USING` produces "no active USING" errors at every
   *use* of that DSECT, far from the real defect.

## On-system build and run (verified)

`jcl/BUILDSMF.jcl` — assemble + link both modules into `ANDRE.EPE.LOAD`
(`SYSLIB` = `ANDRE.EPE.ASM` + `ANDRE.EPE.MACLIB` ahead of `SYS1.MACLIB`;
binder `MODE AMODE(31),RMODE(24)`).

`jcl/RUNSMF.jcl` — scratch any prior `ANDRE.EPE.SMF30`, run MKSMF30 to build
it (`RECFM=VB,LRECL=4096`), then run SMFRPT30 to read it back. Verified run
(all steps RC 0); the report (`RPTDD`) contained:

```
SMF TYPE 30 SUBTYPE 5 - JOB CPU/ELAPSED RPT
  JOB NAME        CPU (SEC)    ELAPSED (SEC)
  ANDREJ1            130.23          500.00
  PAYROLL           2515.00         3600.00
  BACKUP             100.00          120.00
```

(e.g. PAYROLL: CPU = (250000+1500)/100 = 2515.00; elapsed =
(3960000−3600000)/100 = 3600.00.)
