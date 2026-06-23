//FLAGDB2C JOB AMS-CLEAN,
//             ANDRE,
//             NOTIFY=ANDRE,CLASS=A,
//             MSGLEVEL=(1,1)
//********************************************************************
//* FLAGDB2 DB2 HLASM BUILD SKELETON                                 *
//*                                                                  *
//* NOTE: THIS IS A SITE-DEPENDENT SKELETON. DB2 PRECOMPILE AND      *
//* LINK-EDIT LIBRARIES/VERSIONS MAY NEED ADJUSTMENT FOR YOUR SHOP.  *
//********************************************************************
//ASM      EXEC PGM=ASMA90,REGION=0M,
//             PARM='OBJECT,NODECK'
//SYSLIB   DD  DISP=SHR,DSN=ANDRE.EPE.ASM
//         DD  DISP=SHR,DSN=SYS1.MACLIB
//         DD  DISP=SHR,DSN=SYS1.MODGEN
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT2   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT3   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD  SYSOUT=*
//SYSTERM  DD  SYSOUT=*
//SYSLIN   DD  DSN=&&OBJSET,UNIT=SYSDA,SPACE=(TRK,(3,3)),
//             DISP=(MOD,PASS)
//SYSIN    DD  DISP=SHR,DSN=ANDRE.EPE.ASM(FLAGDB2)
//LKED     EXEC PGM=IEWL,COND=(8,LT,ASM),REGION=0M,
//             PARM='LIST,XREF,LET,MAP,RENT'
//SYSLMOD  DD  DISP=SHR,DSN=ANDRE.EPE.LOAD(FLAGDB2)
//SYSLIN   DD  DSN=&&OBJSET,DISP=(OLD,DELETE)
//SYSLIB   DD  DISP=SHR,DSN=CEE.SCEELKED
//SYSUT1   DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD  SYSOUT=*
//********************************************************************
//* TEMPORARILY REMOVED THE DB2 LOAD LIBRARY PLACEHOLDER BECAUSE     *
//* DSN!!0.SDSNLOAD IS NOT VALID JCL. THIS SKELETON NOW TESTS BASIC  *
//* ASSEMBLE/LINK FLOW ONLY.                                         *
//*                                                                  *
//* IF YOUR SHOP REQUIRES DB2 PRECOMPILE OR DB2 RUNTIME LIBRARIES,   *
//* ADD THE CORRECT SITE DATA SET NAMES HERE.                        *
//********************************************************************

