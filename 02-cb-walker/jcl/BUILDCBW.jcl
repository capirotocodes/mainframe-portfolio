//CBWALK   JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*-------------------------------------------------------------------
//* Assemble, link-edit, and run CBWALK (control block walker).
//* PREREQ: src\CBWALK.asm uploaded as ANDRE.EPE.ASM(CBWALK).
//* SYSLIB: ANDRE.EPE.MACLIB (@ENTER/@LEAVE/@HEXOUT) ahead of the IBM
//*         macro/DSECT libraries.
//*-------------------------------------------------------------------
//ASM      EXEC PGM=ASMA90,REGION=0M,
//             PARM='OBJECT,NODECK,LIST,XREF(SHORT)'
//SYSLIB   DD  DISP=SHR,DSN=ANDRE.EPE.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MODGEN
//SYSIN    DD  DISP=SHR,DSN=ANDRE.EPE.ASM(CBWALK)
//SYSLIN   DD  DISP=(,PASS),DSN=&&OBJ,UNIT=SYSDA,
//             SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSPRINT DD  SYSOUT=*
//*-------------------------------------------------------------------
//LKED     EXEC PGM=IEWL,COND=(0,LT,ASM),
//             PARM='LIST,MAP,XREF,RMODE=ANY,AMODE=31'
//SYSLIN   DD  DISP=(OLD,DELETE),DSN=&&OBJ
//SYSLMOD  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD(CBWALK)
//SYSPRINT DD  SYSOUT=*
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//*-------------------------------------------------------------------
//RUN      EXEC PGM=CBWALK,COND=(0,LT,LKED)
//STEPLIB  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//
