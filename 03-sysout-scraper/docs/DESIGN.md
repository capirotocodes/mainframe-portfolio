# Design — JES2 SYSOUT Scraper (SOSCRAPE)

## Goal

A batch utility that **dynamically allocates** its datasets with SVC 99,
**reads** an input dataset with QSAM, **scans** each record for a search
pattern, and **routes** the matching lines to a **SYSOUT** dataset it also
allocated dynamically (so the output flows through the JES2 SSI). It works
like a tiny `grep` whose output is a spool dataset.

```
   PARM='dsname pattern'
        |
        v
   SVC 99 alloc SYSOUT (DDNAME SCRAPOUT, class A)  --> JES2 spool
   SVC 99 alloc input  (DDNAME SCRAPIN, DSN, SHR)
        |
        v
   QSAM GET (locate) each record --> substring match --> QSAM PUT match
        |
        v
   summary line, CLOSE, SVC 99 unallocate both, return
```

This is the **runnable** interpretation of the artifact. Reading *live*
spool through `SUBSYS=JES2` or the SYSOUT API (SAPI, SSI function 79) is
the production-grade extension — see "Stretch" below.

## Services and control blocks

| Service / block | Use | Mapping macro |
|-----------------|-----|---------------|
| SVC 99 (DYNALLOC) | Allocate input DSN and output SYSOUT; unallocate both | `IEFZB4D0` (request block), `IEFZB4D2` (text units) |
| QSAM | `GET` locate-mode read of input; `PUT` move-mode write of matches | `DCBD` (`IHADCB`) |
| JES2 SSI | A dynamically allocated SYSOUT dataset is managed by JES2; unallocation drives JES2 output processing | (implicit, via DALSYSOU) |

**No hardcoded SVC 99 keys.** Text-unit keys use the IBM equates
(`DALDSNAM`, `DALDDNAM`, `DALSTATS`, `DALSYSOU`, `DUNDDNAM`) and verb codes
use `S99VRBAL` / `S99VRBUN` from the supplied mappings, per project rules.

## SVC 99 request layout

For each operation the program builds, as static storage:

1. An **S99 RB pointer** word — `X'80',AL3(rb)` — the high bit marks it as
   the last (only) RB pointer. R1 points here; then `SVC 99`.
2. An **S99RB** (`IEFZB4D0`): `S99RBLN` = `S99RBEND-S99RB` (no magic 20),
   `S99VERB` = `S99VRBAL`/`S99VRBUN`, `S99TXTPP` → the text-unit pointer
   list. `S99ERROR`/`S99INFO` are output fields the program reports on
   failure.
3. A **text-unit pointer list** — fullwords pointing at each text unit,
   high bit set on the last.
4. **Text units** (`IEFZB4D2` layout: key, count, length, parm). The DSN
   text unit's length (`TUDSNLN`) and text (`TUDSNTX`) are filled at run
   time from the PARM; the rest are static.

Allocations request explicit DDNAMEs (`SCRAPIN`, `SCRAPOUT`) so the
assembled QSAM DCBs can connect by `DDNAME=` at OPEN.

## PARM parsing

`EXEC PGM=SOSCRAPE,PARM='dsname pattern'`

- R1 → parm pointer → halfword length + text.
- Split on the **first blank**: token before = input DSN (1–44 chars,
  validated); everything after the blank = the search pattern (1–44 chars).
- A pattern may contain blanks (only the first blank is the delimiter); a
  DSN may not. Missing PARM / missing pattern / over-length → diagnostic
  and RC 8.

## Reading and matching

- Input opened locate-mode (`MACRF=GL`); `GET` returns R1 → the logical
  record. After OPEN the program reads `DCBRECFM`/`DCBLRECL` from `IHADCB`
  to learn the record format:
  - **RECFM F/FB** → record at R1, length = `DCBLRECL`.
  - **RECFM V/VB** → 4-byte RDW at R1; data at R1+4, length = `LL-4`.
  - **RECFM U** → unsupported (diagnostic, RC 8).
- Substring search: for start positions `0 .. RLEN-PLEN`, an `EX` of a
  `CLC` (length = `PLEN-1` in R0) compares the candidate against the
  pattern. First hit ends the scan for that record (line-oriented, like
  `grep`: one output line per matching record).
- Each match is written to SCRAPOUT as `FBA`/`LRECL=133`: ANSI control
  char, an 8-hex match sequence number (built with `@HEXOUT`), then up to
  123 bytes of the record (truncated with an `EX`-ed `MVC`).

## Output, summary, return codes

- All output — matches, the final summary, and any diagnostics issued
  *after* SCRAPOUT is open — goes to the dynamically allocated SYSOUT.
  Fatal errors *before* SCRAPOUT is open use `WTO` (there is nowhere else
  to write yet).
- Summary line: records scanned and matches found, both in hex.

| RC | Meaning |
|----|---------|
| 0  | At least one matching record found. |
| 4  | Clean scan, zero matches (the "grep found nothing" case). |
| 8  | PARM, allocation, OPEN, or RECFM error (diagnostic issued). |

## Register / addressing conventions

- `@ENTER`/`@LEAVE` standard linkage; R12 base, R13 save area.
- R7 → output DCB, R8 → input DCB (both below the line, see next), R6 =
  `BAL` link to the `PUTLINE` writer. R2/R3 hold record pointer/length in
  the scan; R0/R9/R10 drive the `EX`/`CLC` search.
- A single byte of `FLAGS` records what has been allocated/opened
  (`FLOUTALC`/`FLOUTOPN`/`FLINALC`/`FLINOPN`) so one `TERM` path tears down
  exactly what succeeded.

## Addressing mode: RMODE 24 (deliberate)

This program is **AMODE 31, RMODE 24**. CBWALK already demonstrates the
RMODE ANY + `GETMAIN LOC=BELOW` + `OPEN MODE=31` technique for an
above-the-line program. SOSCRAPE instead loads below the 16 MB line on
purpose, because it leans on several **24-bit-addressable** structures that
are far simpler below the line:

- The QSAM DCBs can be OPENed directly (no GETMAIN/copy dance).
- The SVC 99 request-block pointers use the `X'80',AL3(addr)` idiom — a
  3-byte (24-bit) address with the last-RB flag in the top byte. Above the
  line, `AL3` would truncate the real 31-bit address (the binder even warns
  `IEW2635I`). Below the line it is exact.
- The DCB `EODAD` field is 24-bit; an above-the-line EODAD routine would
  need a DCBE with a 31-bit `EODAD`.

Trading one demonstration of the RMODE ANY technique (already shown in
artifact 2) for a much cleaner SVC 99 / QSAM program is the right call here.

## SVC 99 request-block alignment

Each S99RB must start on a **fullword boundary**. The fixed header is
`S99RBLN`(1) `S99VERB`(1) `S99FLG1`(2) `S99ERROR`(2) `S99INFO`(2) = 8 bytes,
then `S99TXTPP` (an `A`-type adcon) at offset 8. `DC A(...)` self-aligns to
a fullword, so if the RB does **not** start aligned, the assembler inserts a
pad byte before `S99TXTPP`, pushing it to offset 9 — and SVC 99 then reads
the text-unit-list pointer from the wrong offset (garbage → S0C4). Each RB
is therefore preceded by `DS 0F`.

## Edge cases / what could go wrong

- **SVC 99 failure** — R15 ≠ 0; the program reports `S99ERROR` in hex and
  returns RC 8. (Common: input DSN not found, or DDNAME already in use.)
- **DDNAME clash** — if `SCRAPIN`/`SCRAPOUT` are already allocated in the
  step, allocation fails; the chosen names are deliberately unusual.
- **Pattern longer than the record** — no match, no error.
- **RECFM V short records** — `LL-4` can be 0; a zero-length record simply
  cannot match a non-empty pattern.
- **Cleanup on every path** — `TERM` closes/unallocates only what `FLAGS`
  says succeeded, then frees the DCB storage, so a mid-stream error never
  leaks an allocation or storage. Unallocating SCRAPOUT is what hands the
  output to JES2.
- **Non-reentrant** — static request blocks and DCB models, consistent
  with the rest of the portfolio (documented choice, not an oversight).

## Stretch (documented, not built here)

To scrape *live* spool: either allocate a held SYSOUT dataset with
`DALSSNM='JES2'` (SUBSYS=JES2) for input, or — the real production path —
use **SAPI (SSI function code 79)** to select SYSOUT by class/jobname/dest
via the SSOB + `IAZSSS2`, then read the dataset JES returns. Both slot in
ahead of the existing QSAM scan with no change to the matching logic.

## Debugging lessons (verified on system ZS31)

Three bugs were found and fixed by running on the real system:

1. **`EX` with register 0 does nothing.** `EX R0,target` is the special
   case that executes the target **unmodified** — the length is never
   OR-ed in. The substring `MVC`/`CLC` length register must be non-zero
   (the code uses R1). This first surfaced as a dsname truncated to one
   byte (and would also have broken the search).
2. **Unaligned S99RB** (see above) — `DS 0F` before each request block.
3. **`AL3` pointers truncate above the line** — resolved by `RMODE 24`.

## On-system build (verified)

See `../jcl/BUILDSO.jcl`: assemble → link → create a sample input dataset
with IEBGENER (from `../samples/SAMPLEIN.txt`) → run, scraping for `ERROR`.
Verified run (all steps RC 0); SCRAPOUT contained:

```
00000001 ERROR: RC=0008 RETURNED FROM MODULE PAYUPD
00000002 ERROR: S0C7 IN MODULE TAXCALC AT OFFSET +0A2C
Records scanned 00000008 matched  00000002
```
