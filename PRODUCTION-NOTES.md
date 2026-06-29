# Production Readiness & Testing Notes

An honest assessment: **this is a demonstration portfolio, not a set of
production programs.** Everything here assembles, links, and runs correctly
on a real z/OS system — but "runs correctly on the happy path on a training
LPAR" is a much lower bar than "production-ready." This document says what
would need to change to ship any of it, and how to test it properly on your
own system. Knowing this distinction — and being able to name the specific
gap in a given program — is itself the senior-level skill.

## Where each artifact sits

| Artifact | Category | Production reality |
|---|---|---|
| 01 Macro Library | **Pattern, reusable** | The most portable piece; a shop might want a `RENT` variant and 64-bit/AR-mode awareness. |
| 02 CB Walker | **Pattern (diagnostic)** | Valid as a problem-state diagnostic; a real one would handle multiple ASIDs (ASVT), not just the current home space. |
| 03 SYSOUT Scraper | **Concept demo** | Reading JES spool in production should use **SAPI / SSI 79** with proper spool authority, not a `SUBSYS=JES2` dynalloc. |
| 04 ESTAE Demo | **Pattern, production-shaped** | The recovery *structure* is exactly right. The `LOOP` mode now shows the bounded-retry guard real recovery needs (see below). |
| 05 SMF Reporter | **Pattern** | The triplet-mapping is production-correct; in production you read real `SYS1.MANx` / logstream / `IFASMFDP` output, not synthetic records. |
| 06 IPCS Dump Practice | **Scaffolding** | A teaching tool that *deliberately* abends; never a production program. The IPCS skills transfer. |
| 07 Ansible Automation | **Concept demo** | `validate_certs: false` and an env-var password are no-gos in prod; use the certified `ibm.ibm_zosmf` collection + a secret manager. |
| 08 Feature-Flag Routing | **Concept demo** | A production flag lives in a control dataset / parmlib / DB2 table / `MODIFY` command, not an EXEC `PARM`, and is audited. |

## Gaps that apply across the board

- **All non-reentrant** (static save areas via `@ENTER`). Fine for
  single-shot batch; a hard stop for LPA residency or concurrent/
  multithreaded use. Production-critical modules want `RENT,REUS,REFR` and
  the assembler reentrancy check.
- **Environment hardcoded** — `ANDRE.EPE.*` datasets, `AMS-CLEAN` job
  cards, `CLASS=A`. Real shops use DSN standards, GDGs, JCL symbolics, and
  a scheduler (Control-M / CA-7), not literal names in JCL.
- **Happy-path tested only.** No negative, boundary, volume, concurrency,
  or abnormal-termination testing (see the test plan below).
- **Messages aren't productionized** — literal `WTO ROUTCDE=(11)` text.
  Production wants real message IDs, descriptor codes, a documented message
  catalog, and LOGREC recording where appropriate.
- **Authorization** — none currently need APF, but each should be confirmed
  to run under a *least-privilege* RACF id, not a powerful one.

## The two that would actually bite you

1. **Recovery retry loops (04).** A recovery routine that retries by
   resuming at the instruction that just failed loops **forever** on a
   persistent error. This portfolio now demonstrates the fix: ESTDEMO's
   **`LOOP` mode** re-drives the failure under a **retry counter capped at
   `MAXRETRY`**, then percolates — verified on the system (it re-failed 3
   times, then the guard stopped it). Production recovery would add this
   guard plus LOGREC recording (`SETRP RECORD=YES`), and use an **FRR** if
   ever in SRB / locked / cross-memory mode.
2. **Insecure automation (07).** `validate_certs: false` plus a password
   from an environment variable. Production needs real TLS validation, a
   vault / secret manager, RACF-protected z/OSMF, and ideally the certified
   `ibm.ibm_zosmf` collection rather than raw REST.

(And 03: full `S99ERROR` / `S99INFO` reason-code handling on every SVC 99
path, plus SAPI for spool access.)

## How to properly test it on your environment

A real promotion path, roughly in order:

1. **Retarget first.** Swap HLQ/DSNs, job cards, classes, SYSLIB/MACLIB/
   LOAD to your shop's standards. Run nothing with `ANDRE.EPE.*`.
2. **Build for review, not just RC.** Assemble with `FLAG`, `LIST`,
   `XREF` (and `RENT` if you want reentrancy) and **read the listing** —
   USING ranges, AMODE/RMODE, no hardcoded offsets, save-area chaining.
   Treat any `ASMA…W` as a defect. Then read the binder map.
3. **Negative + boundary tests, per artifact:**
   - 03 SOSCRAPE → empty file, zero matches, max-length records, huge file,
     odd characters.
   - 04 ESTDEMO → exercise `RETRY`, `PERC`, **and `LOOP`** (verify the
     guard caps the retries); then test your own retry limit.
   - 05 SMFRPT30 → feed **real** type-30 records (an `IFASMFDP` dump of
     `SYS1.MANx`), including absent sections, multiple sections, and jobs
     crossing midnight (the same-day elapsed assumption breaks).
   - 08 FEATFLAG → missing PARM, garbage PARM, wrong-length PARM.
   - 02 CBWALK → run from several address spaces; confirm the validation
     paths return RC 4 rather than abending.
4. **Volume + performance** — representative data sizes; watch CPU and
   storage.
5. **Abnormal termination** — cancel mid-run, drive S522 / B37; for
   long-runners, an operator `MODIFY` / `STOP` path.
6. **Least-privilege RACF id**, on a dedicated **TEST/QA** system with
   representative data — not production, and not a shared training box.
7. **Source control + automated build + baseline** (this is where artifact
   7 points): a library manager or Git+pipeline, a regression baseline, and
   require *listing + test evidence* before promotion.

## The honest interview framing

> "It's a demonstration portfolio — verified clean on a live system,
> written to production conventions, but not production-hardened. Here's
> specifically what I'd add to ship any one of these" — then name the ESTAE
> bounded-retry guard.

Knowing the difference, and naming the exact gap, lands far better than
claiming it's production-ready.
