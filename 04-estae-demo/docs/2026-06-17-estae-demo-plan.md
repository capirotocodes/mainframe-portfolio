# ESTAE Recovery Demo (ESTDEMO) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `ESTDEMO`, a batch HLASM program that deliberately causes a S0C7, recovers in an ESTAEX routine, formats key SDWA fields to WTO, and either retries (RC 0) or percolates (S0C7) based on a PARM.

**Architecture:** Single CSECT, AMODE 31 / RMODE ANY, no data-set I/O (all output via `WTO ROUTCDE=(11)`). `PARM='RETRY'|'PERCOLATE'` sets a `MODEFLAG`; `ESTAEX` establishes a recovery exit that reads the SDWA (re-establishing addressability from `PARAM`), formats fields with `@HEXOUT`, WTOs them, and uses `SETRP` to retry or percolate. Spec: [DESIGN.md](DESIGN.md).

**Tech Stack:** IBM High Level Assembler (`ASMA90`), binder (`IEWL`); IBM macros `ESTAEX`, `SETRP`, `IHASDWA`, `WTO`; personal macros `@ENTER`/`@LEAVE`/`@HEXOUT` from `ANDRE.EPE.MACLIB`. Built/run on z/OS via the Zowe CLI loop (cannot assemble locally).

---

## The on-system build/verify loop (used by every task)

Local files live in `04-estae-demo/`. The z/OS members live under `ANDRE.EPE.*`. The loop, run from the `mainframe-portfolio/` working directory:

```bash
# upload source (member name = ESTDEMO, no extension)
zowe zos-files upload file-to-data-set "04-estae-demo/src/ESTDEMO.asm" "ANDRE.EPE.ASM(ESTDEMO)"
# assemble + link
zowe jobs submit local-file "04-estae-demo/jcl/BUILDEST.jcl" --wait-for-output --rfj
# read the return code / spool of a job id
zowe jobs view spool-file-by-id <JOBID> 4   # JESYSMSG: step COND CODEs / abends
zowe jobs view all-spool-content <JOBID>    # full output incl. JESMSGLG (WTO lines)
```

When a step "fails" in the TDD sense, that is the assembler listing in `ANDRE.EPE.LISTCASM(ESTDEMO)` (download and grep for `ASMA[0-9]+[EWS]`) or a runtime RC/abend in JESYSMSG. **"Pin against live macro" steps** mean: assemble, and if a field/operand name is wrong the assembler flags it cleanly (`ASMAxxxE`); correct the spelling from the macro and re-assemble. There is no local compiler — the host assembler is the type-checker.

---

## File Structure

- **Create** `04-estae-demo/src/ESTDEMO.asm` — the single-CSECT program (built up across Tasks 1–4).
- **Create** `04-estae-demo/jcl/BUILDEST.jcl` — assemble + link into `ANDRE.EPE.LOAD(ESTDEMO)` (Task 1).
- **Create** `04-estae-demo/jcl/RUNEST.jcl` — two-step run, RETRY then PERCOLATE (Task 5).
- **Modify** `04-estae-demo/README.md` — fill in build/run instructions + status (Task 5).
- **Modify** `mainframe-portfolio/CLAUDE.md` — flip artifact 4 status to Complete (Task 5).

`@ENTER` contract (verified this repo): code `name CSECT` / `AMODE` / `RMODE` **before** a bare `@ENTER`; the macro takes only `BASE=` and bases `USING &SYSECT,&BASE`. Do **not** write `@ENTER CSECT=...`.

---

## Task 1: Skeleton — PARM parse, WTO helper, clean exits

Program assembles, links, and runs **without** any abend or recovery yet: valid PARM → RC 0, bad PARM → RC 8. Proves linkage, PARM parsing, and the WTO path before recovery is layered on.

**Files:**
- Create: `04-estae-demo/src/ESTDEMO.asm`
- Create: `04-estae-demo/jcl/BUILDEST.jcl`

- [ ] **Step 1: Write the build JCL** — `04-estae-demo/jcl/BUILDEST.jcl`

```jcl
//ANDREB    JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*------------------------------------------------------------------*
//*  ASSEMBLE + LINK  ESTDEMO   (AMODE 31, RMODE ANY)                 *
//*------------------------------------------------------------------*
//ASM     EXEC PGM=ASMA90,REGION=0M,
//    PARM=('LINECOUNT(111),USING(WARN(11)),XREF(SHORT),DECK')
//SYSIN    DD  DSN=ANDRE.EPE.ASM(ESTDEMO),DISP=SHR
//SYSPUNCH DD  DSN=ANDRE.EPE.OBJ(ESTDEMO),DISP=SHR
//SYSLIN   DD  DUMMY
//SYSPRINT DD  DSN=ANDRE.EPE.LISTCASM(ESTDEMO),DISP=SHR
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(5,5))
//SYSLIB   DD  DSN=ANDRE.EPE.MACLIB,DISP=SHR
//         DD  DSN=SYS1.MACLIB,DISP=SHR
//         DD  DSN=SYS1.MODGEN,DISP=SHR
//LINK    EXEC PGM=IEWL,COND=(4,LE,ASM),
//   PARM='XREF,LIST,LET,NCAL,SIZE=(512K,196K),AC=0'
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(10,10))
//OBJDS    DD  DSN=ANDRE.EPE.OBJ,DISP=SHR
//SYSPRINT DD  DSN=ANDRE.EPE.LISTLNK(ESTDEMO),DISP=SHR
//SYSLMOD  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//SYSLIN   DD  *
  MODE AMODE(31),RMODE(ANY)
  INCLUDE OBJDS(ESTDEMO)
  ENTRY ESTDEMO
  NAME ESTDEMO(R)
/*
```

- [ ] **Step 2: Write the skeleton source** — `04-estae-demo/src/ESTDEMO.asm`

```hlasm
*=====================================================================
* ESTDEMO - ESTAE RECOVERY DEMONSTRATION
*           DELIBERATELY CAUSES A S0C7 DATA EXCEPTION, RECOVERS IN AN
*           ESTAEX RECOVERY ROUTINE, FORMATS KEY SDWA FIELDS TO WTO,
*           AND EITHER RETRIES (CONTINUE, RC 0) OR PERCOLATES (S0C7).
* INPUTS  : PARM='RETRY' | 'PERCOLATE'   (FIRST CHAR R / P)
* OUTPUT  : WTO (ROUTCDE 11) - SDWA REPORT; RC 0 (RETRY) / S0C7 (PERC)
* DEPENDS : @ENTER/@LEAVE/@HEXOUT (ANDRE.EPE.MACLIB); ESTAEX/SETRP/
*           IHASDWA (SYS1.MACLIB/MODGEN)
*=====================================================================
ESTDEMO  CSECT
ESTDEMO  AMODE 31
ESTDEMO  RMODE ANY
         @ENTER
*  ---- PARSE PARM: FIRST CHAR R=RETRY, P=PERCOLATE --------------
         LR    R2,R1               R2 -> PARM LIST POINTER
         MVI   MODEFLAG,X'00'
         LTR   R2,R2               NO PARM LIST?
         BZ    BADPARM
         L     R3,0(,R2)           R3 -> PARM (HALFWORD LEN + TEXT)
         LH    R4,0(,R3)           R4 = PARM TEXT LENGTH
         LTR   R4,R4               EMPTY PARM?
         BZ    BADPARM
         CLI   2(R3),C'R'
         BE    MRETRY
         CLI   2(R3),C'P'
         BE    MPERC
         B     BADPARM
MRETRY   MVI   MODEFLAG,MODERTRY
         B     MAINGO
MPERC    MVI   MODEFLAG,MODEPERC
MAINGO   DS    0H
*  ---- (TASKS 2-4 INSERT: ESTAEX, ABEND, RECOVERY HERE) --------
         MVC   WTOTXT,MSGOK        "RUNNING, NO ABEND YET"
         LA    R6,RETPT0           (placeholder until recovery added)
         BAL   R6,PUTWTO
NORMEXIT DS    0H
RETPT0   DS    0H
         @LEAVE RC=0
*  ---- BAD PARM: REPORT AND RC 8 -------------------------------
BADPARM  DS    0H
         MVC   WTOTXT,MSGBAD
         BAL   R6,PUTWTO
         @LEAVE RC=8
*=====================================================================
* WTO HELPER - ISSUE THE 71-CHAR LINE IN WTOTXT (LIST/EXECUTE FORM)
*   R6 = RETURN REGISTER.  CLOBBERS R0,R1,R15.
*=====================================================================
PUTWTO   DS    0H
         WTO   MF=(E,WTOLIST)
         BR    R6
*=====================================================================
* DATA
*=====================================================================
MODEFLAG DS    X                   X'01'=RETRY  X'02'=PERCOLATE
MODERTRY EQU   X'01'
MODEPERC EQU   X'02'
         DS    0H
WTOLIST  WTO   ' ',                                                    X
               ROUTCDE=(11),MF=L
WTOTXT   EQU   WTOLIST+4,71        TEXT FIELD = AFTER LEN(2)+FLAGS(2)
*  NB: confirm the MF=L layout offset (text after AL2 len + AL2 flags)
*      against the live WTO macro when first assembled; adjust the +4.
MSGOK    DC    CL71'ESTDEMO: STARTED, MODE ACCEPTED (NO ABEND YET)'
MSGBAD   DC    CL71'ESTDEMO: BAD/MISSING PARM - USE RETRY OR PERCOLATE'
         @HEXOUT MODE=DEFINE
         LTORG
R0       EQU   0
R1       EQU   1
R2       EQU   2
R3       EQU   3
R4       EQU   4
R5       EQU   5
R6       EQU   6
R11      EQU   11
R12      EQU   12
R13      EQU   13
R14      EQU   14
R15      EQU   15
         END   ESTDEMO
```

- [ ] **Step 3: Upload and assemble — verify it FAILS clean or PASSES**

Run:
```bash
zowe zos-files upload file-to-data-set "04-estae-demo/src/ESTDEMO.asm" "ANDRE.EPE.ASM(ESTDEMO)"
zowe jobs submit local-file "04-estae-demo/jcl/BUILDEST.jcl" --wait-for-output --rfj
```
Then download the listing and check for flags:
```bash
zowe zos-files download data-set "ANDRE.EPE.LISTCASM(ESTDEMO)" -f "/tmp/EST.lst"
grep -nE "ASMA[0-9]+[EWS]" /tmp/EST.lst
```
Expected: assemble severity ≤ 4, LINK RC 0. **Pin step:** if `WTOTXT EQU WTOLIST+4` is wrong, fields won't be flagged (it's arithmetic) — instead confirm visually in the listing that `WTOLIST`'s generated text begins 4 bytes in; adjust the displacement if the macro emits a different prefix.

- [ ] **Step 4: Run with a valid and an invalid PARM**

Create a throwaway run (inline) and submit, or use a temporary 2-step JCL. Submit:
```bash
# RETRY -> expect RC 0 and the "STARTED" WTO in JESMSGLG
zowe jobs submit local-file "04-estae-demo/jcl/BUILDEST.jcl" --wait-for-output --rfj  # (build first)
```
For the run, add a temporary step `//R EXEC PGM=ESTDEMO,PARM='RETRY'` with `STEPLIB DD DSN=ANDRE.EPE.LOAD,DISP=SHR`. Expected: step RC **0000**; JESMSGLG contains `ESTDEMO: STARTED`. Repeat with `PARM=''` → RC **0008** and `ESTDEMO: BAD/MISSING PARM`.

- [ ] **Step 5: Commit**

```bash
git add 04-estae-demo/src/ESTDEMO.asm 04-estae-demo/jcl/BUILDEST.jcl
git commit -m "artifact 4: ESTDEMO skeleton - PARM parse + WTO helper, clean exits"
```

---

## Task 2: Trigger the S0C7 (no recovery yet)

Add the deliberate data exception and confirm the program abends S0C7 when no recovery is established. This proves the trigger is real before we catch it.

**Files:**
- Modify: `04-estae-demo/src/ESTDEMO.asm` (the `MAINGO` block and the data area)

- [ ] **Step 1: Replace the placeholder body at `MAINGO`**

Replace the three placeholder lines under `MAINGO DS 0H` (the `MVC WTOTXT,MSGOK` / `LA R6,RETPT0` / `BAL R6,PUTWTO`) with the abend trigger:

```hlasm
MAINGO   DS    0H
         MVC   WTOTXT,MSGTRY       "ABOUT TO ABEND"
         BAL   R6,PUTWTO
         CVB   R5,BADPACK          INVALID PACKED DATA -> S0C7
         MVC   WTOTXT,MSGNORC      (only reached if no exception)
         BAL   R6,PUTWTO
```

- [ ] **Step 2: Add the bad packed field and messages to the data area**

Add after `MODEPERC EQU X'02'`:

```hlasm
         DS    0D
BADPACK  DC    X'1234ABCD'         INVALID DIGITS A/B/C -> DATA EXCEPTION
```

Add after `MSGBAD`:

```hlasm
MSGTRY   DC    CL71'ESTDEMO: ABOUT TO EXECUTE CVB ON INVALID PACKED DATA'
MSGNORC  DC    CL71'ESTDEMO: CVB DID NOT FAULT - UNEXPECTED'
```

- [ ] **Step 3: Upload, assemble, link — verify clean**

Run the build loop (Task 1, Step 3). Expected: assemble ≤ 4, LINK RC 0.

- [ ] **Step 4: Run with PARM='RETRY' — verify it ABENDS S0C7**

Run via a temp step `//R EXEC PGM=ESTDEMO,PARM='RETRY'` + `STEPLIB`. Expected (JESYSMSG):
`IEF142I ... ABEND S0C7` (system completion code `0C7`), and JESMSGLG shows `ESTDEMO: ABOUT TO EXECUTE CVB`. The `MSGNORC` line must **not** appear.
```bash
zowe jobs view spool-file-by-id <JOBID> 4 | grep -iE "S0C7|ABEND|COMPLETION"
```

- [ ] **Step 5: Commit**

```bash
git add 04-estae-demo/src/ESTDEMO.asm
git commit -m "artifact 4: trigger S0C7 via CVB on invalid packed data (no recovery yet)"
```

---

## Task 3: ESTAEX recovery routine + SDWA format + RETRY

Establish the recovery exit, format the SDWA, WTO it, and retry to a resume point so the RETRY mode ends RC 0.

**Files:**
- Modify: `04-estae-demo/src/ESTDEMO.asm`

- [ ] **Step 1: Establish recovery before the abend**

Insert immediately after `MAINGO DS 0H` (before `MVC WTOTXT,MSGTRY`):

```hlasm
         ESTAEX RECVEXIT,PARAM=PGMBASEA   ESTABLISH RECOVERY EXIT
```

- [ ] **Step 2: Add the retry resume point and convert NORMEXIT**

Replace the existing `NORMEXIT DS 0H` / `RETPT0 DS 0H` / `@LEAVE RC=0` block with:

```hlasm
*  ---- RETRY RESUME POINT (REACHED VIA SETRP RETADDR) ----------
RETRYPT  DS    0H
         LARL  R12,ESTDEMO         RE-ESTABLISH BASE (DO NOT TRUST REGS)
         ESTAEX 0                  CANCEL RECOVERY (CLEAN CONTINUE)
         MVC   WTOTXT,MSGREC       "RECOVERED, CONTINUING"
         BAL   R6,PUTWTO
NORMEXIT DS    0H
         @LEAVE RC=0
```

- [ ] **Step 3: Add the recovery routine** (place before the `* DATA` banner)

```hlasm
*=====================================================================
* RECVEXIT - ESTAE RECOVERY ROUTINE
*   ENTRY: R0 = 0 IF SDWA PRESENT (X'0C' IF NOT), R1 -> SDWA,
*          R14 = RTM RETURN ADDRESS, R15 = THIS ENTRY POINT.
*   USES RELATIVE BRANCHES UNTIL A CSECT BASE (R11) IS LOADED FROM
*   SDWAPARM, SO NO CSECT BASE IS ASSUMED ON ENTRY.
*=====================================================================
RECVEXIT DS    0H
         DROP  R12                 R12 IS NOT OUR BASE IN THE EXIT
         LR    R3,R14              PRESERVE RTM RETURN ADDRESS
         LTR   R0,R0               SDWA PROVIDED?
         JNZ   NOSDWA              NO -> PERCOLATE BARE
         LR    R2,R1               R2 -> SDWA
         USING SDWA,R2
         L     R11,SDWAPARM        R11 -> PGMBASEA (PARAM WE PASSED)
         L     R11,0(,R11)         R11 = ESTDEMO BASE
         USING ESTDEMO,R11         FULL CSECT ADDRESSABILITY
*  ---- FORMAT SDWA: ABEND CODE + REASON ------------------------
         MVC   WTOTXT,MSGCMPC
         @HEXOUT SDWACMPC,WTOTXT+WCMPCO,LEN=4
         @HEXOUT SDWACRC,WTOTXT+WCRCO,LEN=4
         BAL   R6,PUTWTO
*  ---- FORMAT SDWA: PSW AT ERROR -------------------------------
         MVC   WTOTXT,MSGPSW
         @HEXOUT SDWAEC1,WTOTXT+WPSWO,LEN=8
         BAL   R6,PUTWTO
*  ---- DECIDE: RETRY OR PERCOLATE (TASK 4 ADDS PERCOLATE) ------
         SETRP RC=4,RETADDR=RETRYPT,RETREGS=YES,FRESDWA=YES
         LR    R14,R3              RESTORE RTM RETURN ADDRESS
         BR    R14
*  ---- NO SDWA: CANNOT INSPECT, PERCOLATE ----------------------
NOSDWA   DS    0H
         WTO   'ESTDEMO: NO SDWA - PERCOLATING',ROUTCDE=(11)
         LR    R14,R3
         BR    R14
         DROP  R2
         DROP  R11
```

Re-establish the mainline USING for any code physically after the exit:
the `* DATA` area uses no based references, so no `USING ESTDEMO,R12` is
needed after the `DROP`s. (Verify no `ASMAxxx USING` errors on assembly.)

- [ ] **Step 4: Add the PARAM adcon, SDWA mapping, messages, and hex offsets**

Add to the data area after `BADPACK`:

```hlasm
PGMBASEA DC    A(ESTDEMO)          CSECT BASE, PASSED TO EXIT VIA PARAM
```

Add messages after `MSGNORC` (the `....` are overwritten by `@HEXOUT`):

```hlasm
MSGREC   DC    CL71'ESTDEMO: RECOVERED VIA ESTAE, CONTINUING'
MSGCMPC  DC    CL71'ESTDEMO SDWA  ABEND=........  REASON=........'
WCMPCO   EQU   20                  OFFSET OF ABEND HEX IN MSGCMPC
WCRCO    EQU   38                  OFFSET OF REASON HEX IN MSGCMPC
MSGPSW   DC    CL71'ESTDEMO SDWA  PSW=................'
WPSWO    EQU   18                  OFFSET OF PSW HEX IN MSGPSW
```

Add the SDWA DSECT mapping just before `END ESTDEMO` (after the equates):

```hlasm
         IHASDWA
```

**Pin step:** `SDWACMPC`, `SDWACRC`, `SDWAEC1`, `SDWAPARM` are the intended
`IHASDWA` field names. On first assembly, any wrong spelling flags
`ASMA044E Undefined symbol`; open `ANDRE.EPE`... the live `IHASDWA` in the
listing (or `SYS1.MACLIB(IHASDWA)`) and correct to the actual names (e.g.
the PSW field may be `SDWAEC1`/`SDWANXT1`; the abend code `SDWACMPC` vs
`SDWAABCC`). Likewise confirm `WCMPCO/WCRCO/WPSWO` match where the `....`
sit in each message by counting from the listing. Re-assemble until clean.

- [ ] **Step 5: Assemble, link, run PARM='RETRY' — verify RC 0 + report**

Build loop, then run `PARM='RETRY'`. Expected: step RC **0000**; JESMSGLG (in order): `ABOUT TO EXECUTE CVB`, `SDWA ABEND=000000C7 REASON=...`, `SDWA PSW=...`, `RECOVERED VIA ESTAE, CONTINUING`. The abend hex must read `...0C7`.
```bash
zowe jobs view all-spool-content <JOBID> | grep -iE "ESTDEMO|0C7"
```

- [ ] **Step 6: Commit**

```bash
git add 04-estae-demo/src/ESTDEMO.asm
git commit -m "artifact 4: ESTAEX recovery routine, SDWA format to WTO, RETRY path"
```

---

## Task 4: PERCOLATE path

Make `SETRP` choose retry vs percolate from `MODEFLAG`, so `PARM='PERCOLATE'` reports then lets the S0C7 stand.

**Files:**
- Modify: `04-estae-demo/src/ESTDEMO.asm`

- [ ] **Step 1: Branch on MODEFLAG before SETRP**

Replace the single `SETRP RC=4,...` line (and the two lines after it down to `BR R14`) in `RECVEXIT` with:

```hlasm
         CLI   MODEFLAG,MODEPERC
         JE    DOPERC
         SETRP RC=4,RETADDR=RETRYPT,RETREGS=YES,FRESDWA=YES
         J     EXITRTM
DOPERC   DS    0H
         MVC   WTOTXT,MSGPERC      "PERCOLATING"
         BAL   R6,PUTWTO
         SETRP RC=0,DUMP=NO        LET THE ABEND PERCOLATE
EXITRTM  DS    0H
         LR    R14,R3              RESTORE RTM RETURN ADDRESS
         BR    R14
```

- [ ] **Step 2: Add the percolate message**

Add after `MSGPSW`/`WPSWO`:

```hlasm
MSGPERC  DC    CL71'ESTDEMO: PERCOLATING - ABEND NOT SUPPRESSED'
```

- [ ] **Step 3: Assemble, link — verify clean**

Build loop. Expected: assemble ≤ 4, LINK RC 0.

- [ ] **Step 4: Run both PARMs — verify behaviors differ**

`PARM='RETRY'` → step RC **0000** + `RECOVERED` line (Task 3 behavior intact). `PARM='PERCOLATE'` → step **ABEND S0C7**, JESMSGLG shows the SDWA report + `PERCOLATING - ABEND NOT SUPPRESSED`, and **no** `RECOVERED` line.
```bash
zowe jobs view spool-file-by-id <JOBID> 4 | grep -iE "S0C7|ABEND"
```

- [ ] **Step 5: Commit**

```bash
git add 04-estae-demo/src/ESTDEMO.asm
git commit -m "artifact 4: PERCOLATE path via MODEFLAG/SETRP RC=0"
```

---

## Task 5: Run JCL, docs, status

Package the two-step demonstration run and finish the artifact's docs.

**Files:**
- Create: `04-estae-demo/jcl/RUNEST.jcl`
- Modify: `04-estae-demo/README.md`
- Modify: `mainframe-portfolio/CLAUDE.md`

- [ ] **Step 1: Write the run JCL** — `04-estae-demo/jcl/RUNEST.jcl`

```jcl
//ANDREB    JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*------------------------------------------------------------------*
//*  DEMONSTRATE BOTH RECOVERY PATHS                                 *
//*------------------------------------------------------------------*
//RETRY   EXEC PGM=ESTDEMO,PARM='RETRY'
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//SYSUDUMP DD  SYSOUT=*
//*------------------------------------------------------------------*
//PERC    EXEC PGM=ESTDEMO,PARM='PERCOLATE',COND=EVEN
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//SYSUDUMP DD  SYSOUT=*
```

- [ ] **Step 2: Run the demonstration job and capture output**

```bash
zowe jobs submit local-file "04-estae-demo/jcl/RUNEST.jcl" --wait-for-output --rfj
zowe jobs view spool-file-by-id <JOBID> 4   # RETRY step RC 0; PERC step S0C7
zowe jobs view all-spool-content <JOBID>    # both SDWA reports in JESMSGLG
```
Expected: `RETRY` step COND CODE 0000; `PERC` step ABEND S0C7. Copy the actual JESMSGLG report lines for the README.

- [ ] **Step 3: Fill in `04-estae-demo/README.md`**

Replace the `## Build instructions` placeholder section with concrete build/run instructions modeled on `03-sysout-scraper/README.md` (upload `src/ESTDEMO.asm` as `ANDRE.EPE.ASM(ESTDEMO)`; submit `jcl/BUILDEST.jcl`; run `jcl/RUNEST.jcl`), the return-code table (RETRY→0, PERCOLATE→S0C7, bad PARM→8), and paste the **verified** JESMSGLG report captured in Step 2. End with `> Status: **Complete** — assembled, linked, and run on system ZS31.`

- [ ] **Step 4: Flip the status in `mainframe-portfolio/CLAUDE.md`**

Change the status table row:
```
| 4 | ESTAE Recovery Demo   | Not started |
```
to:
```
| 4 | ESTAE Recovery Demo   | Complete    |
```

- [ ] **Step 5: Commit**

```bash
git add 04-estae-demo/jcl/RUNEST.jcl 04-estae-demo/README.md mainframe-portfolio/CLAUDE.md
git commit -m "artifact 4: run JCL, README with verified output, status -> Complete"
```

---

## Self-Review (completed during planning)

- **Spec coverage:** PARM selection (T1), S0C7 trigger (T2), ESTAEX + SDWA format + WTO + RETRY (T3), PERCOLATE (T4), build/run JCL + docs + status (T5). RMODE ANY / no-DCB and `WTO ROUTCDE=(11)` are realized by the WTO-only design throughout. All DESIGN sections map to a task.
- **Placeholder scan:** The only deferred items are explicit **pin-against-live-macro** steps (SDWA field spellings, WTO MF=L text offset) — inherent to HLASM-on-host where the assembler is the type-checker, not vague TODOs. Each names exactly what to confirm and how.
- **Name consistency:** `MODEFLAG`/`MODERTRY`/`MODEPERC`, `WTOTXT`/`PUTWTO`/`R6`, `RECVEXIT`/`RETRYPT`/`PGMBASEA`, and the `MSGxxx` buffers with `Wxxxx` offsets are used consistently across tasks. Register equates (R2 SDWA, R11 exit base, R12 mainline base, R6 WTO link) match the DESIGN register plan.
