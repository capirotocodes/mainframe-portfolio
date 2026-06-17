# Control Block Walker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `CBWALK`, a batch HLASM program that walks PSA → CVT → ASCB → TCB from address 0 and prints key identity fields from each block to a SYSPRINT report.

**Architecture:** Single CSECT, AMODE 31/RMODE ANY, standard linkage via the artifact-1 macros (`@ENTER`/`@LEAVE`/`@HEXOUT`). One linear section per control block, each establishing `USING` on an IBM DSECT, validating, formatting with `@HEXOUT`, and `PUT`-ting lines through one shared `PUTHEX`/`PUTLINE` subroutine. Report is QSAM `RECFM=FBA,LRECL=121` with ANSI carriage control.

**Tech Stack:** z/OS HLASM (ASMA90), QSAM (`OPEN`/`PUT`/`CLOSE`), IBM DSECTs `IHAPSA`/`CVT`/`IHAASCB`/`IKJTCB`/`DCBD`, Zowe CLI build loop.

---

## Conventions for every task

- **Build loop (the "test"):** after editing `src/CBWALK.asm`:
  ```powershell
  zowe files upload ftds "src\CBWALK.asm" "ANDRE.EPE.ASM(CBWALK)"
  zowe jobs submit local-file "jcl/BUILDCBW.jcl" --wait-for-output --rfj
  ```
  Then read the spool of the returned `JOBnnnnn`:
  ```powershell
  zowe jobs list spool-files-by-jobid JOBnnnnn
  zowe jobs view spool-file-by-id JOBnnnnn 2      # JESMSGLG: step RCs / abends
  zowe jobs view spool-file-by-id JOBnnnnn <id>   # ASM SYSPRINT / report
  ```
- **Column 71 rule:** no source line may have a non-blank past column 71 — HLASM treats column 72 as a continuation indicator (this exact bug cost us an assembly in artifact 1). Verify before every upload:
  ```powershell
  $n=0; Get-Content "src\CBWALK.asm" | %{ $n++; if($_.Length -gt 71){"line $n len $($_.Length)"} }
  ```
- **Field-name caveat:** all block fields are read through IBM DSECTs, so a wrong name fails at assembly with `ASMA044E/057E` (undefined symbol) — never at runtime. If a field name is rejected, open the DSECT expansion in the ASM listing (`LIST` is on) and use the correct spelling. Suspect names are flagged per task.
- **No git:** this workspace is not a git repo. "Checkpoint" = a clean build + the expected report verified on-system, not a commit.

---

## File structure

- Create: `src/CBWALK.asm` — the program (one CSECT, built up across Tasks 1–6).
- Create: `jcl/BUILDCBW.jcl` — assemble + link + run JCL (Task 1).
- Modify: `README.md` — fill in build instructions + sample output (Task 7).
- Modify: `../CLAUDE.md` — flip artifact 2 status to Complete (Task 7).

---

## Task 1: Toolchain + report scaffold

Get a minimal program that opens SYSPRINT, prints a title, and returns RC=0 — proving the datasets, SYSLIB concatenation, and QSAM I/O all work before any control-block code.

**Files:**
- Create: `jcl/BUILDCBW.jcl`
- Create: `src/CBWALK.asm`

- [ ] **Step 1: Write the build JCL** — `jcl/BUILDCBW.jcl`

```jcl
//CBWALKB  JOB (ACCT),'BUILD CBWALK',CLASS=A,MSGCLASS=H,
//             NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Assemble, link-edit, and run CBWALK (control block walker).
//* PREREQ: src\CBWALK.asm uploaded as ANDRE.EPE.ASM(CBWALK).
//* SYSLIB: ANDRE.EPE.MACLIB (@ENTER/@LEAVE/@HEXOUT) ahead of the IBM
//*         macro/DSECT libraries.
//*-------------------------------------------------------------------
//ASM      EXEC PGM=ASMA90,REGION=0M,
//             PARM='OBJECT,NODECK,LIST,XREF(SHORT)'
//SYSLIB   DD  DISP=SHR,DSN=ANDRE.EPE.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MODGEN
//SYSIN    DD  DISP=SHR,DSN=ANDRE.EPE.ASM(CBWALK)
//SYSLIN   DD  DISP=(,PASS),DSN=&&OBJ,UNIT=SYSDA,
//             SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSPRINT DD  SYSOUT=*
//*-------------------------------------------------------------------
//LKED     EXEC PGM=IEWL,COND=(0,LT,ASM),
//             PARM='LIST,MAP,XREF,RMODE=ANY,AMODE=31'
//SYSLIN   DD  DISP=(OLD,DELETE),DSN=&&OBJ
//SYSLMOD  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD(CBWALK)
//SYSPRINT DD  SYSOUT=*
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//*-------------------------------------------------------------------
//RUN      EXEC PGM=CBWALK,COND=(0,LT,LKED)
//STEPLIB  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//
```

- [ ] **Step 2: Write the scaffold program** — `src/CBWALK.asm`

```hlasm
*=====================================================================
* CBWALK  -  z/OS control block walker
*---------------------------------------------------------------------
* Purpose     : Walk PSA -> CVT -> ASCB -> TCB from address 0 and
*               print key identity fields from each block to SYSPRINT.
* Inputs      : None (reads live system storage).
* Outputs     : SYSPRINT report (RECFM=FBA,LRECL=121). RC 0 clean,
*               4 chain truncated / validation failed, 8 open failed.
* Registers   : R3 CVT, R4 ASCB, R5 TCB, R2 scratch, R6 link to
*               PUTHEX/PUTLINE; R12 base, R13 save area.
* Preserved   : Caller registers saved by @ENTER.
* Dependencies: @ENTER @LEAVE @HEXOUT (ANDRE.EPE.MACLIB); IHAPSA CVT
*               IHAASCB IKJTCB DCBD (SYS1.MACLIB / SYS1.MODGEN).
* Sample      : See ../jcl/BUILDCBW.jcl
*=====================================================================
R0       EQU   0
R1       EQU   1
R2       EQU   2
R3       EQU   3
R4       EQU   4
R5       EQU   5
R6       EQU   6
R7       EQU   7
R8       EQU   8
R9       EQU   9
R10      EQU   10
R11      EQU   11
R12      EQU   12
R13      EQU   13
R14      EQU   14
R15      EQU   15
*---------------------------------------------------------------------
CBWALK   CSECT
CBWALK   AMODE 31
CBWALK   RMODE ANY
         @ENTER
*---------------------------------------------------------------------
* Open the report; fall to NOOPEN (RC=8) if it did not open
*---------------------------------------------------------------------
         OPEN  (SYSPRINT,OUTPUT),MODE=31
         LA    R1,SYSPRINT
         USING IHADCB,R1
         TM    DCBOFLGS,DCBOFOPN    did SYSPRINT open?
         DROP  R1
         BNO   NOOPEN
*---------------------------------------------------------------------
* Title line
*---------------------------------------------------------------------
         MVI   LINE,C'1'           ANSI: page eject
         MVC   LINE+1(L'TITLE),TITLE
         BAL   R6,PUTLINE
*---------------------------------------------------------------------
* (control-block sections added in later tasks)
*---------------------------------------------------------------------
WALKEND  DS    0H
         CLOSE (SYSPRINT),MODE=31
         @LEAVE RC=0
*---------------------------------------------------------------------
* SYSPRINT failed to open - nothing to report
*---------------------------------------------------------------------
NOOPEN   DS    0H
         @LEAVE RC=8
*---------------------------------------------------------------------
* PUTHEX : format WORD as 8 hex chars at LINE+25, then print.
* PUTLINE: print LINE, then blank it for reuse. Return via R6.
*---------------------------------------------------------------------
PUTHEX   DS    0H
         @HEXOUT WORD,LINE+25,LEN=4
PUTLINE  PUT   SYSPRINT,LINE
         MVI   LINE,C' '
         MVC   LINE+1(L'LINE-1),LINE
         BR    R6
*---------------------------------------------------------------------
* Constants and work areas
*---------------------------------------------------------------------
         LTORG
TITLE    DC    C'z/OS CONTROL BLOCK WALK'
WORD     DC    F'0'
LINE     DC    CL121' '
         @HEXOUT MODE=DEFINE
*---------------------------------------------------------------------
* I/O
*---------------------------------------------------------------------
SYSPRINT DCB   DSORG=PS,MACRF=PM,RECFM=FBA,LRECL=121,DDNAME=SYSPRINT
*---------------------------------------------------------------------
* DSECTs (IBM-supplied)
*---------------------------------------------------------------------
         DCBD  DSORG=PS
         IHAPSA
         CVT   DSECT=YES,LIST=YES
         IHAASCB
         IKJTCB
         END   CBWALK
```

- [ ] **Step 3: Column-71 check** — run the PowerShell length check above. Expected: no output.

- [ ] **Step 4: Upload + build + run**

```powershell
zowe files upload ftds "src\CBWALK.asm" "ANDRE.EPE.ASM(CBWALK)"
zowe jobs submit local-file "jcl/BUILDCBW.jcl" --wait-for-output --rfj
```
Expected: `retcode: CC 0000`.

- [ ] **Step 5: Verify the report** — view the RUN step SYSPRINT (find its id via `list spool-files-by-jobid`). Expected: a page with `z/OS CONTROL BLOCK WALK`.

If `DCBOFOPN`/`DCBOFLGS` are rejected, confirm `DCBD DSORG=PS` is present (it generates `IHADCB` and those equates). If `CVT DSECT=YES,LIST=YES` errors, try plain `CVT` — installations differ.

- [ ] **Step 6: Checkpoint** — clean assemble (sev ≤4), LKED RC=0, RUN RC=0, title prints.

> **Implemented note (post-build):** OPEN of an `RMODE ANY` (above-the-line) base DCB fails (`IEC190I`, `DCBOFOPN` off) even with `MODE=31`. Final scaffold keeps the DCB as a model (`DCBMODL`), does `GETMAIN RU,LV=DCBMLEN,LOC=BELOW`, copies the model below the line into storage addressed by **R7**, opens `((R7),OUTPUT),MODE=31`, and `FREEMAIN`s on both exits. `PUTHEX`/`PUTLINE` PUT to `(R7)`. Their interface (`BAL R6,PUTHEX` after setting `WORD`; `BAL R6,PUTLINE` after building `LINE`) is unchanged, so Tasks 2–6 are unaffected. See DESIGN.md "Below-the-line DCB".

---

## Task 2: PSA section (address 0) and the chain pointers

**Files:**
- Modify: `src/CBWALK.asm` — replace the `* (control-block sections added...)` comment block with the PSA section; add PSA constants.

- [ ] **Step 1: Insert the PSA section** (where the placeholder comment was)

```hlasm
*---------------------------------------------------------------------
* PSA  (address 0) - capture the chain pointers
*---------------------------------------------------------------------
         USING IHAPSA,0
         L     R3,FLCCVT           -> CVT
         L     R4,PSAAOLD          -> current ASCB
         L     R5,PSATOLD          -> current TCB
         DROP  0
         MVI   LINE,C'0'           ANSI: double space before header
         MVC   LINE+1(L'HPSA),HPSA
         BAL   R6,PUTLINE
         ST    R3,WORD
         MVC   LINE+5(L'LCVT),LCVT
         BAL   R6,PUTHEX
         ST    R4,WORD
         MVC   LINE+5(L'LASCB),LASCB
         BAL   R6,PUTHEX
         ST    R5,WORD
         MVC   LINE+5(L'LTCB),LTCB
         BAL   R6,PUTHEX
```

- [ ] **Step 2: Add PSA constants** (in the constants area, after `TITLE`)

```hlasm
HPSA     DC    C'PSA  @ 00000000'
LCVT     DC    C'FLCCVT  (CVT) '
LASCB    DC    C'PSAAOLD (ASCB)'
LTCB     DC    C'PSATOLD (TCB) '
```

Note: detail label sits at `LINE+5`, the 8-char hex value at `LINE+25`. The `=` is implied by the gap; if you prefer an explicit `=`, widen labels to include `' ='` and keep them within column 71.

- [ ] **Step 3: Column-71 check** — expected: no output.

- [ ] **Step 4: Upload + build + run** (same two commands as Task 1, Step 4). Expected `CC 0000`.

- [ ] **Step 5: Verify** — report shows the PSA header and three **non-zero** hex pointers. Sanity: `FLCCVT` typically looks like `00FDxxxx`/`00FExxxx`. Record the ASCB/TCB values to cross-check later.

- [ ] **Step 6: Checkpoint** — three plausible pointers printed; RUN RC=0.

---

## Task 3: CVT section

**Files:**
- Modify: `src/CBWALK.asm` — add the CVT section after the PSA section; add CVT constants.

- [ ] **Step 1: Insert the CVT section**

```hlasm
*---------------------------------------------------------------------
* CVT
*---------------------------------------------------------------------
         USING CVT,R3
         MVI   LINE,C'0'
         MVC   LINE+1(L'HCVT),HCVT
         BAL   R6,PUTLINE
         MVC   LINE+5(L'LSNAME),LSNAME
         MVC   LINE+25(8),CVTSNAME   system name (EBCDIC)
         BAL   R6,PUTLINE
         L     R2,CVTECVT            -> ECVT
         ST    R2,WORD
         MVC   LINE+5(L'LECVT),LECVT
         BAL   R6,PUTHEX
         DROP  R3
```

- [ ] **Step 2: Add CVT constants**

```hlasm
HCVT     DC    C'CVT'
LSNAME   DC    C'CVTSNAME (sys) '
LECVT    DC    C'CVTECVT (ECVT)'
```

- [ ] **Step 3: Column-71 check** — expected: no output.

- [ ] **Step 4: Upload + build + run.** Expected `CC 0000`.
  - If `CVTSNAME` is undefined at assembly, the system-name field differs on your level — check the `CVT` DSECT listing for the 8-byte EBCDIC system name (alternative: `L R2,CVTECVT` then map `IHAECVT` and read `ECVTSPLX`). Substitute and rebuild.

- [ ] **Step 5: Verify** — `CVTSNAME` prints this LPAR's name (we have seen `ZS31` in the JES logs). This is the key correctness check: a matching name proves the walk reads real storage, not plausible hex.

- [ ] **Step 6: Checkpoint** — system name matches the LPAR; RUN RC=0.

---

## Task 4: ASCB section with eyecatcher validation

**Files:**
- Modify: `src/CBWALK.asm` — add the ASCB section after the CVT section; add ASCB constants.

- [ ] **Step 1: Insert the ASCB section**

```hlasm
*---------------------------------------------------------------------
* ASCB (current address space) - validate eyecatcher first
*---------------------------------------------------------------------
         USING ASCB,R4
         MVI   LINE,C'0'
         MVC   LINE+1(L'HASCB),HASCB
         BAL   R6,PUTLINE
         CLC   ASCBASCB,=C'ASCB'    eyecatcher present?
         BE    ASCBOK
         MVC   LINE+5(L'EBADASC),EBADASC
         BAL   R6,PUTLINE
         OI    FLAGS,FLBADCB        remember: chain not fully clean
         B     WALKEND             skip ASCB detail and TCB
ASCBOK   DS    0H
         MVC   LINE+5(L'LASID),LASID
         SLR   R0,R0
         ICM   R0,B'0011',ASCBASID  ASID is a halfword
         ST    R0,WORD
         BAL   R6,PUTHEX
         L     R2,ASCBJBNI          jobname for initiated jobs
         LTR   R2,R2
         BNZ   HAVEJBN
         L     R2,ASCBJBNS          else started-task jobname
HAVEJBN  DS    0H
         MVC   LINE+5(L'LJOB),LJOB
         LTR   R2,R2                no jobname pointer?
         BZ    NOJOB
         MVC   LINE+25(8),0(R2)     8-byte EBCDIC jobname
         B     PUTJOB
NOJOB    MVC   LINE+25(8),=CL8'(none)'
PUTJOB   BAL   R6,PUTLINE
         DROP  R4
```

- [ ] **Step 2: Add ASCB constants and the flag byte** (constants area)

```hlasm
HASCB    DC    C'ASCB'
LASID    DC    C'ASCBASID (id) '
LJOB     DC    C'JOBNAME       '
EBADASC  DC    C'** ASCB eyecatcher invalid - chain stops'
FLAGS    DC    X'00'
FLBADCB  EQU   X'80'              a validation check failed
```

- [ ] **Step 3: Column-71 check** — expected: no output.

- [ ] **Step 4: Upload + build + run.** Expected `CC 0000`.
  - If `ASCB` (the DSECT name) or `ASCBASCB`/`ASCBASID`/`ASCBJBNI`/`ASCBJBNS` are undefined, check the `IHAASCB` listing. The DSECT name is `ASCB`; the eyecatcher field is `ASCBASCB`.

- [ ] **Step 5: Verify** — `ASCBASID` and `JOBNAME` match the running job. Find the job's ASID/owner in `zowe jobs view job-status-by-jobid JOBnnnnn` or SDSF; the report's ASID (hex) and jobname (`CBWALKB`) must agree.

- [ ] **Step 6: Checkpoint** — eyecatcher matched (no error line), ASID + jobname correct; RUN RC=0.

---

## Task 5: TCB section

**Files:**
- Modify: `src/CBWALK.asm` — add the TCB section; it is the branch target `TCBSKIP` for the ASCB failure path; add TCB constants.

- [ ] **Step 1: Insert the TCB section** (after the ASCB section)

```hlasm
*---------------------------------------------------------------------
* TCB (current task) - guard the pointer before dereferencing
*---------------------------------------------------------------------
         LTR   R5,R5               TCB pointer present?
         BNZ   TCBOK
         MVC   LINE+5(L'EZTCB),EZTCB
         BAL   R6,PUTLINE
         OI    FLAGS,FLBADCB
         B     WALKEND
TCBOK    DS    0H
         USING TCB,R5
         MVI   LINE,C'0'
         MVC   LINE+1(L'HTCB),HTCB
         BAL   R6,PUTLINE
         L     R2,TCBRBP            -> current RB
         ST    R2,WORD
         MVC   LINE+5(L'LRBP),LRBP
         BAL   R6,PUTHEX
         MVC   LINE+5(L'LCMP),LCMP
         L     R0,TCBCMP            completion code word
         ST    R0,WORD
         BAL   R6,PUTHEX
         DROP  R5
```

- [ ] **Step 2: Add TCB constants**

```hlasm
HTCB     DC    C'TCB'
LRBP     DC    C'TCBRBP  (RB)  '
LCMP     DC    C'TCBCMP  (comp)'
EZTCB    DC    C'** TCB pointer is zero - chain broken'
```

`FLAGS`/`FLBADCB` already exist from Task 4; the guard reuses them and routes to `WALKEND` (defined in the Task 1 scaffold).

- [ ] **Step 3: Column-71 check** — expected: no output.

- [ ] **Step 4: Upload + build + run.** Expected `CC 0000`.
  - If `TCB`/`TCBRBP`/`TCBCMP` are undefined, check the `IKJTCB` listing (DSECT name is `TCB`; `TCBRBP` is at offset 0).

- [ ] **Step 5: Verify** — report shows the full PSA→CVT→ASCB→TCB walk. `TCBCMP` should be `00000000` for a running task.

- [ ] **Step 6: Checkpoint** — all four blocks reported in order; RUN RC=0.

---

## Task 6: Pointer guards and return codes

Harden the walk: refuse to dereference a zero pointer (report + truncate), and set the documented return codes. The ASCB eyecatcher path already sets `FLBADCB` in Task 4.

**Files:**
- Modify: `src/CBWALK.asm` — add zero-pointer guards after capturing the pointers (Task 2 area) and replace the final `@LEAVE RC=0` with a computed return code.

- [ ] **Step 1: Guard the CVT pointer immediately after `DROP 0` in the PSA section**

```hlasm
         LTR   R3,R3               CVT pointer present?
         BNZ   CVTOK
         MVC   LINE+5(L'EZCVT),EZCVT
         BAL   R6,PUTLINE
         OI    FLAGS,FLBADCB
         B     WALKEND             report, close, return RC=4
CVTOK    DS    0H
```

Only the CVT pointer needs an explicit guard here: a zero/garbage **ASCB** fails the `CLC ASCBASCB,=C'ASCB'` eyecatcher check (Task 4) and routes to `WALKEND`, and the **TCB** pointer is guarded at the top of its section (Task 5). Routing through `WALKEND` (not a bare `@LEAVE`) guarantees `CLOSE` runs so the error line is flushed to SYSPRINT.

- [ ] **Step 2: Add the error constant** (constants area)

```hlasm
EZCVT    DC    C'** CVT pointer is zero - chain broken'
```

- [ ] **Step 3: Replace the final `@LEAVE RC=0`** at `WALKEND` (the one right after `CLOSE (SYSPRINT)` from the Task 1 scaffold) with the computed return code

```hlasm
WALKEND  DS    0H
         CLOSE (SYSPRINT),MODE=31
         TM    FLAGS,FLBADCB       any validation failure?
         BO    LEAVE4
         @LEAVE RC=0
LEAVE4   @LEAVE RC=4
```

- [ ] **Step 4: Column-71 check** — expected: no output.

- [ ] **Step 5: Upload + build + run.** Expected `CC 0000` (normal path: all pointers valid, eyecatcher matches → RC=0).

- [ ] **Step 6: Verify** — normal run is `RC=0000` and the report is unchanged from Task 5. The guard paths are defensive; we do not expect to trigger them on a healthy system.

- [ ] **Step 7: Checkpoint** — RC=0 on the healthy path; guard code assembles and is reachable.

---

## Task 7: README and status

**Files:**
- Modify: `README.md`
- Modify: `../CLAUDE.md`

- [ ] **Step 1: Fill in `README.md` build section** — replace the placeholder with the real build/run instructions and a captured sample of the report (paste the actual SYSPRINT from the Task 6 run, including the verified system name/ASID).

- [ ] **Step 2: Update the status table in `../CLAUDE.md`** — change artifact 2 from `Not started` to `Complete`:

```markdown
| 2 | Control Block Walker  | Complete    |
```

- [ ] **Step 3: Verify** — README reflects the real member/dataset names (`ANDRE.EPE.ASM(CBWALK)`, `ANDRE.EPE.LOAD(CBWALK)`) and the sample matches a real run.

- [ ] **Step 4: Checkpoint** — docs match the built artifact; status table updated.

---

## Notes for the implementer

- **Why `USING IHAPSA,0`:** register 0 as a `USING` base contributes 0 to the effective address, so PSA fields resolve to their absolute low-storage locations. `DROP 0` as soon as the three pointers are captured so nothing else accidentally addresses off base 0.
- **Why one `PUTHEX`/`PUTLINE` pair:** keeps line output DRY; `@HEXOUT` is expanded once, at `PUTHEX`. `BAL R6,...` is safe because QSAM `PUT` and `@HEXOUT` clobber R0/R1/R14/R15 but not R6.
- **ASID is a halfword:** `ICM R0,B'0011',ASCBASID` zero-extends it into a word before `@HEXOUT` (which formats 4 bytes).
- **Carriage control:** byte 1 of `LINE` — `'1'` eject (title), `'0'` double-space (block headers), `' '` single-space (detail). `PUTLINE` re-blanks `LINE` (byte 1 back to `' '`) after each write.
- **Non-reentrant by design:** static `LINE`/`WORD`/DCB, consistent with artifact 1. A reentrant variant would `GETMAIN` the work areas and use `RDJFCB`/`OPEN` on a dynamic DCB.
```
