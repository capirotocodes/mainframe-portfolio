//ANDREC   JOB CLASS=A,MSGCLASS=W,NOTIFY=&SYSUID
//********************************************************************
//*  Compile Assembler Program using COMPILE CLIST                  *
//********************************************************************
//COMPILE  EXEC PGM=IKJEFT01
//SYSTSPRT DD SYSOUT=*
//SYSPROC  DD DSN=ANDRE.CLIST,DISP=SHR
//SYSTSIN  DD *
  %COMPILE MEMBER(MYPROG) CLASS(A) SYSOUT(W) RENT(N)
/*
