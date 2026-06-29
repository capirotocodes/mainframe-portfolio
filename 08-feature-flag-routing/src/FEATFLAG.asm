*=====================================================================
* FEATFLAG -  PARM-driven feature-flag routing
*---------------------------------------------------------------------
* Purpose     : Select one of two execution paths (LEGACY or NEW) in a
*               single load module from the EXEC PARM, with no relink
*               needed to switch - a feature-flag / progressive
*               delivery pattern for z/OS batch.
* Inputs      : EXEC PARM. PARM='NEW_BULK_EXTRACT=Y' selects the NEW
*               path; absent or anything else selects LEGACY.
* Outputs     : WTO naming the route taken (ROUTCDE=11). RC 0.
* Registers   : R12 base, R13 save area (@ENTER); R10 -> parm list,
*               R2 -> parm text, R3 = parm length.
* Preserved   : Caller registers saved by @ENTER.
* Dependencies: @ENTER @LEAVE (ANDRE.EPE.MACLIB); WTO (SYS1.MACLIB).
* Sample      : See ../jcl/RUNFF.jcl
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
FEATFLAG CSECT
FEATFLAG AMODE 31
FEATFLAG RMODE ANY
         @ENTER
*---------------------------------------------------------------------
* Preserve the parm pointer (R1) BEFORE issuing any service that uses
* R1 - this is the bug the original skeleton had: GETMAIN overwrote R1
* and the flag was read from the wrong storage, so it never matched.
*---------------------------------------------------------------------
         LR    R10,R1              R10 -> parm list (survives WTO)
         WTO   'FEATFLAG STARTING',ROUTCDE=(11)
*---------------------------------------------------------------------
* Inspect the EXEC PARM: a halfword length followed by the text.
*---------------------------------------------------------------------
         LTR   R10,R10             no parm list at all?
         BZ    LEGACY
         L     R2,0(,R10)          R2 -> parm string (LEN + text)
         LH    R3,0(,R2)           R3 = parm text length
         CH    R3,=H'18'           long enough to hold the flag value?
         BL    LEGACY
         CLC   2(18,R2),FLAGON     flag set to the NEW value?
         BNE   LEGACY
*---------------------------------------------------------------------
* NEW path (flag on)
*---------------------------------------------------------------------
NEWEXTR  DS    0H
         WTO   'FEATFLAG ROUTE=NEW (flag on)',ROUTCDE=(11)
         @LEAVE RC=0
*---------------------------------------------------------------------
* LEGACY path (flag off / default)
*---------------------------------------------------------------------
LEGACY   DS    0H
         WTO   'FEATFLAG ROUTE=LEGACY (flag off)',ROUTCDE=(11)
         @LEAVE RC=0
*---------------------------------------------------------------------
* Constants
*---------------------------------------------------------------------
FLAGON   DC    CL18'NEW_BULK_EXTRACT=Y'
         LTORG
         END   FEATFLAG
