# FLAGDB2 Feature-Flag Batch Skeleton

## Purpose

`FLAGDB2` is a small HLASM batch program skeleton created to demonstrate **progressive delivery / feature-flag routing** on z/OS without requiring a database dependency.

The idea is simple:

- the same load module can support more than one execution path
- the selected path is controlled by the JCL `PARM`
- no relink is required to switch behavior
- this is useful for controlled rollout, testing, fallback, and demonstration

This version is intentionally **non-DB2** because no active DB2 subsystem was confirmed in the target environment.

---

## What Was Built

Three artifacts were created and validated:

### 1. `z/andre/FLAGDB2.asm`

HLASM source for the batch program.

What it does:

- runs as a standard batch load module
- reads the JCL parameter area from register 1
- checks whether the incoming parameter text matches:

```text
NEW_BULK_EXTRACT=Y
```

Behavior:

- if the parameter matches, branch to the **new** path
- otherwise, branch to the **legacy** path

Current implementation notes:

- both paths currently return `RC=0`
- this is a skeleton/stub for demonstration and extension
- DB2 logic was intentionally removed/stubbed out

---

### 2. `z/andre/FLAGDB2C.jcl`

Compile/link JCL for the assembler program.

What it does:

- assembles `ANDRE.EPE.ASM(FLAGDB2)`
- link-edits the object
- stores the load module in:

```text
ANDRE.EPE.LOAD(FLAGDB2)
```

Outcome:

- compile/link completed successfully with `CC=0000`

---

### 3. `z/andre/FLAGDB2R.jcl`

Run JCL for the program.

What it does:

- executes `PGM=FLAGDB2`
- loads the module from:

```text
ANDRE.EPE.LOAD
```

Outcome:

- run completed successfully with `CC=0000`

---

## Why This Was Done

The original goal was to create a **batch HLASM skeleton with DB2 and feature-flag routing**.

During implementation, two important realities were found:

1. **DB2 was not active in the environment**
   - no DB2 subsystem was visible in the system activity display
   - embedded SQL could not be meaningfully completed without site-specific DB2 setup

2. **The first runtime versions abended**
   - early versions assembled but failed at runtime with `S0C4`
   - the failures were caused by entry/linkage/save-area handling assumptions that were not safe for this batch execution model

Because of that, the work was intentionally split into phases:

### Phase 1

Prove the batch assembler/link/run path works cleanly.

### Phase 2

Keep the feature-flag concept intact.

### Phase 3

Defer DB2 until a real subsystem and precompile flow are available.

This was the correct engineering choice because it reduced variables and produced a working, explainable baseline.

---

## Problems Encountered and Fixes Applied

## 1. Initial source was not assemble-clean

Early versions had issues such as:

- missing register equates
- invalid symbol usage
- no stable addressability
- raw embedded SQL that assembler could not process directly

### Fix

The source was rewritten into a clean HLASM-only skeleton first.

---

## 2. Compile JCL issues

The compile JCL initially had problems such as:

- invalid placeholder library names
- missing `SYSTERM`
- binder target not specifying a member name

### Fix

The JCL was corrected so that:

- assembler output was properly captured
- binder stored the module as `ANDRE.EPE.LOAD(FLAGDB2)`
- compile/link completed successfully

---

## 3. Runtime `S0C4` abends

Several runtime versions failed with protection/addressing exceptions.

### Root cause

The early prolog/save-area handling was not stable for the way the program was being invoked in batch.

### Fix

The final version uses a safer runtime structure:

- standard save/return handling
- dynamic work area allocation
- simplified parameter inspection logic
- minimal writable state

This eliminated the runtime abend.

---

## 4. Dump handling confusion

A temporary attempt was made to write `SYSUDUMP` to a dataset for IPCS.

### Result

That produced a formatted dump listing, not a true IPCS dump image.

### Decision

That path was abandoned because it was not needed once the runtime issue was fixed.

---

## Final Technical Design

The final `FLAGDB2` design is intentionally simple.

### Entry behavior

- save caller context
- establish addressability
- obtain a small dynamic work area

### Parameter handling

- inspect the standard JCL parameter area passed in register 1
- if no parameter is present, use legacy path
- if parameter length is less than 18, use legacy path
- if parameter text equals `NEW_BULK_EXTRACT=Y`, use new path
- otherwise, use legacy path

### Exit behavior

- free dynamic work area
- return to caller with `RC=0`

---

## How to Explain the Feature-Flag Concept

A simple explanation:

> `FLAGDB2` demonstrates how one z/OS batch program can support multiple behaviors without changing the load module.  
> The JCL `PARM` acts as a feature flag.  
> This allows controlled rollout of new logic while preserving a fallback path.

You can also explain it this way:

- **legacy path** = current stable behavior
- **new path** = candidate behavior under controlled activation
- **PARM value** = rollout switch

This is similar to feature flags in distributed/cloud applications, but implemented in a traditional z/OS batch model.

---

## Example Usage

### Legacy/default path

Run without the feature flag:

```jcl
//RUN      EXEC PGM=FLAGDB2,REGION=0M
```

Expected result:

- legacy path selected
- job completes with `CC=0000`

### New path

Run with the feature flag enabled:

```jcl
//RUN      EXEC PGM=FLAGDB2,REGION=0M,PARM='NEW_BULK_EXTRACT=Y'
```

Expected result:

- new path selected
- job completes with `CC=0000`

---

## What This Is For

This implementation is useful for:

- demonstrating progressive delivery on z/OS
- showing how JCL `PARM` can control behavior
- teaching HLASM batch structure
- providing a safe baseline before adding DB2
- proving compile/link/run mechanics in the target environment

---

## What It Is Not Yet

This is **not yet**:

- a real DB2 application
- a production business program
- a complete canary/telemetry framework
- a full blue/green deployment system

It is a **working skeleton** intended to be extended.

---

## Recommended Next Steps

### Option 1: Keep it as a demo

Use it as a presentation/demo artifact for:

- feature flags
- progressive delivery
- z/OS batch modernization concepts

### Option 2: Add visible path output

Enhance the program so it writes which path was selected:

- legacy
- new

This would make demonstrations easier.

### Option 3: Reintroduce DB2 later

Only after confirming:

- active DB2 subsystem
- precompile procedure
- DB2 libraries
- bind/package requirements

Then the new path could contain real DB2 logic.

---

## Final Outcome

The final result is:

- a compile-clean HLASM batch skeleton
- a run-clean load module
- feature-flag routing controlled by JCL `PARM`
- no DB2 dependency
- validated with successful compile and run return codes

---

## Key Files

- `z/andre/FLAGDB2.asm`
- `z/andre/FLAGDB2C.jcl`
- `z/andre/FLAGDB2R.jcl`

---

## One-Sentence Summary

`FLAGDB2` is a working z/OS HLASM batch skeleton that demonstrates feature-flag-driven routing through JCL parameters, providing a safe baseline for future enhancement such as DB2 integration.
