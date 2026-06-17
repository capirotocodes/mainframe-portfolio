# 03 — JES2 SYSOUT Scraper

A batch HLASM program (`SOSCRAPE`) that dynamically allocates its datasets
with SVC 99, reads an input dataset with QSAM, scans each record for a
search pattern, and routes the matching lines to a **SYSOUT** dataset it
also allocated dynamically (so the output flows through the JES2 SSI). A
tiny `grep` whose output is a spool dataset.

## Purpose

Demonstrate real-world systems-programming plumbing — dynamic allocation
via SVC 99, sequential I/O, and a SYSOUT dataset managed by JES2 — the kind
of work that ties directly to a JES support background.

## Control blocks / services used

- **SVC 99 (dynamic allocation)** — hand-built `S99RB` + text-unit list to
  allocate the input DSN (DISP=SHR) and a SYSOUT dataset (class A), and to
  unallocate both on exit. Keys use the IBM equates (`DALDSNAM`,
  `DALDDNAM`, `DALSTATS`, `DALSYSOU`, `DUNDDNAM`) — no hardcoded values.
- **JES2 SSI** — a dynamically allocated SYSOUT dataset is processed by
  JES2; unallocating it hands the output to JES2 for printing/spooling.
- **QSAM** — locate-mode `GET` of the input, move-mode `PUT` of matches.
- IBM macros: `IEFZB4D0`/`IEFZB4D2` (SVC 99 mappings), `DCBD` (`IHADCB`).

## HLASM techniques demonstrated

- Building SVC 99 request blocks and text units by hand (allocate + unalloc).
- Connecting dynamically allocated DDs to QSAM DCBs by DDNAME.
- RECFM-aware record handling (F/FB via LRECL, V/VB via the RDW).
- `EX`-driven substring search and truncation.
- Deliberate `RMODE 24` so the DCBs, the SVC 99 `AL3` request-block
  pointers, and the 24-bit DCB `EODAD` are all below the 16 MB line
  (artifact 2 covers the RMODE ANY + `GETMAIN LOC=BELOW` technique).
- Flag-driven teardown that closes/unallocates only what succeeded.

## PARM and return codes

`PARM='dsname pattern'` — dsname (≤44) is scanned; the text after the first
blank is the pattern (≤44, may contain blanks).

| RC | Meaning |
|----|---------|
| 0  | At least one matching record found. |
| 4  | Clean scan, zero matches. |
| 8  | PARM, allocation, OPEN, or RECFM error (diagnostic written). |

## Build instructions

Source: `src/SOSCRAPE.asm`. Build JCL: `jcl/BUILDSO.jcl` (assemble → link →
build a sample input dataset with IEBGENER → run). The assembler `SYSLIB`
concatenates `ANDRE.EPE.MACLIB` (artifact-1 macros) ahead of `SYS1.MACLIB`
and `SYS1.MODGEN`.

```
zowe files upload ftds "src/SOSCRAPE.asm" "ANDRE.EPE.ASM(SOSCRAPE)"
zowe jobs submit local-file "jcl/BUILDSO.jcl" --wait-for-output --rfj
```

The run scrapes `ANDRE.EPE.SCRAP.IN` (built from `samples/SAMPLEIN.txt`)
for `ERROR`. Verified run (system ZS31, all steps RC 0); SCRAPOUT:

```
00000001 ERROR: RC=0008 RETURNED FROM MODULE PAYUPD
00000002 ERROR: S0C7 IN MODULE TAXCALC AT OFFSET +0A2C
Records scanned 00000008 matched  00000002
```

## Design notes

See `docs/DESIGN.md`. It also records the three bugs shaken out on the real
system (the `EX` register-0 gotcha, S99RB fullword alignment, and `AL3`
pointer truncation above the line). The "live spool" variants
(`SUBSYS=JES2` input, or the production SAPI / SSI function 79 path) are
documented there as extensions that slot in ahead of the QSAM scan without
changing the match logic.

> Status: **Complete** — assembled, linked, and run on system ZS31 (RC 0).
