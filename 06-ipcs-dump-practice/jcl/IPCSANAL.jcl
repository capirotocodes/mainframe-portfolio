//IPCSANAL JOB (ACCT),'IPCS ANALYSIS',
//         CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID,
//         MSGLEVEL=(1,1),REGION=0M
//*
//*********************************************************************
//* JOB:     IPCSANAL                                                 *
//* PURPOSE: Sample JCL to analyze dump using IPCS batch             *
//*                                                                   *
//* NOTES:                                                            *
//*   - This demonstrates batch IPCS commands                        *
//*   - Can also use TSO IPCS for interactive analysis               *
//*********************************************************************
//*
//IPCS     EXEC PGM=IKJEFT01,DYNAMNBR=50,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  IPCS
  SETDEF DSNAME('&SYSUID..IPCS.DUMP') NOCONFIRM
  STATUS
  SUMMARY
  REGS
  WHERE
  LISTDUMP PSW,REGS,SAVE,SPLS,TRACE
  VERBX REGS
  VERBX STORAGE
  FIND 'DUMP' ASID(X'0001')
  FIND 'DUMPPGM' ASID(X'0001')
  FIND 'This is sample data' ASID(X'0001')
  END
/*
//*
//* Alternative commands for more detailed analysis:
//*
//* CBFORMAT - Format control blocks
//* SYSTRACE - Display system trace
//* SUMMARY FORMAT - Formatted summary
//* VERBEXIT LIST - List available exits
//* WHERE - Show location of failure
//* LISTSYM - List symbols
//*
