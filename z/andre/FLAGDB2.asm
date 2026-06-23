FLAGDB2  CSECT
FLAGDB2  AMODE 31
FLAGDB2  RMODE ANY
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
***********************************************************************
*                                                                     *
*  PROGRAM: FLAGDB2                                                   *
*                                                                     *
*  PURPOSE:                                                           *
*    COMPILE-CLEAN HLASM FEATURE-FLAG SKELETON.                       *
*                                                                     *
*    THIS VERSION KEEPS THE PARM-DRIVEN ROUTING MODEL BUT STUBS OUT   *
*    DB2 PROCESSING UNTIL THE SITE-SPECIFIC DB2 PRECOMPILE FLOW IS    *
*    KNOWN. THIS LETS US PROVE THE ASSEMBLE/LINK PATH FIRST.          *
*                                                                     *
*  FEATURE FLAG:                                                      *
*    IF PARM = NEW_BULK_EXTRACT=Y THEN BRANCH TO NEWEXTR              *
*    ELSE BRANCH TO LEGACY                                            *
*                                                                     *
*  DEPLOYMENT NOTE:                                                   *
*    THIS ENABLES BLUE/GREEN OR CANARY STYLE ROUTING BY CHANGING      *
*    ONLY THE EXEC PARM IN JCL. NO RELINK IS NEEDED TO SWITCH PATHS.  *
*                                                                     *
***********************************************************************
         SAVE  (14,12)
         LR    R12,R15
         USING FLAGDB2,R12
         GETMAIN RU,LV=WORKLEN
         LR    R11,R1
         USING WORKDSE,R11
         XC    WORKDSE(WORKLEN),WORKDSE
         ST    R13,SAVEBK
         ST    R11,8(R13)
         LR    R13,R11
         SR    R15,R15
***********************************************************************
*  RETRIEVE JCL PARM FROM REGISTER 1                                  *
***********************************************************************
         LR    R10,R1
         LTR   R10,R10
         BZ    PARMNONE
         USING PARMDSE,R10
         LH    R2,PARMLEN
         LTR   R2,R2
         BZ    PARMNONE
         CH    R2,=H'18'
         BL    PARMNONE
         CLC   PARMTEXT(18),FLAGON
         BE    NEWEXTR
         B     LEGACY
PARMNONE DS    0H
         B     LEGACY
***********************************************************************
*  LEGACY ROUTE                                                       *
***********************************************************************
LEGACY   DS    0H
         SR    R15,R15
         B     EOJ
***********************************************************************
*  NEW EXTRACTION ROUTE                                               *
***********************************************************************
NEWEXTR  DS    0H
         SR    R15,R15
         B     EOJ
***********************************************************************
*  RETURN TO CALLER                                                   *
***********************************************************************
EOJ      DS    0H
         L     R13,SAVEBK
         FREEMAIN RU,A=(R11),LV=WORKLEN
         RETURN (14,12),RC=(15)
***********************************************************************
*  STATIC STORAGE                                                     *
***********************************************************************
FLAGON   DC    CL18'NEW_BULK_EXTRACT=Y'
WORKLEN  EQU   72
***********************************************************************
*  WORK AREA DSECT                                                    *
***********************************************************************
WORKDSE  DSECT
SAVEFWD  DS    F
SAVEBK   DS    F
SAVE14   DS    F
SAVE15   DS    F
SAVE16   DS    14F
***********************************************************************
*  JCL PARM DSECT                                                     *
***********************************************************************
PARMDSE  DSECT
PARMLEN  DS    H
PARMTEXT DS    CL100
         END   FLAGDB2
