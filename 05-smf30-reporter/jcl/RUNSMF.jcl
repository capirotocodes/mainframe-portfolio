//SMFRUN   JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*------------------------------------------------------------------*
//*  STEP 1: SCRATCH ANY PRIOR TEST DATASET                          *
//*------------------------------------------------------------------*
//DEL     EXEC PGM=IEFBR14
//OLD      DD  DSN=ANDRE.EPE.SMF30,DISP=(MOD,DELETE),
//             SPACE=(TRK,(1,1)),UNIT=SYSDA
//*------------------------------------------------------------------*
//*  STEP 2: GENERATE SYNTHETIC TYPE-30 SUBTYPE-5 RECORDS            *
//*------------------------------------------------------------------*
//GEN     EXEC PGM=MKSMF30
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//SYSUDUMP DD  SYSOUT=*
//OUTDD    DD  DSN=ANDRE.EPE.SMF30,DISP=(NEW,CATLG,DELETE),
//             SPACE=(TRK,(1,1)),
//             DCB=(RECFM=VB,LRECL=4096,BLKSIZE=4100)
//*------------------------------------------------------------------*
//*  STEP 3: READ THEM BACK AND PRINT THE REPORT                     *
//*------------------------------------------------------------------*
//RPT     EXEC PGM=SMFRPT30,COND=(0,NE)
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//INDD     DD  DSN=ANDRE.EPE.SMF30,DISP=SHR
//RPTDD    DD  SYSOUT=*
