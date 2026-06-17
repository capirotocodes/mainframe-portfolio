*=====================================================================
* SOSCRAPE - JES2 SYSOUT scraper (scrape-and-route)
*---------------------------------------------------------------------
* Purpose     : Dynamically allocate an input dataset and a SYSOUT
*               dataset with SVC 99, read the input with QSAM, and
*               write every record containing the search pattern to
*               the SYSOUT dataset (which JES2 then processes).
* Inputs      : PARM='dsname pattern' - dsname (<=44) is the dataset
*               to scan; the text after the first blank is the pattern
*               (<=44, may contain blanks).
* Outputs     : SYSOUT (DDNAME SCRAPOUT, class A): matched lines, each
*               prefixed with a hex match number, plus a summary line.
*               RC 0 = matches found, 4 = none found, 8 = error.
* Registers   : R2/R3 record ptr/len, R0/R9/R10 search, R5 work,
*               R6 BAL link, R7 output DCB, R8 input DCB (below line),
*               R12 base, R13 save area.
* Preserved   : Caller registers saved by @ENTER.
* Dependencies: @ENTER @LEAVE @HEXOUT (ANDRE.EPE.MACLIB); IEFZB4D0
*               IEFZB4D2 DCBD (SYS1.MACLIB / SYS1.MODGEN).
* Sample      : See ../jcl/BUILDSO.jcl
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
SOSCRAPE CSECT
SOSCRAPE AMODE 31
SOSCRAPE RMODE 24
         @ENTER
         LR    R11,R1              save PARM ptr (macros use R1)
*---------------------------------------------------------------------
* RMODE 24: the module, its DCBs, the SVC 99 AL3 request-block
* pointers, and the 24-bit DCB EODAD field all live below the 16M
* line, so QSAM can OPEN the DCBs directly - no GETMAIN/copy needed.
* R8 -> input DCB, R7 -> output DCB.
*---------------------------------------------------------------------
         LA    R8,INDCB            R8 -> input DCB
         LA    R7,OUTDCB           R7 -> output DCB
*---------------------------------------------------------------------
* Allocate the SYSOUT output first, so later diagnostics have a home
*---------------------------------------------------------------------
         LA    R1,S99PALC          -> RB pointer (allocate SYSOUT)
         SVC   99
         LTR   R15,R15
         BZ    ALOROK
         WTO   'SOSCRAPE: SYSOUT (SCRAPOUT) allocation failed'
         MVC   RCWORD,=F'8'
         B     TERM
ALOROK   OI    FLAGS,FLOUTALC      remember: SCRAPOUT allocated
         OPEN  ((R7),OUTPUT)
         USING IHADCB,R7
         TM    DCBOFLGS,DCBOFOPN   did SCRAPOUT open?
         DROP  R7
         BO    OPNOOK
         WTO   'SOSCRAPE: SYSOUT (SCRAPOUT) open failed'
         MVC   RCWORD,=F'8'
         B     TERM
OPNOOK   OI    FLAGS,FLOUTOPN
*---------------------------------------------------------------------
* Parse PARM:  'dsname pattern'
*---------------------------------------------------------------------
         L     R2,0(,R11)          R11 -> parm pointer (saved at entry)
         LH    R3,0(,R2)           R3 = parm length
         LTR   R3,R3
         BNP   PNULL               no PARM text
         LA    R2,2(,R2)           R2 -> parm text
*  find the first blank (dsname / pattern delimiter)
         LR    R4,R2               R4 = scan pointer
         LR    R5,R3               R5 = bytes remaining
PFB      CLI   0(R4),C' '
         BE    PFB1
         LA    R4,1(,R4)
         BCT   R5,PFB
         B     PNOPAT              no blank -> no pattern given
PFB1     DS    0H
*  dsname = R2..R4-1  (use R1 for EX length: EX reg 0 = no modify)
         LR    R1,R4
         SR    R1,R2               R1 = dsname length
         LTR   R1,R1
         BNP   PNULL
         C     R1,=F'44'
         BH    PDSNBIG
         STH   R1,TUDSNLN          set DSN text-unit length
         BCTR  R1,0
         EX    R1,MVCDSN           copy dsname into the text unit
*  pattern = text after the blank
         LA    R4,1(,R4)           skip the delimiting blank
         LA    R5,0(R3,R2)         R5 -> end of parm text
         LR    R1,R5
         SR    R1,R4               R1 = pattern length
         LTR   R1,R1
         BNP   PNOPAT
         C     R1,=F'44'
         BH    PPATBIG
         ST    R1,PLEN
         BCTR  R1,0
         EX    R1,MVCPAT           copy the pattern
*---------------------------------------------------------------------
* Allocate the input dataset (DSN, DISP=SHR, DDNAME SCRAPIN)
*---------------------------------------------------------------------
         LA    R1,S99PALI
         SVC   99
         LTR   R15,R15
         BZ    ALIROK
         MVI   LINE,C' '
         MVC   LINE+1(L'MALCIN),MALCIN
         SLR   R5,R5
         ICM   R5,B'0011',RBIERR   S99ERROR (halfword)
         ST    R5,WORD
         @HEXOUT WORD,LINE+1+L'MALCIN,LEN=4
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
ALIROK   OI    FLAGS,FLINALC
         OPEN  ((R8),INPUT)
         USING IHADCB,R8
         TM    DCBOFLGS,DCBOFOPN
         BO    OPNIOK
         DROP  R8
         MVI   LINE,C' '
         MVC   LINE+1(L'MOPNIN),MOPNIN
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
OPNIOK   OI    FLAGS,FLINOPN
*---------------------------------------------------------------------
* Learn the input record format / length from the open DCB
*---------------------------------------------------------------------
         USING IHADCB,R8
         LH    R5,DCBLRECL
         ST    R5,INLRECL
         SLR   R5,R5
         IC    R5,DCBRECFM
         DROP  R8
         N     R5,=X'000000C0'     isolate the format bits
         C     R5,=X'00000080'     F / FB ?
         BE    SETFIX
         C     R5,=X'00000040'     V / VB ?
         BE    SETVAR
         MVI   LINE,C' '           RECFM U or other - unsupported
         MVC   LINE+1(L'MUNSUP),MUNSUP
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
SETFIX   MVI   RECFIX,X'01'
         B     RDLOOP
SETVAR   MVI   RECFIX,X'00'
*---------------------------------------------------------------------
* Read loop: GET (locate), set record ptr/len, scan, write matches
*---------------------------------------------------------------------
RDLOOP   DS    0H
         GET   (R8)                R1 -> logical record
         L     R5,RECCNT
         AHI   R5,1
         ST    R5,RECCNT
         CLI   RECFIX,X'01'
         BNE   RDVAR
         LR    R2,R1               fixed: record at R1
         L     R3,INLRECL          length = LRECL
         B     RDMTCH
RDVAR    LH    R3,0(,R1)           var: LL of RDW
         AHI   R3,-4               data length
         LA    R2,4(,R1)           data after the 4-byte RDW
RDMTCH   DS    0H
*  substring search: try start positions 0 .. RLEN-PLEN
         L     R5,PLEN
         CR    R5,R3               pattern longer than record?
         BH    RDLOOP
         LR    R4,R3
         SR    R4,R5               R4 = last valid start index
         L     R1,PLEN
         BCTR  R1,0                R1 = PLEN-1 (EX reg 0 = no modify)
         SLR   R9,R9               R9 = current start index
MSCAN    CR    R9,R4
         BH    RDLOOP              exhausted - no match this record
         LA    R10,0(R9,R2)        R10 -> candidate position
         EX    R1,CLCP
         BE    MATCH
         LA    R9,1(,R9)
         B     MSCAN
*---------------------------------------------------------------------
* A match: write the record (prefixed with a hex match number)
*---------------------------------------------------------------------
MATCH    DS    0H
         L     R5,MATCNT
         AHI   R5,1
         ST    R5,MATCNT
         MVI   LINE,C' '
         MVC   LINE+1(L'LINE-1),LINE   blank the line
         ST    R5,WORD
         @HEXOUT WORD,LINE+1,LEN=4     match number, 8 hex chars
         MVI   LINE+9,C' '
         LR    R5,R3                   record length
         C     R5,=F'123'             cap at 123 printable bytes
         BNH   MCOPY
         LA    R5,123
MCOPY    LTR   R5,R5
         BNP   MPUT                    zero-length record
         BCTR  R5,0
         EX    R5,MVCTXT
MPUT     BAL   R6,PUTLINE
         B     RDLOOP
*---------------------------------------------------------------------
* End of input: summary line, then tear down
*---------------------------------------------------------------------
EOF      DS    0H
         MVI   LINE,C' '
         MVC   LINE+1(L'LINE-1),LINE
         MVC   LINE+1(16),MSUM1        'Records scanned '
         L     R5,RECCNT
         ST    R5,WORD
         @HEXOUT WORD,LINE+17,LEN=4
         MVC   LINE+25(10),MSUM2       ' matched  '
         L     R5,MATCNT
         ST    R5,WORD
         @HEXOUT WORD,LINE+35,LEN=4
         BAL   R6,PUTLINE
         L     R5,MATCNT               set RC: 0 found, 4 none
         LTR   R5,R5
         BNZ   EOFRC0
         MVC   RCWORD,=F'4'
         B     TERM
EOFRC0   MVC   RCWORD,=F'0'
*---------------------------------------------------------------------
* TERM: close / unallocate only what succeeded, free storage, return
*---------------------------------------------------------------------
TERM     DS    0H
         TM    FLAGS,FLINOPN
         BNO   TRM1
         CLOSE ((R8))
TRM1     TM    FLAGS,FLOUTOPN
         BNO   TRM2
         CLOSE ((R7))
TRM2     TM    FLAGS,FLINALC
         BNO   TRM3
         LA    R1,S99PUNI          unallocate SCRAPIN
         SVC   99
TRM3     TM    FLAGS,FLOUTALC
         BNO   TRM4
         LA    R1,S99PUNO          unallocate SCRAPOUT -> JES2
         SVC   99
TRM4     L     R2,RCWORD
         @LEAVE RC=(R2)
*---------------------------------------------------------------------
* PARM error exits
*---------------------------------------------------------------------
PNULL    MVI   LINE,C' '
         MVC   LINE+1(L'MNOPARM),MNOPARM
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
PNOPAT   MVI   LINE,C' '
         MVC   LINE+1(L'MNOPAT),MNOPAT
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
PDSNBIG  MVI   LINE,C' '
         MVC   LINE+1(L'MDSNBIG),MDSNBIG
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
PPATBIG  MVI   LINE,C' '
         MVC   LINE+1(L'MPATBIG),MPATBIG
         BAL   R6,PUTLINE
         MVC   RCWORD,=F'8'
         B     TERM
*---------------------------------------------------------------------
* PUTLINE: write LINE to SCRAPOUT, blank it, return via R6.
* The EX targets below are reached only by EX (never fall through).
*---------------------------------------------------------------------
PUTLINE  PUT   (R7),LINE
         MVI   LINE,C' '
         MVC   LINE+1(L'LINE-1),LINE
         BR    R6
CLCP     CLC   0(0,R10),PATT
MVCTXT   MVC   LINE+10(0),0(R2)
MVCDSN   MVC   TUDSNTX(0),0(R2)
MVCPAT   MVC   PATT(0),0(R4)
*=====================================================================
* SVC 99 request blocks and text units (IEFZB4D0 / IEFZB4D2)
*=====================================================================
         DS    0F
*  ---- allocate input ------------------------------------------------
S99PALI  DC    X'80',AL3(RBALI)        RB pointer (last-RB bit on)
RBALI    DC    AL1(S99RBEND-S99RB)     S99RBLN
         DC    AL1(S99VRBAL)           S99VERB = allocate
         DC    XL2'0000'               S99FLG1
RBIERR   DC    XL2'0000'               S99ERROR (set by SVC 99)
         DC    XL2'0000'               S99INFO
         DC    A(TXLALI)               S99TXTPP
         DC    A(0)                    S99S99X
         DC    XL4'00'                 S99FLG2
TXLALI   DC    A(TUDSN)                -> dsname text unit
         DC    A(TUSTAT)               -> status text unit
         DC    X'80',AL3(TUDDIN)       -> ddname (last)
TUDSN    DC    AL2(DALDSNAM),AL2(1)
TUDSNLN  DC    AL2(0)                  parm length (run-time)
TUDSNTX  DC    CL44' '                 dsname (run-time)
TUSTAT   DC    AL2(DALSTATS),AL2(1),AL2(1),X'08'   DISP=SHR
TUDDIN   DC    AL2(DALDDNAM),AL2(1),AL2(8),CL8'SCRAPIN'
*  ---- allocate output SYSOUT ---------------------------------------
         DS    0F                  align RB so S99TXTPP lands at +8
S99PALC  DC    X'80',AL3(RBALC)
RBALC    DC    AL1(S99RBEND-S99RB)
         DC    AL1(S99VRBAL)
         DC    XL2'0000'
RBOERR   DC    XL2'0000'               S99ERROR
         DC    XL2'0000'
         DC    A(TXLALC)
         DC    A(0)
         DC    XL4'00'
TXLALC   DC    A(TUSYSOU)
         DC    X'80',AL3(TUDDOUT)
TUSYSOU  DC    AL2(DALSYSOU),AL2(1),AL2(1),C'A'    SYSOUT class A
TUDDOUT  DC    AL2(DALDDNAM),AL2(1),AL2(8),CL8'SCRAPOUT'
*  ---- unallocate input ---------------------------------------------
         DS    0F                  align RB
S99PUNI  DC    X'80',AL3(RBUNI)
RBUNI    DC    AL1(S99RBEND-S99RB)
         DC    AL1(S99VRBUN)           S99VERB = unallocate
         DC    XL2'0000'
         DC    XL2'0000'
         DC    XL2'0000'
         DC    A(TXLUNI)
         DC    A(0)
         DC    XL4'00'
TXLUNI   DC    X'80',AL3(TUUNIN)
TUUNIN   DC    AL2(DUNDDNAM),AL2(1),AL2(8),CL8'SCRAPIN'
*  ---- unallocate output --------------------------------------------
         DS    0F                  align RB
S99PUNO  DC    X'80',AL3(RBUNO)
RBUNO    DC    AL1(S99RBEND-S99RB)
         DC    AL1(S99VRBUN)
         DC    XL2'0000'
         DC    XL2'0000'
         DC    XL2'0000'
         DC    A(TXLUNO)
         DC    A(0)
         DC    XL4'00'
TXLUNO   DC    X'80',AL3(TUUNOUT)
TUUNOUT  DC    AL2(DUNDDNAM),AL2(1),AL2(8),CL8'SCRAPOUT'
*=====================================================================
* Constants, messages, work areas
*=====================================================================
         LTORG
MALCIN   DC    C'** Input allocation failed, S99ERROR='
MOPNIN   DC    C'** Input OPEN failed'
MUNSUP   DC    C'** Unsupported RECFM (need F or V)'
MNOPARM  DC    C'** No PARM: need PARM=''dsname pattern'''
MNOPAT   DC    C'** PARM has no pattern (need: dsname pattern)'
MDSNBIG  DC    C'** DSN too long (max 44)'
MPATBIG  DC    C'** Pattern too long (max 44)'
MSUM1    DC    CL16'Records scanned '
MSUM2    DC    CL10' matched  '
FLAGS    DC    X'00'
FLOUTALC EQU   X'80'                   SCRAPOUT allocated
FLOUTOPN EQU   X'40'                   SCRAPOUT open
FLINALC  EQU   X'20'                   SCRAPIN allocated
FLINOPN  EQU   X'10'                   SCRAPIN open
RECFIX   DC    X'00'                   1 = RECFM F, 0 = RECFM V
RCWORD   DC    F'0'
RECCNT   DC    F'0'
MATCNT   DC    F'0'
INLRECL  DC    F'0'
WORD     DC    F'0'
PLEN     DC    F'0'
PATT     DC    CL44' '
LINE     DC    CL133' '
         @HEXOUT MODE=DEFINE
*---------------------------------------------------------------------
* DCBs (RMODE 24 -> below the line; opened directly)
*---------------------------------------------------------------------
INDCB    DCB   DDNAME=SCRAPIN,DSORG=PS,MACRF=GL,EODAD=EOF
OUTDCB   DCB   DDNAME=SCRAPOUT,DSORG=PS,MACRF=PM,RECFM=FBA,LRECL=133
*---------------------------------------------------------------------
* DSECTs (IBM-supplied)
*---------------------------------------------------------------------
         DCBD  DSORG=PS
         IEFZB4D0
         IEFZB4D2
         END   SOSCRAPE
