# 04 — ESTAE Recovery Demo

A batch HLASM program that deliberately triggers an abend, recovers in an
ESTAE recovery routine, formats key SDWA fields, and reports what
happened — with both RETRY and PERCOLATE variants.

## Purpose

Demonstrate recovery routine design and SDWA analysis — pairing directly
with deep dump/listing debugging skills — by causing a controlled failure
(e.g., S0C7 data exception) and handling it cleanly.

## Control blocks / services used

- **`ESTAE`** — establish the recovery routine.
- **SDWA** — System Diagnostic Work Area; the recovery routine inspects
  abend code, PSW, registers, and failing instruction address.
- **`SETRP`** — set return parameters to choose RETRY vs PERCOLATE.
- IBM macros: `ESTAE`, `SETRP`, `IHASDWA` (SDWA DSECT).

## Variants

- **RETRY** — recovery routine requests a retry at a clean resume point and
  the program continues.
- **PERCOLATE** — recovery routine reports, then lets the abend percolate
  so the failure is not suppressed.

## HLASM techniques demonstrated

- Establishing and coding an ESTAE recovery exit.
- Mapping and reading the SDWA with `IHASDWA`.
- Driving recovery flow with `SETRP` (RETRY / PERCOLATE / dump options).
- Formatting diagnostic fields for a readable report.
- Standard OS linkage; reentrancy considerations in the recovery path.

## Build instructions

_Placeholder — to be filled in when the program and JCL are written._
The plan: assemble against IBM macro libraries, link-edit to a load
library, and run a step that abends and is recovered; SYSOUT shows the
formatted SDWA report. Expect a non-zero (or zero, for RETRY) step
completion depending on the variant.
