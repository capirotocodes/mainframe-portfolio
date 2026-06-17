*=====================================================================
* ESTDEMO - ESTAE RECOVERY DEMONSTRATION
*---------------------------------------------------------------------
* Purpose     : Deliberately causes a S0C7 data exception, recovers in
*               an ESTAE recovery routine, formats key SDWA fields to
*               WTO, and either retries (continue, RC 0) or percolates
*               (S0C7).
* Inputs      : PARM='RETRY' | 'PERCOLATE'   (first char R / P)
* Outputs     : WTO (ROUTCDE 11) - SDWA report; RC 0 (retry) / S0C7
*               (percolate).
* Registers   : R2-R4 PARM scratch, R5 CVB target, R6 WTO link reg,
*               R12 base, R13 save area.
* Preserved   : Caller registers saved by @ENTER.
* Dependencies: @ENTER/@LEAVE/@HEXOUT (ANDRE.EPE.MACLIB); ESTAEX/SETRP/
*               IHASDWA (SYS1.MACLIB/MODGEN).
* Sample      : PARM='RETRY' / PARM='PERCOLATE'
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
*  ---- (TASKS 3-4 INSERT: ESTAEX, RECOVERY HERE) ----------------
         MVC   WTOTXT,MSGTRY       "ABOUT TO ABEND"
         BAL   R6,PUTWTO
         CVB   R5,BADPACK          INVALID PACKED DATA -> S0C7
         MVC   WTOTXT,MSGNORC      (ONLY REACHED IF NO EXCEPTION)
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
         DS    0H                  ALIGN WTO LIST FORM
*  LIST FORM: TEXT IS BLANK HERE - PUTWTO OVERLAYS WTOTXT, THEN MF=(E)
WTOLIST  WTO   '                                                       X
                               ',                                      X
               ROUTCDE=(11),MF=L
WTOTXT   EQU   WTOLIST+4,71        TEXT FIELD = AFTER LEN(2)+FLAGS(2)
*  PIN: +4 = AL2(len)+AL2(flags) before the text; verified against
*       expanded WTOLIST in listing. Re-check if macro prefix changes.
MSGBAD   DC    CL71'ESTDEMO: BAD/MISSING PARM - USE RETRY OR PERCOLATE'
MSGTRY   DC    CL71'ESTDEMO: ABOUT TO EXECUTE CVB ON INVALID PACKED'
MSGNORC  DC    CL71'ESTDEMO: CVB DID NOT FAULT - UNEXPECTED'
         DS    0D
BADPACK  DC    X'1234567ABCDEF00C'  INVALID DIGITS (A-F) -> S0C7
         @HEXOUT MODE=DEFINE
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
         END   ESTDEMO
