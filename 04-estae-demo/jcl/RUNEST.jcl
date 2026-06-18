//ESTRUN   JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*------------------------------------------------------------------*
//*  ESTDEMO - DEMONSTRATE BOTH RECOVERY PATHS                       *
//*    STEP RETRY : RECOVERS THE S0C7, CONTINUES, ENDS RC 0          *
//*    STEP PERC  : REPORTS THEN PERCOLATES -> STEP ABENDS S0C7      *
//*  NO DUMP DD: DIAGNOSTICS GO TO WTO (JESMSGLG); SVC DUMPS ARE     *
//*  SUPPRESSED INSTALLATION-WIDE ON THIS SYSTEM.                    *
//*------------------------------------------------------------------*
//RETRY   EXEC PGM=ESTDEMO,PARM='RETRY'
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//*
//PERC    EXEC PGM=ESTDEMO,PARM='PERCOLATE',COND=EVEN
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
