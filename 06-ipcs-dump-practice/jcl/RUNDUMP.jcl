//RUNDUMP  JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1),REGION=0M
//*
//*********************************************************************
//* JOB:     RUNDUMP                                                  *
//* PURPOSE: Execute DUMPPGM to generate system dump for IPCS        *
//*                                                                   *
//* NOTES:                                                            *
//*   - Program will ABEND U0013 with dump                           *
//*   - SYSUDUMP captures the dump for IPCS analysis                 *
//*   - Dump dataset can be used with IPCS commands                  *
//*********************************************************************
//*
//STEP1    EXEC PGM=DUMPPGM
//STEPLIB  DD DISP=SHR,DSN=ANDRE.EPE.LOAD
//SYSOUT   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSABEND DD DISP=(MOD,CATLG,CATLG),
//            DSN=ANDRE.IPCS.ABEND,
//            UNIT=SYSDA,
//            SPACE=(CYL,(50,10),RLSE),
//            DCB=(RECFM=VBS,LRECL=4160,BLKSIZE=4164)
//*
//* Alternative: Use SYSABEND for more detailed dump
//* Uncomment the following and comment out SYSUDUMP above
//*
//*SYSABEND DD DISP=(NEW,CATLG,DELETE),
//*            DSN=&SYSUID..IPCS.ABEND,
//*            UNIT=SYSDA,
//*            SPACE=(CYL,(15,10),RLSE),
//*            DCB=(RECFM=VBS,LRECL=4160,BLKSIZE=4164)
//*
