*=====================================================================
* ESTDEMO -  ESTAE recovery demonstration
*---------------------------------------------------------------------
* Purpose     : Deliberately abend (S0C7), recover in an ESTAEX exit,
*               format key SDWA fields to WTO, then RETRY (resume once,
*               RC 0), PERCOLATE (let it stand), or LOOP (re-drive
*               the failing instruction under a BOUNDED retry counter).
* Inputs      : EXEC PARM=RETRY (default), PARM=PERC, or PARM=LOOP.
* Outputs     : WTO diagnostics to JESMSGLG (ROUTCDE=11). Step RC 0 on
*               retry; step abends S0C7 on percolate or once the LOOP
*               retry limit is exceeded; RC 8 if ESTAEX cannot be set.
* Registers   : Mainline R12 base, R13 save area, R5 -> RECAREA.
*               Recovery R3 -> SDWA, R12 reloaded base, R4 retry addr,
*               R5 retry count.
* Preserved   : Caller registers saved by @ENTER.
* Dependencies: @ENTER @LEAVE @HEXOUT (ANDRE.EPE.MACLIB); ESTAEX SETRP
*               WTO IHASDWA (SYS1.MACLIB / SYS1.MODGEN).
* Sample      : See ../jcl/RUNEST.jcl
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
MAXRETRY EQU   3          LOOP mode retry limit
ESTDEMO  CSECT
ESTDEMO  AMODE 31
ESTDEMO  RMODE ANY
         @ENTER
*---------------------------------------------------------------------
* Parse PARM:  R1 -> parm list, the entry -> halfword length + text.
* PARM=PERC -> percolate; PARM=LOOP -> bounded retry loop; else retry.
*---------------------------------------------------------------------
         MVI   MODEFLG,C'R'        default = retry once
         L     R2,0(,R1)           R2 -> parm string (LEN + text)
         LH    R3,0(,R2)           R3 = parm text length
         LTR   R3,R3               no parm at all?
         BZ    PARMSET
         CH    R3,=H'4'            shorter than a 4-char keyword?
         BL    PARMSET
         CLC   2(4,R2),=C'PERC'    percolate requested?
         BNE   TRYLOOP
         MVI   MODEFLG,C'P'
         B     PARMSET
TRYLOOP  CLC   2(4,R2),=C'LOOP'    bounded retry loop requested?
         BNE   PARMSET
         MVI   MODEFLG,C'L'
PARMSET  DS    0H
*---------------------------------------------------------------------
* Start banner naming the chosen mode
*---------------------------------------------------------------------
         CLI   MODEFLG,C'P'
         BE    BANPERC
         CLI   MODEFLG,C'L'
         BE    BANLOOP
         WTO   'ESTDEMO STARTING - RETRY MODE',ROUTCDE=(11)
         B     BANDONE
BANPERC  WTO   'ESTDEMO STARTING - PERCOLATE MODE',ROUTCDE=(11)
         B     BANDONE
BANLOOP  WTO   'ESTDEMO STARTING - LOOP MODE',ROUTCDE=(11)
BANDONE  DS    0H
*---------------------------------------------------------------------
* Build the recovery parameter area: eyecatcher, mode, my base
* register, the two resume addresses, and a zeroed retry counter.
*---------------------------------------------------------------------
         LA    R5,RECAREA
         USING RECPARM,R5
         MVC   RPEYE,=C'RPRM'
         MVC   RPMODE,MODEFLG
         ST    R12,RPBASE          save base for the recovery exit
         LA    R0,RESUME           retry-once resume point
         ST    R0,RPRESUME
         LA    R0,ABENDPT          loop resume = re-drive the abend
         ST    R0,RPABEND
         XC    RPRETRY,RPRETRY     retry counter = 0
         DROP  R5
*---------------------------------------------------------------------
* Establish the recovery routine, then force the abend.
*---------------------------------------------------------------------
         ESTAEX RECEXIT,PARAM=RECAREA,TERM=YES
         LTR   R15,R15             established cleanly?
         BNZ   ESTFAIL
         WTO   'ESTDEMO - FORCING S0C7 NOW',ROUTCDE=(11)
ABENDPT  DS    0H                  LOOP mode resumes here to re-fail
         AP    BADPACK(4),PONE(2)  invalid packed -> S0C7
*---------------------------------------------------------------------
* Reaching here means the abend did not occur - unexpected.
*---------------------------------------------------------------------
         WTO   'ESTDEMO - ABEND DID NOT OCCUR',ROUTCDE=(11)
         @LEAVE RC=8
*---------------------------------------------------------------------
* RESUME - retry-once resumes here with mainline registers restored.
*---------------------------------------------------------------------
RESUME   DS    0H
         ESTAEX 0                  cancel the recovery routine
         WTO   'ESTDEMO - RECOVERED VIA RETRY, CONTINUING',ROUTCDE=(11)
         @LEAVE RC=0
*---------------------------------------------------------------------
* ESTAEX could not be established
*---------------------------------------------------------------------
ESTFAIL  DS    0H
         WTO   'ESTDEMO - ESTAEX ESTABLISH FAILED',ROUTCDE=(11)
         @LEAVE RC=8
*=====================================================================
* RECEXIT - the ESTAEX recovery routine.
*   R0 = 0 (SDWA present) or 12 (none); R1 -> SDWA; R2 -> PARAM area;
*   R13 -> RTM work area; R15 = entry point.
*=====================================================================
RECEXIT  DS    0H
         USING RECPARM,R2          PARAM area, addressed by R2
         L     R12,RPBASE          reload program base
         USING ESTDEMO,R12
*  R0 = 12 means no SDWA was provided (R1 then holds the abend code).
*  Any other entry code (0, 16, ...) carries an SDWA address in R1.
         C     R0,=F'12'           no SDWA provided?
         BE    NOSDWA
         LR    R3,R1               R3 -> SDWA
         USING SDWA,R3
*---------------------------------------------------------------------
* Format and report the diagnostics (hex field sits at text start,
* i.e. list-form label + 4, so no character counting is needed).
*---------------------------------------------------------------------
         @HEXOUT SDWAABCC,MSGCODE+4,LEN=4
         WTO   MF=(E,MSGCODE)
         @HEXOUT SDWAEC1,MSGPSW+4,LEN=8
         WTO   MF=(E,MSGPSW)
         @HEXOUT SDWAGR14,MSGREGS+4,LEN=8
         WTO   MF=(E,MSGREGS)
*---------------------------------------------------------------------
* Retry once, bounded-retry loop, or percolate per the saved mode.
*---------------------------------------------------------------------
         CLI   RPMODE,C'P'         percolate?
         BE    DOPERC
         CLI   RPMODE,C'L'         bounded-retry loop?
         BE    DOLOOP
*  mode R: retry once, resuming past the failing instruction
         L     R4,RPRESUME
         SETRP RC=4,RETADDR=(R4),RETREGS=YES,FRESDWA=YES,WKAREA=(R3)
         BR    R14                 return to RTM -> retry once
*---------------------------------------------------------------------
* LOOP - re-drive the failing instruction, but BOUNDED by a retry
* counter so a persistent error cannot loop forever.  Past the limit,
* stop retrying and percolate - the production-safe behaviour.
*---------------------------------------------------------------------
DOLOOP   DS    0H
         L     R5,RPRETRY
         AHI   R5,1               count this retry attempt
         ST    R5,RPRETRY
         @HEXOUT RPRETRY,MSGTRY+4,LEN=4
         WTO   MF=(E,MSGTRY)
         C     R5,=A(MAXRETRY)    retried too many times?
         BH    LIMIT
         L     R4,RPABEND         re-drive the failing instruction
         SETRP RC=4,RETADDR=(R4),RETREGS=YES,FRESDWA=YES,WKAREA=(R3)
         BR    R14                return to RTM -> retry (re-fail)
LIMIT    DS    0H
         WTO   'ESTDEMO RECOVERY - RETRY LIMIT HIT',ROUTCDE=(11)
         SETRP RC=0,WKAREA=(R3)
         BR    R14                give up -> percolate
DOPERC   DS    0H
         WTO   'ESTDEMO RECOVERY - PERCOLATING ABEND',ROUTCDE=(11)
         SETRP RC=0,WKAREA=(R3)
         BR    R14                return to RTM -> percolate
         DROP  R3
*---------------------------------------------------------------------
* No SDWA: cannot SETRP, so percolate regardless of the request.
*---------------------------------------------------------------------
NOSDWA   DS    0H
         WTO   'ESTDEMO RECOVERY - NO SDWA, PERCOLATING',ROUTCDE=(11)
         SLR   R15,R15             RC 0 = percolate
         BR    R14
         DROP  R12
*---------------------------------------------------------------------
* Constants and work areas (non-reentrant, like the rest of the set)
*---------------------------------------------------------------------
         LTORG
MODEFLG  DC    C'R'                R=retry once  P=percolate  L=loop
PONE     DC    PL2'1'              valid packed addend
BADPACK  DC    XL4'C1C2C3C4'       invalid packed data -> S0C7
*---------------------------------------------------------------------
* Recovery parameter area (mapped by RECPARM below)
*---------------------------------------------------------------------
RECAREA  DS    XL24                mapped by RECPARM (4+1+3+4+4+4+4)
*---------------------------------------------------------------------
* WTO list-form messages. The hex placeholder is the first thing in
* the text, so it is patched at <label>+4 (the text start).
*---------------------------------------------------------------------
MSGCODE  WTO   '00000000=ABEND CODE (SDWAABCC)',ROUTCDE=(11),MF=L
MSGPSW   WTO   '0000000000000000=PSW (SDWAEC1)',ROUTCDE=(11),MF=L
MSGREGS  WTO   '0000000000000000=GPR 14-15 AT ERROR',ROUTCDE=(11),MF=L
MSGTRY   WTO   '00000000=RETRY COUNT (LOOP MODE)',ROUTCDE=(11),MF=L
         @HEXOUT MODE=DEFINE
*---------------------------------------------------------------------
* DSECTs
*---------------------------------------------------------------------
RECPARM  DSECT
RPEYE    DS    CL4                 eyecatcher 'RPRM'
RPMODE   DS    C                   R=retry once  P=percolate  L=loop
         DS    XL3                 align
RPBASE   DS    A                   saved program base (R12)
RPRESUME DS    A                   retry-once resume address
RPABEND  DS    A                   loop resume (re-drive the abend)
RPRETRY  DS    F                   retry counter (bounded by MAXRETRY)
RECPARML EQU   *-RECPARM
         IHASDWA
         END   ESTDEMO
