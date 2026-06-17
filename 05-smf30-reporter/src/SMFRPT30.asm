*=====================================================================
* SMFRPT30 - SMF TYPE 30 (SUBTYPE 5) JOB CPU / ELAPSED REPORTER
*            READS A RECFM=VBS SMF DATASET WITH QSAM GET LOCATE MODE,
*            MAPS RECORDS WITH THE IFASMFR (30) DSECTS, AND PRINTS
*            ONE LINE PER JOB-TERMINATION RECORD:
*               JOB NAME | CPU SECONDS | ELAPSED SECONDS
*            CPU     = (SMF30CPT + SMF30CPS) / 100   (HUNDREDTHS)
*            ELAPSED = (SMF30TME - SMF30RST) / 100   (SAME-DAY)
*=====================================================================
SMFRPT30 CSECT
SMFRPT30 AMODE 31
SMFRPT30 RMODE 24
         @ENTER
         OPEN  (INDCB,(INPUT),RPTDCB,(OUTPUT))
         PUT   RPTDCB,HDR1         REPORT TITLE  (NEW PAGE)
         PUT   RPTDCB,HDR2         COLUMN HEADINGS
*  ---- MAIN READ LOOP (GET LOCATE: R1 -> LOGICAL RECORD) --------
RLOOP    DS    0H
         GET   INDCB
         LR    R7,R1
         USING SMFRCD30,R7
         CLI   SMF30RTY,30         TYPE 30 ?
         BNE   RLOOP
         CLC   SMF30STP,=AL2(5)    SUBTYPE 5 (JOB END) ?
         BNE   RLOOP
*  ---- LOCATE IDENTIFICATION SECTION VIA ITS TRIPLET ------------
         ICM   R8,B'1111',SMF30IOF OFFSET TO ID SECTION
         BZ    RLOOP              NOT PRESENT -> SKIP
         AR    R8,R7              ABSOLUTE ADDRESS
         USING SMF30ID,R8
*  ---- LOCATE PROCESSOR SECTION VIA ITS TRIPLET ----------------
         ICM   R9,B'1111',SMF30COF OFFSET TO PROCESSOR SECTION
         BZ    RLOOP
         AR    R9,R7
         USING SMF30CAS,R9
*  ---- CPU = SMF30CPT + SMF30CPS (HUNDREDTHS OF A SECOND) -------
         MVC   WCPT,SMF30CPT      COPY TO ALIGNED WORK FIELDS
         MVC   WCPS,SMF30CPS
         L     R2,WCPT
         A     R2,WCPS
*  ---- ELAPSED = SMF30TME - SMF30RST (HUNDREDTHS, SAME-DAY) -----
         MVC   WTME,SMF30TME
         MVC   WRST,SMF30RST
         L     R3,WTME
         S     R3,WRST
*  ---- FORMAT THE DETAIL LINE ----------------------------------
         MVI   DTLCC,C' '         SINGLE SPACE
         MVC   DTLJOB,SMF30JBN
         CVD   R2,DW
         MVC   DTLCPU,EDMASK
         ED    DTLCPU,DW+2
         CVD   R3,DW
         MVC   DTLELP,EDMASK
         ED    DTLELP,DW+2
         PUT   RPTDCB,DTLINE
         B     RLOOP
*  ---- END OF INPUT (EODAD) ------------------------------------
RATEOF   DS    0H
         CLOSE (INDCB,,RPTDCB)
         @LEAVE RC=0
*=====================================================================
* DATA
*=====================================================================
         DS    0D
DW       DS    D                  CVD PACKED WORK
WCPT     DS    F
WCPS     DS    F
WTME     DS    F
WRST     DS    F
EDMASK   DC    X'402020202020202020214B2020'  9 INT,'.',2 DEC
*  ---- REPORT TITLE / HEADINGS (RECFM=FBA, COL1 = ASA CC) ------
HDR1     DC    CL133'1  SMF TYPE 30 SUBTYPE 5 - JOB CPU/ELAPSED RPT'
HDR2     DC    CL133' '
         ORG   HDR2+2
         DC    C'JOB NAME'
         ORG   HDR2+15
         DC    C'   CPU (SEC)'
         ORG   HDR2+31
         DC    C'ELAPSED (SEC)'
         ORG
*  ---- DETAIL LINE LAYOUT --------------------------------------
DTLINE   DC    CL133' '
DTLCC    EQU   DTLINE,1            CARRIAGE CONTROL
DTLJOB   EQU   DTLINE+2,8          JOB NAME
DTLCPU   EQU   DTLINE+14,13        CPU SECONDS  (EDITED)
DTLELP   EQU   DTLINE+30,13        ELAPSED SECONDS (EDITED)
*=====================================================================
INDCB    DCB   DDNAME=INDD,DSORG=PS,MACRF=(GL),EODAD=RATEOF
RPTDCB   DCB   DDNAME=RPTDD,DSORG=PS,MACRF=(PM),RECFM=FBA,             X
               LRECL=133,BLKSIZE=1330
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
         END   SMFRPT30
