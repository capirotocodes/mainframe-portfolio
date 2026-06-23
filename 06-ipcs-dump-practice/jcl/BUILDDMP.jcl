//BUILDDMP JOB (ACCT),'BUILD DUMPPGM',
//         CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID,
//         MSGLEVEL=(1,1),REGION=0M
//*
//*********************************************************************
//* JOB:     BUILDDMP                                                 *
//* PURPOSE: Assemble and link DUMPPGM for IPCS practice             *
//*********************************************************************
//*
//ASM      EXEC PGM=ASMA90,PARM='OBJECT,NODECK,NOLIST'
//SYSLIB   DD DISP=SHR,DSN=SYS1.MACLIB
//         DD DISP=SHR,DSN=SYS1.MODGEN
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(5,2))
//SYSUT2   DD UNIT=SYSDA,SPACE=(CYL,(5,2))
//SYSUT3   DD UNIT=SYSDA,SPACE=(CYL,(5,2))
//SYSPRINT DD SYSOUT=*
//SYSLIN   DD UNIT=SYSDA,SPACE=(TRK,(5,5)),
//            DISP=(NEW,PASS),DSN=&&OBJMOD
//SYSIN    DD DISP=SHR,DSN=&SYSUID..SOURCE.ASM(DUMPPGM)
//*
//LKED     EXEC PGM=IEWL,PARM='MAP,LIST,LET,RENT,REUS,REFR',
//         COND=(0,NE,ASM)
//SYSLIN   DD DISP=(OLD,DELETE),DSN=&&OBJMOD
//SYSLMOD  DD DISP=SHR,DSN=&SYSUID..LOAD.LIB(DUMPPGM)
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(5,2))
//SYSPRINT DD SYSOUT=*
//*

//* Made with Bob
