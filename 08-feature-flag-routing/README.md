# 08 — Feature-Flag Routing (FEATFLAG)

A single batch HLASM load module that selects one of two execution paths —
**LEGACY** or **NEW** — from the EXEC `PARM`, with no relink needed to
switch. The z/OS-batch expression of a feature flag / progressive-delivery
pattern.

## Purpose

Demonstrate parm-driven behaviour selection: ship one module, then turn a
candidate code path on or off per run by changing only the JCL. The chosen
route is announced by `WTO` (`ROUTCDE=(11)`) so it shows in the job log.

| `PARM` | Route | Step result |
|--------|-------|-------------|
| (absent) or anything else | **LEGACY** (flag off) | RC 0 |
| `NEW_BULK_EXTRACT=Y` | **NEW** (flag on) | RC 0 |

## Files

| File | What it is |
|------|------------|
| `src/FEATFLAG.asm` | The program — one CSECT, `AMODE 31 / RMODE ANY`. |
| `jcl/BUILDFF.jcl` | Assemble (`ASMA90`) + bind (`IEWL`) into the load library. |
| `jcl/RUNFF.jcl` | Run both ways: no PARM (LEGACY) then the flag value (NEW). |
| `docs/DESIGN.md` | Design, the parm-pointer bug it fixes, edge cases, verified run. |

## HLASM techniques demonstrated

- EXEC `PARM` inspection (length-prefixed parameter area from R1).
- **Register-1 lifetime discipline** — the parm pointer is saved before
  any R1-clobbering service runs. This is the defect the original
  skeleton had (`GETMAIN` destroyed R1 before the parm was read, so the
  flag never matched); see `docs/DESIGN.md`.
- Standard `@ENTER`/`@LEAVE` linkage; `WTO ROUTCDE=(11)` reporting.

## Build instructions

1. Upload `src/FEATFLAG.asm` as member `FEATFLAG` in your source PDS and
   the JCL members into a JCL PDS (the supplied JCL uses `ANDRE.EPE.*` —
   retarget to your environment).
2. Submit `jcl/BUILDFF.jcl` — assembles against `ANDRE.EPE.MACLIB` +
   `SYS1.MACLIB` + `SYS1.MODGEN` and binds `AMODE 31 / RMODE ANY` into the
   load library.
3. Submit `jcl/RUNFF.jcl`. Expect both steps to end RC 0, with the job log
   showing `FEATFLAG ROUTE=LEGACY` for the no-PARM step and
   `FEATFLAG ROUTE=NEW` for the `PARM='NEW_BULK_EXTRACT=Y'` step.

**Status: built and verified on a real z/OS system** — assembles and links
clean; STEP1 routes LEGACY and STEP2 routes NEW, both COND CODE 0000. See
[docs/DESIGN.md](docs/DESIGN.md) for the captured job log.
