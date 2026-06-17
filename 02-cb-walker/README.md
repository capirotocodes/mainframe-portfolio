# 02 — Control Block Walker

A batch HLASM program that walks the standard z/OS control block chain
starting at the PSA (address 0) and prints key fields from each block.

## Purpose

Demonstrate confident navigation of core z/OS control blocks and strict
DSECT discipline — never hardcoding offsets — while producing a readable
report of system identity fields.

## Control block chain

```
PSA (addr 0) --> CVT --> ASCB --> TCB
```

- **PSA** — Prefixed Save Area; entry point at address 0.
- **CVT** — Communications Vector Table; the root of most chains.
- **ASCB** — Address Space Control Block (current address space).
- **TCB** — Task Control Block (current task).

## DSECTs used (IBM-supplied)

| Block | DSECT macro |
|-------|-------------|
| PSA   | `IHAPSA` |
| CVT   | `CVT` |
| ASCB  | `IHAASCB` |
| TCB   | `IKJTCB` |

## HLASM techniques demonstrated

- Control block navigation by chasing pointers between blocks.
- `USING`/`DROP` addressability against IBM DSECTs.
- Reading live system storage in a batch program.
- Standard OS linkage (AMODE 31 / RMODE ANY).
- Formatting fields for a printed report (ties to `@HEXOUT` from
  artifact 1, optionally).

## Build instructions

Source: `src/CBWALK.asm`. Build JCL: `jcl/BUILDCBW.jcl` (assemble → link →
run). The program reuses the artifact-1 macros, so the assembler `SYSLIB`
concatenates `ANDRE.EPE.MACLIB` ahead of `SYS1.MACLIB` and `SYS1.MODGEN`
(the IBM DSECT/macro libraries).

Build via Zowe (from this directory):

```
zowe files upload ftds "src/CBWALK.asm" "ANDRE.EPE.ASM(CBWALK)"
zowe jobs submit local-file "jcl/BUILDCBW.jcl" --wait-for-output --rfj
```

The three steps (`ASM` / `LKED` / `RUN`) each end COND CODE 0000; the report
is written to the `RUN` step's `SYSPRINT`.

## Sample output

Verified run on system `ZOS31` (job `CBWALKB`):

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

The cross-checks confirm the walk reads live storage: `CVTSNAME` is the
running system's name, and `ASCBASID`/`JOBNAME` are this job's own address
space and name.

## Return codes

| RC | Meaning |
|----|---------|
| 0  | Clean full walk — all four blocks reported. |
| 4  | A pointer was zero or the ASCB eyecatcher failed; chain truncated. |
| 8  | SYSPRINT could not be opened. |

## Design notes

See `docs/DESIGN.md` for the full design. Two points worth highlighting for
a code review:

- **`USING PSA,0`** reads the PSA at absolute low-storage addresses (base
  register 0 contributes 0); each subsequent block is addressed off the
  pointer chased from the previous one, always through the IBM DSECT — no
  hardcoded offsets.
- **Above-the-line I/O.** The program is `RMODE ANY`, so its DCB assembles
  above the 16 MB line. `OPEN`/`CLOSE` use `MODE=31` (a 31-bit parameter
  list — the default 3-byte `AL3` DCB address can't be relocated above the
  line), and because a base QSAM DCB still cannot be *opened* above the
  line, the DCB is kept as a model and copied into `GETMAIN ...,LOC=BELOW`
  storage at run time. This keeps the program `RMODE ANY` while satisfying
  QSAM's below-the-line DCB requirement.
