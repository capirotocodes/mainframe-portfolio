*=====================================================================
* DEMOSP  -  Structured-programming macro demonstration
*---------------------------------------------------------------------
* Purpose     : Exercise the personal macro library: @ENTER/@LEAVE,
*               @DO/@ENDDO (WHILE and UNTIL), @IF/@ELSE/@ENDIF,
*               @HEXOUT and @PCALL. Sums 1..10, tallies even/odd
*               values, doubles the sum via an external subroutine,
*               and writes both results in hex with WTO.
* Inputs      : None.
* Outputs     : Console / job-log WTO showing SUM and DBL in hex.
*               Return code 0.
* Registers   : R4 index, R5 work, R6 sum, R7 even, R8 limit,
*               R9 odd, R10 countdown; R12 base, R13/14/15 linkage.
* Preserved   : Standard - caller registers saved by @ENTER.
* Dependencies: Macro members @ENTER @LEAVE @DO @ENDDO @IF @ELSE
*               @ENDIF @HEXOUT @PCALL @XINVB on SYSLIB.
* Sample      : See ../jcl/BUILDEX.jcl
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
DEMOSP   CSECT
DEMOSP   AMODE 31
DEMOSP   RMODE ANY
         @ENTER
*---------------------------------------------------------------------
* Sum 1..10, tally even and odd values (top-tested @DO WHILE)
*---------------------------------------------------------------------
         LA    R4,1               i = 1
         SLR   R6,R6              sum = 0
         SLR   R7,R7              even count = 0
         SLR   R9,R9              odd count = 0
         LA    R8,10              limit = 10
         @DO   WHILE=(CR,R4,R8),WCOND=LE
         AR    R6,R4              sum = sum + i
         LR    R5,R4              copy i
         N     R5,=F'1'           isolate low-order bit
         @IF   (C,R5,=F'0'),EQ    if i is even
         AHI   R7,1               even = even + 1
         @ELSE                    else
         AHI   R9,1               odd = odd + 1
         @ENDIF
         AHI   R4,1               i = i + 1
         @ENDDO
         ST    R6,SUM             save the running total
*---------------------------------------------------------------------
* Bottom-tested loop (@DO / @ENDDO UNTIL): spin a counter to zero
*---------------------------------------------------------------------
         LA    R10,3
         @DO
         AHI   R10,-1
         @ENDDO UNTIL=(C,R10,=F'0'),UCOND=EQ
*---------------------------------------------------------------------
* Format SUM, double it via external routine, format again, report
*---------------------------------------------------------------------
         @HEXOUT SUM,MSGSUM,LEN=4
         @PCALL DOUBLE,PARMS=(SUM)
         @HEXOUT SUM,MSGDBL,LEN=4
         WTO   MF=(E,WTOLST)
         @LEAVE RC=0
*---------------------------------------------------------------------
* Constants, work areas, WTO list form
*---------------------------------------------------------------------
         LTORG
SUM      DC    F'0'
WTOLST   WTO   'DEMOSP: SUM=........ DBL=........',MF=L
MSGSUM   EQU   WTOLST+4+12        8-char hex field for SUM
MSGDBL   EQU   WTOLST+4+25        8-char hex field for DBL
         @HEXOUT MODE=DEFINE
*=====================================================================
* DOUBLE  -  double the fullword addressed by the first parameter
*---------------------------------------------------------------------
* Inputs  : R1 -> parm list; parm 1 = A(fullword).
* Outputs : the fullword is replaced by value*2.
*=====================================================================
DOUBLE   CSECT
DOUBLE   AMODE 31
DOUBLE   RMODE ANY
         @ENTER
         L     2,0(,1)            R2 -> caller's fullword
         L     3,0(,2)            load value
         SLA   3,1                value * 2
         ST    3,0(,2)            store it back
         @LEAVE
         END   DEMOSP
