***********************************************************************
* PROGRAM:    DUMPPGM                                                 *
* PURPOSE:    Generate a system dump for IPCS practice               *
* AUTHOR:     Bob                                                     *
* DATE:       2026-06-18                                              *
*                                                                     *
* DESCRIPTION:                                                        *
*   This program demonstrates various scenarios that can be          *
*   analyzed using IPCS (Interactive Problem Control System).        *
*   It creates interesting data structures and then forces a         *
*   dump using ABEND.                                                 *
*                                                                     *
* FEATURES:                                                           *
*   - Creates sample data structures in storage                      *
*   - Establishes save area chain                                    *
*   - Sets up control blocks                                         *
*   - Forces ABEND U0013 with dump                                   *
*                                                                     *
* USAGE:                                                              *
*   Run via JCL with SYSUDUMP or SYSABEND DD statement              *
***********************************************************************
         TITLE 'DUMPPGM - System Dump Generator for IPCS Practice'
*
DUMPPGM  CSECT
DUMPPGM  AMODE 31
DUMPPGM  RMODE ANY
*
         SAVE  (14,12),,DUMPPGM-&SYSDATE-&SYSTIME
         LR    R12,R15              Load base register
         USING DUMPPGM,R12          Establish addressability
         LA    R11,4095(,R12)       Second base register
         LA    R11,1(,R11)          
         USING DUMPPGM+4096,R11     
*
* Get storage for dynamic save area and work area
*
         GETMAIN RU,LV=WORKLEN,LOC=BELOW
         ST    R13,4(,R1)           Chain save areas
         ST    R1,8(,R13)           
         LR    R13,R1               New save area
         USING WORKAREA,R13         Address work area
*
* Display startup message
*
         WTO   'DUMPPGM: Starting dump generation program'
*
* Create interesting data structures for IPCS analysis
*
         BAL   R14,INITDATA         Initialize data structures
         BAL   R14,BUILDCTL         Build control blocks
         BAL   R14,FILLBUFF         Fill buffers with data
*
* Display pre-dump message
*
         WTO   'DUMPPGM: Data structures created, forcing dump...'
*
* Force a dump with ABEND U0013
*
         ABEND 13,DUMP              Force dump for IPCS practice
*
* Normal return (never reached)
*
RETURN   DS    0H
         LR    R1,R13               Save work area address
         L     R13,4(,R13)          Restore caller's save area
         FREEMAIN RU,LV=WORKLEN,A=(R1)
         RETURN (14,12),RC=0        Return to caller
*
***********************************************************************
* INITDATA - Initialize sample data structures                       *
***********************************************************************
INITDATA DS    0H
         ST    R14,RETADDR          Save return address
*
* Initialize header structure
*
         MVC   HEADER,=C'DUMP'      Eye-catcher
         MVC   HEADER+4(4),=F'1'    Version
         MVC   HEADER+8(8),=CL8'DUMPPGM' Program name
         TIME  DEC                  Get current time
         ST    R0,HEADER+16         Store time
         ST    R1,HEADER+20         Store date
*
* Initialize sample table
*
         LA    R2,TABLE             Point to table
         LA    R3,10                10 entries
         LA    R4,1                 Counter
INITLOOP DS    0H
         ST    R4,0(,R2)            Store entry number
         MVC   4(8,R2),=CL8'ENTRY   ' Entry name
         STC   R4,9(,R2)            Store number in name
         OI    9(R2),X'F0'          Make printable
         LA    R2,TABELEN(,R2)      Next entry
         LA    R4,1(,R4)            Increment counter
         BCT   R3,INITLOOP          Loop
*
         L     R14,RETADDR          Restore return address
         BR    R14                  Return
*
***********************************************************************
* BUILDCTL - Build sample control blocks                             *
***********************************************************************
BUILDCTL DS    0H
         ST    R14,RETADDR          Save return address
*
* Create a simple control block chain
*
         LA    R2,CTLBLK1           First control block
         MVC   0(4,R2),=C'CTL1'     Eye-catcher
         LA    R3,CTLBLK2           Second control block
         ST    R3,4(,R2)            Chain to next
         ST    R2,8(,R2)            Back pointer
*
         MVC   0(4,R3),=C'CTL2'     Eye-catcher
         LA    R4,CTLBLK3           Third control block
         ST    R4,4(,R3)            Chain to next
         ST    R2,8(,R3)            Back pointer
*
         MVC   0(4,R4),=C'CTL3'     Eye-catcher
         XC    4(4,R4),4(R4)        End of chain
         ST    R3,8(,R4)            Back pointer
*
         L     R14,RETADDR          Restore return address
         BR    R14                  Return
*
***********************************************************************
* FILLBUFF - Fill buffers with sample data                           *
***********************************************************************
FILLBUFF DS    0H
         ST    R14,RETADDR          Save return address
*
* Fill buffer with pattern
*
         LA    R2,BUFFER            Point to buffer
         LA    R3,BUFLEN            Buffer length
         LA    R4,0                 Pattern counter
FILLLOOP DS    0H
         STC   R4,0(,R2)            Store byte
         LA    R2,1(,R2)            Next byte
         LA    R4,1(,R4)            Next pattern
         N     R4,=X'000000FF'      Keep in byte range
         BCT   R3,FILLLOOP          Loop
*
* Add some text strings
*
         MVC   BUFFER(50),=C'This is sample data for IPCS dump analysiX
               s practice'
         MVC   BUFFER+100(40),=C'Look for this string in the dump fileX
               !'
*
         L     R14,RETADDR          Restore return address
         BR    R14                  Return
*
***********************************************************************
* Constants and Literals                                             *
***********************************************************************
         LTORG
*
***********************************************************************
* Work Area DSECT                                                     *
***********************************************************************
WORKAREA DSECT
SAVEAREA DS    18F                  Register save area
RETADDR  DS    F                    Return address save
*
* Sample data structures
*
HEADER   DS    0CL24                Header structure
         DS    CL4                  Eye-catcher
         DS    F                    Version
         DS    CL8                  Program name
         DS    F                    Time
         DS    F                    Date
*
TABLE    DS    10CL12               Sample table
TABELEN  EQU   12                   Table entry length
*
CTLBLK1  DS    0CL16                Control block 1
         DS    CL4                  Eye-catcher
         DS    A                    Forward pointer
         DS    A                    Back pointer
         DS    F                    Data field
*
CTLBLK2  DS    0CL16                Control block 2
         DS    CL4                  Eye-catcher
         DS    A                    Forward pointer
         DS    A                    Back pointer
         DS    F                    Data field
*
CTLBLK3  DS    0CL16                Control block 3
         DS    CL4                  Eye-catcher
         DS    A                    Forward pointer
         DS    A                    Back pointer
         DS    F                    Data field
*
BUFFER   DS    CL256                Sample buffer
BUFLEN   EQU   256                  Buffer length
*
WORKLEN  EQU   *-WORKAREA           Work area length
*
         END   DUMPPGM

* Made with Bob
