*=====================================================================
* CBWALK  -  z/OS control block walker
*---------------------------------------------------------------------
* Purpose     : Walk PSA -> CVT -> ASCB -> TCB from address 0 and
*               print key identity fields from each block to SYSPRINT.
* Inputs      : None (reads live system storage).
* Outputs     : SYSPRINT report (RECFM=FBA,LRECL=121). RC 0 clean,
*               4 chain truncated / validation failed, 8 open failed.
* Registers   : R3 CVT, R4 ASCB, R5 TCB, R2 scratch, R6 link to
*               PUTHEX/PUTLINE; R7 live DCB (below 16M); R12 base,
*               R13 save area.
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
CBWALK   CSECT
CBWALK   AMODE 31
CBWALK   RMODE ANY
         @ENTER
*---------------------------------------------------------------------
* The CSECT is RMODE ANY, so the assembled DCB model lives above the
* 16M line. OPEN cannot open a DCB that resides above the line (z/OS
* issues IEC190I and DCBOFOPN stays off). So obtain storage BELOW the
* line, copy the model into it, and open that copy. R7 -> live DCB.
*---------------------------------------------------------------------
         GETMAIN RU,LV=DCBMLEN,LOC=BELOW
         LR    R7,R1               R7 -> below-the-line DCB
         MVC   0(DCBMLEN,R7),DCBMODL  copy DCB model below the line
*---------------------------------------------------------------------
* Open the report; fall to NOOPEN (RC=8) if it did not open
*---------------------------------------------------------------------
         OPEN  ((R7),OUTPUT),MODE=31
         USING IHADCB,R7
         TM    DCBOFLGS,DCBOFOPN   did SYSPRINT open?
         DROP  R7
         BNO   NOOPEN
*---------------------------------------------------------------------
* Title line
*---------------------------------------------------------------------
         MVI   LINE,C'1'           ANSI: page eject
         MVC   LINE+1(L'TITLE),TITLE
         BAL   R6,PUTLINE
*---------------------------------------------------------------------
* PSA  (address 0) - capture the chain pointers
*---------------------------------------------------------------------
         USING PSA,0
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
         LTR   R3,R3               CVT pointer present?
         BNZ   CVTOK
         MVC   LINE+5(L'EZCVT),EZCVT
         BAL   R6,PUTLINE
         OI    FLAGS,FLBADCB
         B     WALKEND             report, close, return RC=4
CVTOK    DS    0H
*---------------------------------------------------------------------
* CVT
*---------------------------------------------------------------------
         USING CVT,R3
         MVI   LINE,C'0'
         MVC   LINE+1(L'HCVT),HCVT
         BAL   R6,PUTLINE
         MVC   LINE+5(L'LSNAME),LSNAME
         MVC   LINE+25(8),CVTSNAME
         BAL   R6,PUTLINE
         L     R2,CVTECVT            -> ECVT
         ST    R2,WORD
         MVC   LINE+5(L'LECVT),LECVT
         BAL   R6,PUTHEX
         DROP  R3
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
*---------------------------------------------------------------------
WALKEND  DS    0H
         CLOSE ((R7)),MODE=31
         FREEMAIN RU,LV=DCBMLEN,A=(R7)
         TM    FLAGS,FLBADCB       any validation failure?
         BO    LEAVE4
         @LEAVE RC=0
LEAVE4   @LEAVE RC=4
*---------------------------------------------------------------------
* SYSPRINT failed to open - nothing to report
*---------------------------------------------------------------------
NOOPEN   DS    0H
         FREEMAIN RU,LV=DCBMLEN,A=(R7)
         @LEAVE RC=8
*---------------------------------------------------------------------
* PUTHEX : format WORD as 8 hex chars at LINE+25, then print.
* PUTLINE: print LINE, then blank it for reuse. Return via R6.
*---------------------------------------------------------------------
PUTHEX   DS    0H
         @HEXOUT WORD,LINE+25,LEN=4
PUTLINE  PUT   (R7),LINE
         MVI   LINE,C' '
         MVC   LINE+1(L'LINE-1),LINE
         BR    R6
*---------------------------------------------------------------------
* Constants and work areas
*---------------------------------------------------------------------
         LTORG
TITLE    DC    C'z/OS CONTROL BLOCK WALK'
HPSA     DC    C'PSA  @ 00000000'
LCVT     DC    C'FLCCVT  (CVT) '
LASCB    DC    C'PSAAOLD (ASCB)'
LTCB     DC    C'PSATOLD (TCB) '
HCVT     DC    C'CVT'
LSNAME   DC    C'CVTSNAME (sys) '
LECVT    DC    C'CVTECVT (ECVT)'
HASCB    DC    C'ASCB'
LASID    DC    C'ASCBASID (id) '
LJOB     DC    C'JOBNAME       '
EBADASC  DC    C'** ASCB eyecatcher invalid - chain stops'
HTCB     DC    C'TCB'
LRBP     DC    C'TCBRBP  (RB)  '
LCMP     DC    C'TCBCMP  (comp)'
EZTCB    DC    C'** TCB pointer is zero - chain broken'
EZCVT    DC    C'** CVT pointer is zero - chain broken'
FLAGS    DC    X'00'
FLBADCB  EQU   X'80'
WORD     DC    F'0'
LINE     DC    CL121' '
         @HEXOUT MODE=DEFINE
*---------------------------------------------------------------------
* DCB model (assembled above the line; copied below the line at run
* time). DCBMLEN is the model length used for GETMAIN and the copy.
*---------------------------------------------------------------------
DCBMODL  DCB   DSORG=PS,MACRF=PM,RECFM=FBA,LRECL=121,DDNAME=SYSPRINT
DCBMLEN  EQU   *-DCBMODL
*---------------------------------------------------------------------
* DSECTs (IBM-supplied)
*---------------------------------------------------------------------
         DCBD  DSORG=PS
         IHAPSA
         CVT   DSECT=YES,LIST=YES
         IHAASCB
         IKJTCB
         END   CBWALK
