//ALLOCLIB JOB (ACCT),'ALLOC LOAD LIB',
//         CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//*
//* Allocate load library for DUMPPGM
//*
//ALLOC    EXEC PGM=IEFBR14
//LOADLIB  DD DSN=&SYSUID..LOAD.LIB,
//            DISP=(NEW,CATLG,DELETE),
//            UNIT=SYSDA,
//            SPACE=(TRK,(10,5,5)),
//            DCB=(RECFM=U,BLKSIZE=32760,LRECL=0,DSORG=PO)
//*

//* Made with Bob
