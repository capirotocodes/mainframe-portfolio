//SOSCRAPE JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*-------------------------------------------------------------------
//* Assemble, link-edit, build a sample input dataset, and run the
//* JES2 SYSOUT scraper.  The RUN step allocates SCRAPIN and SCRAPOUT
//* dynamically (SVC 99) - no DD cards for them.
//*
//* Before running: upload src/SOSCRAPE.asm as ANDRE.EPE.ASM(SOSCRAPE)
//* and pre-allocate load library ANDRE.EPE.LOAD.  Adjust HLQs to suit.
//*-------------------------------------------------------------------
//ASM      EXEC PGM=ASMA90,REGION=0M,
//             PARM='OBJECT,NODECK,LIST,XREF(SHORT)'
//SYSLIB   DD  DISP=SHR,DSN=ANDRE.EPE.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MODGEN
//SYSIN    DD  DISP=SHR,DSN=ANDRE.EPE.ASM(SOSCRAPE)
//SYSLIN   DD  DISP=(,PASS),DSN=&&OBJ,UNIT=SYSDA,
//             SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSPRINT DD  SYSOUT=*
//*-------------------------------------------------------------------
//LKED     EXEC PGM=IEWL,COND=(0,LT,ASM),
//             PARM='LIST,MAP,XREF,RMODE=24,AMODE=31'
//SYSLIN   DD  DISP=(OLD,DELETE),DSN=&&OBJ
//SYSLMOD  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD(SOSCRAPE)
//SYSPRINT DD  SYSOUT=*
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//*-------------------------------------------------------------------
//* Delete any prior sample, then (re)build it with IEBGENER
//*-------------------------------------------------------------------
//DEL      EXEC PGM=IEFBR14
//D1       DD  DSN=ANDRE.EPE.SCRAP.IN,DISP=(MOD,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(1,1))
//*-------------------------------------------------------------------
//GEN      EXEC PGM=IEBGENER
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  DUMMY
//SYSUT2   DD  DSN=ANDRE.EPE.SCRAP.IN,DISP=(,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//SYSUT1   DD  *
JOB12345 STARTED ON SYSTEM ZOS31
ALLOC FOR STEP1 COMPLETED NORMALLY
IEF236I ALLOC. FOR JOB12345 STEP1
ERROR: RC=0008 RETURNED FROM MODULE PAYUPD
WARN: SPOOL UTILIZATION ABOVE 70 PERCENT
STEP1 ENDED - COND CODE 0000
ERROR: S0C7 IN MODULE TAXCALC AT OFFSET +0A2C
JOB12345 ENDED - MAX COND CODE 0008
/*
//*-------------------------------------------------------------------
//* Run: scrape ANDRE.EPE.SCRAP.IN for lines containing 'ERROR'.
//* Matches appear as the dynamically allocated SCRAPOUT SYSOUT DS.
//*-------------------------------------------------------------------
//RUN      EXEC PGM=SOSCRAPE,COND=(0,LT,LKED),
//             PARM='ANDRE.EPE.SCRAP.IN ERROR'
//STEPLIB  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD
//SYSUDUMP DD  SYSOUT=*
//
