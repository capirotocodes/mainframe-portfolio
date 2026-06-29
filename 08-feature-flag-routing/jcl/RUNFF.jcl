//FFRUN    JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*------------------------------------------------------------------*
//*  RUN FEATFLAG BOTH WAYS - same load module, different EXEC PARM.  *
//*  STEP1 (no PARM)            -> LEGACY route, RC 0.                 *
//*  STEP2 PARM='NEW_BULK_EXTRACT=Y' -> NEW route, RC 0.              *
//*  The chosen route is reported by WTO to JESMSGLG (ROUTCDE=11).    *
//*------------------------------------------------------------------*
//LEGACY  EXEC PGM=FEATFLAG
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
//*------------------------------------------------------------------*
//NEW     EXEC PGM=FEATFLAG,PARM='NEW_BULK_EXTRACT=Y'
//STEPLIB  DD  DSN=ANDRE.EPE.LOAD,DISP=SHR
