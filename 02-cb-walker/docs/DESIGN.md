# Design — Control Block Walker

## Goal

A batch HLASM program (`CBWALK`) that walks the standard z/OS control-block
chain starting at the PSA (address 0) and prints key identity fields from
each block to a SYSPRINT report:

```
PSA (addr 0) --> CVT --> ASCB (current) --> TCB (current)
```

The program demonstrates confident control-block navigation and strict DSECT
discipline — every field is read through an IBM-supplied DSECT, never a
hardcoded offset — while producing a report that reads cleanly in a code
review. It reuses the artifact-1 macro library (`@ENTER`, `@LEAVE`,
`@HEXOUT`) so the library is shown working inside a real program.

## Conventions

- z/OS HLASM, AMODE 31, RMODE ANY. Problem state, key 8.
- Single CSECT `CBWALK`. Standard OS linkage via `@ENTER`/`@LEAVE`.
- SYSLIB concatenation: `ANDRE.EPE.MACLIB` (the personal macros) ahead of
  `SYS1.MACLIB` and `SYS1.MODGEN` (the IBM DSECT macros).

## Register plan

| Reg | Role |
|-----|------|
| R12 | program base (established by `@ENTER`) |
| R13 | save area (chained by `@ENTER`) |
| R3  | CVT address |
| R4  | ASCB address (current address space) |
| R5  | TCB address (current task) |
| R2  | scratch (e.g. jobname pointer) |
| R6  | link register for the `PUTHEX`/`PUTLINE` subroutines |
| R7  | address of the live (below-the-line) SYSPRINT DCB |
| R0,R1,R14,R15 | volatile across `@HEXOUT` and QSAM linkage |

## DSECTs used (IBM-supplied)

| Block | DSECT macro |
|-------|-------------|
| PSA   | `IHAPSA` |
| CVT   | `CVT`     |
| ASCB  | `IHAASCB` |
| TCB   | `IKJTCB`  |

Reading every field through these DSECTs gives an important safety property:
a wrong field name fails at **assembly** with a clean `ASMAxxxE`, never as a
runtime surprise. The field names below are the intended targets; exact
spellings are pinned against the live macros during implementation.

## The walk

Approach: a single linear CSECT with one labelled section per block, read
top-to-bottom in the same order as the chain it traverses. Each section
establishes a `USING` on its DSECT, validates, formats fields with
`@HEXOUT`, `PUT`s its lines, then `DROP`s.

### Addressing the PSA (address 0)

`USING PSA,0` (the `IHAPSA` macro generates a DSECT named `PSA`) — register
0 as the `USING` base contributes 0 to the effective address, so PSA fields
resolve to their absolute low-storage addresses. The three pointers are
captured, then `DROP 0`:

- `FLCCVT`  (CVT pointer)          → R3
- `PSAAOLD` (current ASCB pointer) → R4
- `PSATOLD` (current TCB pointer)  → R5

### Per-block fields

| Block | Base | Fields reported |
|-------|------|-----------------|
| PSA  | `0` | `FLCCVT`, `PSAAOLD`, `PSATOLD` (the chain pointers) |
| CVT  | R3  | `CVTSNAME` (system name), `CVTECVT` (ECVT pointer) |
| ASCB | R4  | `ASCBASCB` eyecatcher, `ASCBASID` (ASID), jobname via `ASCBJBNI`/`ASCBJBNS` |
| TCB  | R5  | `TCBRBP` (current RB), `TCBCMP` (completion code) |

Jobname: `ASCBJBNI` (jobs via initiator) is used if non-zero, otherwise
`ASCBJBNS` (started tasks); the pointer addresses an 8-byte EBCDIC name.

## Validation and error handling

Only the **ASCB** carries a start-of-block acronym (`ASCBASCB` = `C'ASCB'`).
The PSA, CVT, and TCB have no eyecatcher at offset 0, so validation is
applied where it is meaningful:

- Before dereferencing **any** pointer: verify it is non-zero. A zero
  pointer prints an error line and stops the chain cleanly rather than
  taking an addressing exception.
- **ASCB**: compare `ASCBASCB` with `C'ASCB'`; on mismatch, print an error
  line and skip the ASCB and TCB sections.

There is deliberately **no `ESTAE` recovery** in this artifact — recovery is
the subject of artifact 4. The non-zero pointer checks remove the common
failure, but a wild pointer that passes them could still abend S0C4. This
boundary is a conscious choice, not an oversight.

### Return codes

| RC | Meaning |
|----|---------|
| 0  | Clean full walk — all four blocks reported. |
| 4  | Walk completed but a validation check failed / chain truncated. |
| 8  | SYSPRINT could not be opened (nothing could be reported). |

The return code alone tells you whether the chain was fully traversed.

## Report format

QSAM, basic sequential `PUT`:

- `DCB DSORG=PS,MACRF=PM,RECFM=FBA,LRECL=121,DDNAME=SYSPRINT`
- `OPEN (SYSPRINT,OUTPUT),MODE=31`; check `TM DCBOFLGS,DCBOFOPN`; `PUT`
  lines; `CLOSE (SYSPRINT),MODE=31`.

  **Why `MODE=31`:** the default `OPEN`/`CLOSE` parameter list encodes the
  DCB address as a 3-byte (`AL3`) constant — a 24-bit form. For an
  `RMODE ANY` module loaded above the 16 MB line the binder cannot relocate
  that adcon (`IEW2635I`) and `OPEN` takes an `S0C4` reason 11 at run time
  (the same 24-bit-adcon trap that bit `@PCALL` in artifact 1). `MODE=31`
  generates a 31-bit parameter list with full 4-byte DCB addresses, so the
  program keeps `RMODE ANY` and opens correctly from above the line.

  **Below-the-line DCB:** `MODE=31` fixes the *parameter list*, but the base
  DCB itself still cannot be opened above the line — OPEN issues `IEC190I`
  and leaves `DCBOFOPN` off. (A `DCBE RMODE31=BUFF` does **not** help; it
  only moves *buffers* above the line, not the DCB.) So the DCB is assembled
  as a model in the CSECT (`DCBMODL`), and at run time the program does
  `GETMAIN ...,LOC=BELOW`, copies the model into that below-the-line
  storage, and opens the copy (R7 → live DCB). `FREEMAIN` releases it on
  both the normal and open-failure exits. This keeps the program `RMODE ANY`
  while satisfying QSAM's below-the-line DCB requirement.
- Line buffer `CL121`. Byte 1 is ANSI carriage control: `'1'` (page eject)
  for the title, `'0'` (double space) for block headers, `' '` (single
  space) for detail lines. Each line is blank-filled before use.
- `@HEXOUT` formats 4-byte pointers/values into 8 EBCDIC hex characters;
  character fields (system name, jobname, eyecatcher) are moved with `MVC`.

Actual output (verified run on system `ZOS31`, job `CBWALKB`):

```
z/OS CONTROL BLOCK WALK
PSA  @ 00000000
     FLCCVT  (CVT)       00FD5858
     PSAAOLD (ASCB)      00FB8200
     PSATOLD (TCB)       008D0A88
CVT
     CVTSNAME (sys)      ZOS31
     CVTECVT (ECVT)      01E00D18
ASCB
     ASCBASID (id)       0000003C
     JOBNAME             CBWALKB
TCB
     TCBRBP  (RB)        008D00A0
     TCBCMP  (comp)      00000000
```

## Edge cases / what could go wrong

- **Broken / zero pointer** — diagnosed and reported; chain stops cleanly,
  RC=4. (Not expected in normal operation, but proves the discipline.)
- **Bad ASCB eyecatcher** — reported; ASCB/TCB skipped, RC=4.
- **Fetch protection** — the PSA/CVT/ASCB/TCB fields read here are not
  fetch-protected, so a problem-state program can read them. Documented
  assumption; no key switch is performed.
- **Wrong DSECT field name** — fails at assembly (clean), never at run time.
- **No recovery** — see the validation note above; ESTAE is out of scope for
  this artifact.

## On-system build

JCL in `../jcl/` (to be written):

1. **ASM** — `ASMA90`, `PARM='OBJECT,NODECK,LIST,XREF(SHORT)'`; SYSLIB =
   `ANDRE.EPE.MACLIB` + `SYS1.MACLIB` + `SYS1.MODGEN`; SYSIN =
   `ANDRE.EPE.ASM(CBWALK)`.
2. **LKED** — `IEWL`, link to `ANDRE.EPE.LOAD(CBWALK)`.
3. **RUN** — `EXEC PGM=CBWALK` with `SYSPRINT DD SYSOUT=*` and
   `SYSUDUMP DD SYSOUT=*`.

Built and run via the Zowe loop (upload `src/CBWALK.asm` as member `CBWALK`,
submit, read the spool). Cannot be assembled locally.

### Verification

No local assembly is possible, so correctness is confirmed on the system:

- Assemble clean (severity 0–4), link RC=0, run RC=0.
- **Sanity-check the report against known truth:** `CVTSNAME` must match this
  LPAR's MVS system name (`ZOS31` on the build system — note this is the
  `SYSNAME`, distinct from the 4-char JES2/SMF id `ZS31` shown in the job
  log), and `ASCBASID`/jobname must match the running `CBWALKB` job. Both
  agreed on the verified run, confirming the walk reads the correct live
  storage — not just plausible-looking hex.
