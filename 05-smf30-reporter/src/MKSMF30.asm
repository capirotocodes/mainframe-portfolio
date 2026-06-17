*=====================================================================
* MKSMF30 - SYNTHETIC SMF TYPE 30 SUBTYPE 5 RECORD GENERATOR
*           BUILDS A SMALL RECFM=VBS DATASET OF JOB-TERMINATION
*           RECORDS (HEADER + IDENTIFICATION + PROCESSOR SECTIONS)
*           SO SMFRPT30 CAN BE TESTED WITHOUT REAL SMF DATA.
*           SECTIONS ARE MAPPED WITH THE REAL IFASMFR (30) DSECTS.
*=====================================================================
MKSMF30  CSECT
MKSMF30  AMODE 31
MKSMF30  RMODE 24
         @ENTER
         OPEN  (OUTDCB,(OUTPUT))
         TM    OUTDCB+48,X'10'     DCBOFLGS: DCBOFOPN - DID IT OPEN?
         BO    OPENOK
         ABEND 201,DUMP            OPEN FAILED -> U0201
OPENOK   DS    0H
         LA    R5,JOBTBL           -> FIRST TABLE ENTRY
         LA    R6,NJOBS            NUMBER OF RECORDS TO BUILD
GLOOP    DS    0H
*  ---- CLEAR THE RECORD BUILD AREA TO ZEROS ----------------------
         LA    R0,RECBUF
         LA    R1,RECLEN
         LA    R14,RECBUF
         SLR   R15,R15
         MVCL  R0,R14
*  ---- ESTABLISH ADDRESSABILITY OVER THE THREE SECTIONS ----------
         LA    R7,RECBUF
         USING SMFRCD30,R7
         LA    R8,RECBUF+RHDRLEN
         USING SMF30ID,R8
         LA    R9,RECBUF+RHDRLEN+RIDLEN
         USING SMF30CAS,R9
*  ---- SMF RECORD HEADER ----------------------------------------
         MVC   SMF30LEN,=AL2(RECLEN)    RDW LENGTH (WHOLE RECORD)
         MVI   SMF30RTY,30              RECORD TYPE 30
         MVC   SMF30STP,=AL2(5)         SUBTYPE 5 = JOB TERMINATION
         MVC   SMF30SID,=CL4'ZS31'      SYSTEM ID
         MVC   SMF30TME,TBTME-TBENT(R5) JOB END TIME (HUNDREDTHS)
         MVC   SMF30DTE,TBDTE-TBENT(R5) JOB END DATE (CYYDDDF)
         MVC   SMF30IOF,=A(RHDRLEN)     TRIPLET: ID SECTION OFFSET
         MVC   SMF30ILN,=AL2(RIDLEN)            ID SECTION LENGTH
         MVC   SMF30ION,=AL2(1)                 ID SECTION COUNT
         MVC   SMF30COF,=A(RHDRLEN+RIDLEN)  TRIPLET: PROC OFFSET
         MVC   SMF30CLN,=AL2(RCASLEN)           PROC SECTION LENGTH
         MVC   SMF30CON,=AL2(1)                 PROC SECTION COUNT
*  ---- IDENTIFICATION SECTION -----------------------------------
         MVC   SMF30JBN,TBJOB-TBENT(R5) JOB NAME
         MVC   SMF30PGM,=CL8'IEFBR14'   PROGRAM NAME
         MVC   SMF30STM,=CL8'STEP1'     STEP NAME
         MVC   SMF30RST,TBRST-TBENT(R5) READER-IN TIME (HUNDREDTHS)
         MVC   SMF30RSD,TBRSD-TBENT(R5) READER-IN DATE (CYYDDDF)
*  ---- PROCESSOR (CPU ACCOUNTING) SECTION -----------------------
         MVC   SMF30CPT,TBCPT-TBENT(R5) TCB CPU TIME (HUNDREDTHS)
         MVC   SMF30CPS,TBCPS-TBENT(R5) SRB CPU TIME (HUNDREDTHS)
*  ---- WRITE THE RECORD AND ADVANCE -----------------------------
         PUT   OUTDCB,RECBUF
         LA    R5,JTBLEN(,R5)
         BCT   R6,GLOOP
         CLOSE (OUTDCB)
         @LEAVE RC=0
*=====================================================================
* DATA
*=====================================================================
RHDRLEN  EQU   228                 SMFRCD30 SELF-DEFINING HDR LENGTH
RIDLEN   EQU   72                  GENERATED ID SECTION LENGTH
RCASLEN  EQU   16                  GENERATED PROCESSOR SECTION LENGTH
RECLEN   EQU   RHDRLEN+RIDLEN+RCASLEN
NJOBS    EQU   3
         DS    0F
RECBUF   DS    XL(RECLEN)          RECORD BUILD AREA
*  ---- TABLE: ONE ENTRY PER JOB RECORD --------------------------
         DS    0F
JOBTBL   DS    0F
TBENT    DS    0F                  ENTRY TEMPLATE (FOR FIELD OFFSETS)
TBJOB    DS    CL8                 JOB NAME
TBCPT    DS    F                   TCB CPU (HUNDREDTHS)
TBCPS    DS    F                   SRB CPU (HUNDREDTHS)
TBRST    DS    F                   READER-IN TIME (HUNDREDTHS)
TBRSD    DS    PL4                 READER-IN DATE (CYYDDDF)
TBTME    DS    F                   END TIME (HUNDREDTHS)
TBDTE    DS    PL4                 END DATE (CYYDDDF)
JTBLEN   EQU   *-TBENT
         ORG   TBENT
         DC    CL8'ANDREJ1',F'12345',F'678',F'3240000'
         DC    PL4'126163',F'3290000',PL4'126163'
         DC    CL8'PAYROLL',F'250000',F'1500',F'3600000'
         DC    PL4'126163',F'3960000',PL4'126163'
         DC    CL8'BACKUP',F'9999',F'1',F'3960000'
         DC    PL4'126163',F'3972000',PL4'126163'
         ORG
*=====================================================================
OUTDCB   DCB   DDNAME=OUTDD,DSORG=PS,MACRF=(PM),RECFM=VB,              X
               LRECL=4096,BLKSIZE=4100
*=====================================================================
         LTORG
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
         IFASMFR (30)
         END   MKSMF30
