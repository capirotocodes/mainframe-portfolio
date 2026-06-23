# IPCS Dump Practice - Design Document

## Overview

This project provides a complete system for generating and analyzing system dumps using IPCS (Interactive Problem Control System). It includes a sample program that creates interesting data structures and forces a dump, along with JCL for building, executing, and analyzing the dump.

## Purpose

The primary purpose is to provide hands-on practice with IPCS dump analysis in a controlled environment. This is valuable for:

- Learning IPCS commands and techniques
- Understanding dump structure and content
- Practicing problem determination skills
- Training new system programmers
- Testing IPCS configurations

## Components

### 1. DUMPPGM (src/DUMPPGM.asm)

Assembly language program that:

- **Creates Sample Data Structures**: Builds various data structures that are interesting to examine in a dump
- **Establishes Save Area Chain**: Creates proper save area linkage for stack analysis
- **Builds Control Blocks**: Creates a chain of control blocks with eye-catchers
- **Fills Buffers**: Populates buffers with patterns and text strings
- **Forces Dump**: Issues ABEND U0013 with DUMP option

#### Data Structures Created

1. **Header Structure** (24 bytes)
   - Eye-catcher: 'DUMP'
   - Version number
   - Program name
   - Timestamp (time and date)

2. **Sample Table** (10 entries × 12 bytes)
   - Entry number
   - Entry name with identifier
   - Demonstrates table structures

3. **Control Block Chain** (3 blocks × 16 bytes)
   - Eye-catchers: 'CTL1', 'CTL2', 'CTL3'
   - Forward and backward pointers
   - Data fields
   - Demonstrates linked structures

4. **Buffer** (256 bytes)
   - Pattern fill (0x00-0xFF repeating)
   - Text strings for searching
   - Demonstrates memory content analysis

### 2. Build JCL (jcl/BUILDDMP.jcl)

Two-step JCL to assemble and link the program:

- **ASM Step**: Assembles DUMPPGM.asm using ASMA90
- **LKED Step**: Links the object module with RENT, REUS, REFR attributes

### 3. Execution JCL (jcl/RUNDUMP.jcl)

Executes DUMPPGM to generate the dump:

- Runs the program (which will ABEND)
- Captures dump to dataset via SYSUDUMP
- Includes alternative SYSABEND option for more detailed dumps
- Creates cataloged dump dataset for IPCS analysis

### 4. IPCS Analysis JCL (jcl/IPCSANAL.jcl)

Batch IPCS job demonstrating common analysis commands:

- SETDEF: Define dump dataset
- STATUS: Show dump status
- SUMMARY: Display dump summary
- REGS: Show register contents
- WHERE: Locate failure point
- LISTDUMP: List various dump components
- VERBX: Verbose display of registers and storage
- FIND: Search for specific strings in dump

## Usage Instructions

### Step 1: Prepare Source

1. Upload DUMPPGM.asm to your mainframe
2. Place in a PDS member (e.g., userid.SOURCE.ASM(DUMPPGM))

### Step 2: Build the Program

1. Edit BUILDDMP.jcl
2. Update dataset names to match your environment
3. Submit the job
4. Verify successful assembly and link (RC=0)

### Step 3: Generate the Dump

1. Edit RUNDUMP.jcl
2. Update dataset names
3. Submit the job
4. Job will ABEND U0013 (expected behavior)
5. Verify dump dataset was created

### Step 4: Analyze with IPCS

#### Option A: Batch Analysis

1. Edit IPCSANAL.jcl
2. Update dump dataset name
3. Submit the job
4. Review SYSTSPRT output

#### Option B: Interactive TSO IPCS

```
TSO IPCS
SETDEF DSNAME('userid.IPCS.DUMP') NOCONFIRM
STATUS
SUMMARY
REGS
WHERE
LISTDUMP PSW,REGS,SAVE,SPLS,TRACE
```

## IPCS Commands Reference

### Basic Commands

- **SETDEF**: Define dump dataset to analyze
- **STATUS**: Display dump status and characteristics
- **SUMMARY**: Show summary of dump contents
- **REGS**: Display register contents at time of failure
- **WHERE**: Show PSW and location of failure

### Analysis Commands

- **LISTDUMP**: List various dump components
  - PSW: Program Status Word
  - REGS: Registers
  - SAVE: Save areas
  - SPLS: Subpool list
  - TRACE: System trace

- **VERBX**: Verbose display using exits
  - REGS: Detailed register display
  - STORAGE: Storage display

- **FIND**: Search for strings or patterns
  - Syntax: FIND 'string' ASID(X'asid')

- **CBFORMAT**: Format control blocks
- **SYSTRACE**: Display system trace entries
- **LISTSYM**: List symbols in dump

### Advanced Commands

- **VERBEXIT LIST**: List available IPCS exits
- **SUMMARY FORMAT**: Formatted summary display
- **BROWSE**: Browse dump storage
- **NOTE**: Add notes to dump analysis
- **COPYDUMP**: Copy dump to another dataset

## Practice Exercises

### Exercise 1: Basic Navigation

1. Open the dump in IPCS
2. Display the summary
3. Find the PSW at time of failure
4. Locate the failing instruction

### Exercise 2: Register Analysis

1. Display all registers
2. Identify which register contains the base address
3. Find the return address in R14
4. Examine the save area chain

### Exercise 3: Storage Analysis

1. Find the 'DUMP' eye-catcher in storage
2. Locate the sample table entries
3. Find the control block chain
4. Search for the text strings in the buffer

### Exercise 4: Control Block Analysis

1. Format the control blocks
2. Follow the forward pointers
3. Verify the backward pointers
4. Examine the data fields

### Exercise 5: Problem Determination

1. Determine why the program ABENDed
2. Identify the ABEND code
3. Find the instruction that caused the ABEND
4. Trace back through the call chain

## Technical Details

### Program Characteristics

- **AMODE**: 31-bit addressing mode
- **RMODE**: Any (can reside above or below 16MB line)
- **Attributes**: RENT (reentrant), REUS (reusable), REFR (refreshable)
- **Base Registers**: R12 (primary), R11 (secondary for >4K)

### Dump Characteristics

- **Type**: SYSUDUMP (or SYSABEND)
- **Format**: VBS (Variable Blocked Spanned)
- **LRECL**: 4160
- **BLKSIZE**: 4164
- **Space**: 10 CYL primary, 5 CYL secondary

### ABEND Information

- **Code**: U0013 (user ABEND 13)
- **Reason**: Intentional for dump generation
- **Completion Code**: System completion code 0013

## Tips for IPCS Analysis

1. **Start with SUMMARY**: Get overview before diving into details
2. **Use Eye-catchers**: Search for known strings to locate structures
3. **Follow Chains**: Use pointers to navigate linked structures
4. **Check Registers**: R13 points to save area, R12 often base register
5. **Use VERBX**: More detailed than basic commands
6. **Save Your Work**: Use NOTE command to document findings
7. **Practice Regularly**: IPCS skills improve with practice

## Common Issues and Solutions

### Issue: Dump dataset not found

**Solution**: Verify dataset name in SETDEF command matches actual dump dataset

### Issue: IPCS commands fail

**Solution**: Ensure IPCS is properly installed and authorized

### Issue: Cannot find data structures

**Solution**: Use FIND command with eye-catchers, check ASID

### Issue: Storage display shows wrong data

**Solution**: Verify addressing mode and storage keys

## References

- IBM z/OS IPCS User's Guide
- IBM z/OS IPCS Commands
- IBM z/OS MVS Diagnosis: Tools and Service Aids
- IBM z/OS MVS System Codes

## Future Enhancements

Potential additions to this practice system:

1. Multiple ABEND scenarios (S0C1, S0C4, S0C7, etc.)
2. More complex data structures (queues, trees, hash tables)
3. Multi-threaded scenarios
4. Storage overlay scenarios
5. IPCS REXX exits for custom analysis
6. Automated analysis scripts
7. Comparison tools for before/after dumps

## Conclusion

This IPCS dump practice system provides a safe, controlled environment for learning and practicing dump analysis skills. The intentionally simple program creates recognizable patterns that are easy to find and analyze, making it ideal for training and skill development.
