//EPEALLOC JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*-------------------------------------------------------------------
//* One-time bootstrap allocation of the libraries BUILDEX.jcl expects.
//*
//* IN THE AUTHOR'S ENVIRONMENT ALL THREE ALREADY EXIST:
//*   ANDRE.EPE.MACLIB   ANDRE.EPE.ASM   ANDRE.EPE.LOAD
//* so there is nothing to allocate and you do NOT need to submit this.
//*
//* WHY: allocating a dataset that already exists fails with IGD17101I
//* (DUPLICATE NAME) during allocation, which FLUSHES THE WHOLE JOB.
//* All real allocation steps are therefore commented out below and
//* kept only as templates for a fresh HLQ.  Before uncommenting a
//* step, confirm the dataset is missing, e.g.:
//*   TSO LISTC ENT('ANDRE.EPE.LOAD')
//* Then upload members via Zowe/ISPF:
//*   ANDRE.EPE.MACLIB <- the .mac members (no extension)
//*   ANDRE.EPE.ASM    <- examples/DEMOSP.asm  as member DEMOSP
//* Adjust the HLQ to your installation.
//*-------------------------------------------------------------------
//* No-op anchor so this job ends RC=0 if submitted as-is (no EXEC
//* statement would otherwise be a JCL error).  Touches nothing.
//NOOP     EXEC PGM=IEFBR14
//*-------------------------------------------------------------------
//* TEMPLATES - uncomment only the datasets that do not yet exist.
//*-------------------------------------------------------------------
//*MACLIB  EXEC PGM=IEFBR14
//*DD1     DD  DISP=(NEW,CATLG),DSN=ANDRE.EPE.MACLIB,
//*            SPACE=(TRK,(15,15,20)),
//*            DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920)
//*SRCLIB  EXEC PGM=IEFBR14
//*DD1     DD  DISP=(NEW,CATLG),DSN=ANDRE.EPE.ASM,
//*            SPACE=(TRK,(15,15,20)),
//*            DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920)
//* PDSE for load modules (no directory-block count needed for PDSE).
//*LOADLIB EXEC PGM=IEFBR14
//*DD1     DD  DISP=(NEW,CATLG),DSN=ANDRE.EPE.LOAD,
//*            DSNTYPE=LIBRARY,
//*            SPACE=(TRK,(15,15)),
//*            DCB=(RECFM=U,BLKSIZE=32760)
//
