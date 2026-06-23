//FLAGDB2R JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//********************************************************************
//* RUN FLAGDB2 - DEFAULT / LEGACY PATH                              *
//* WRITES A REAL DUMP DATA SET SUITABLE FOR IPCS                    *
//********************************************************************
//RUN      EXEC PGM=FLAGDB2,REGION=0M
//STEPLIB  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//********************************************************************
//* ALTERNATE TEST: NEW PATH                                         *
//* Change EXEC to:                                                  *
//* //RUN EXEC PGM=FLAGDB2,REGION=0M,PARM='NEW_BULK_EXTRACT=Y'       *
//********************************************************************

