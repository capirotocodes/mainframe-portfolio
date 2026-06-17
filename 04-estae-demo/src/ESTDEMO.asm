*=====================================================================
* ESTDEMO - ESTAE RECOVERY DEMONSTRATION
*           DELIBERATELY CAUSES A S0C7 DATA EXCEPTION, RECOVERS IN AN
*           ESTAE RECOVERY ROUTINE, FORMATS KEY SDWA FIELDS TO WTO,
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
WTOLIST  WTO   '                                                       X
                               ',                                      X
               ROUTCDE=(11),MF=L
WTOTXT   EQU   WTOLIST+4,71        TEXT FIELD = AFTER LEN(2)+FLAGS(2)
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
