# Design Document: Ansible Automation for z/OS

## Architecture

```
Windows/Linux → Ansible → z/OSMF REST API → z/OS JES → CLIST → Assembler/Linker
```

## Components

### 1. JCL (COMPASM.jcl)

Invokes TSO CLIST to compile assembler programs:

```jcl
//ANDREC   JOB CLASS=A,MSGCLASS=W
//COMPILE  EXEC PGM=IKJEFT01
//SYSPROC  DD DSN=ANDRE.CLIST,DISP=SHR
//SYSTSIN  DD *
  %COMPILE MEMBER(MYPROG) CLASS(A) SYSOUT(W) RENT(N)
/*
```

### 2. Ansible Playbook

Automates the compilation process:

- Reads JCL content
- Submits via z/OSMF REST API
- Monitors job completion
- Reports results

### 3. COMPILE CLIST

Two-step process:

- **Assembly**: ASMA90 assembles source to object
- **Link-Edit**: IEWL creates load module

## Data Flow

1. Ansible reads JCL from local file
2. HTTP PUT to z/OSMF `/zosmf/restjobs/jobs`
3. z/OSMF submits to JES internal reader
4. JES schedules and executes job
5. TSO runs CLIST with parameters
6. ASMA90 assembles, IEWL link-edits
7. Ansible polls for completion
8. Results retrieved and displayed

## REST API Endpoints

### Submit Job

```
PUT https://host:443/zosmf/restjobs/jobs
Content-Type: text/plain
Body: <JCL content>
```

### Check Status

```
GET https://host:443/zosmf/restjobs/jobs/JOBNAME/JOBID
```

### Get Output

```
GET https://host:443/zosmf/restjobs/jobs/JOBNAME/JOBID/files
GET https://host:443/zosmf/restjobs/jobs/JOBNAME/JOBID/files/ID/records
```

## Return Codes

| Code    | Meaning               |
| ------- | --------------------- |
| CC 0000 | Success               |
| CC 0004 | Success with warnings |
| CC 0008 | Warnings              |
| CC 0012 | JCL error             |

## Security

- Basic auth over HTTPS
- Password in environment variable
- TLS certificate validation disabled (dev only)

## Performance

- Typical compile time: 5-15 seconds
- Polling interval: 2 seconds
- Max wait time: 60 seconds

---

_Technical design by Andre - June 2026_
