//DEMOSP   JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//*-------------------------------------------------------------------
//* Assemble, link-edit, and run DEMOSP, the structured-programming
//* demo that exercises the personal macro library.
//*
//* PREREQUISITE CHECKLIST  (skip any item and OPEN abends, e.g. a
//* missing SYSIN member gives S013-18 in step ASM):
//*   [ ] 1. Allocate the three datasets below.  Run ALLOC.jcl once,
//*          or pre-allocate by hand:
//*            ANDRE.EPE.MACLIB  PDS,  RECFM=FB LRECL=80  (macros)
//*            ANDRE.EPE.ASM     PDS,  RECFM=FB LRECL=80  (source)
//*            ANDRE.EPE.LOAD    PDS/PDSE, RECFM=U        (load mods)
//*   [ ] 2. Upload the .mac members (NO extension) into ANDRE.EPE.MACLIB
//*          via Zowe/ISPF.
//*   [ ] 3. Upload examples/DEMOSP.asm as member ANDRE.EPE.ASM(DEMOSP).
//*          Verify with:  TSO LISTDS 'ANDRE.EPE.ASM' MEMBERS
//*   Adjust the HLQ on all DSNs below to match your installation.
//*-------------------------------------------------------------------
//ASM      EXEC PGM=ASMA90,REGION=0M,
//             PARM='OBJECT,NODECK,LIST,XREF(SHORT)'
//SYSLIB   DD  DISP=SHR,DSN=ANDRE.EPE.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MODGEN
//SYSIN    DD  DISP=SHR,DSN=ANDRE.EPE.ASM(DEMOSP)
//SYSLIN   DD  DISP=(,PASS),DSN=&&OBJ,UNIT=SYSDA,
//             SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSPRINT DD  SYSOUT=*
//*-------------------------------------------------------------------
//LKED     EXEC PGM=IEWL,COND=(0,LT,ASM),
//             PARM='LIST,MAP,XREF,RMODE=ANY,AMODE=31'
//SYSLIN   DD  DISP=(OLD,DELETE),DSN=&&OBJ
//SYSLMOD  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD(DEMOSP)
//SYSPRINT DD  SYSOUT=*
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//*-------------------------------------------------------------------
//RUN      EXEC PGM=DEMOSP,COND=(0,LT,LKED)
//STEPLIB  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//
