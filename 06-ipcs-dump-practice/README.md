# IPCS Dump Practice System

A complete system for generating and analyzing mainframe system dumps using IPCS (Interactive Problem Control System).

## Overview

This project provides a hands-on learning environment for practicing IPCS dump analysis. It includes:

- **DUMPPGM**: Assembly program that creates interesting data structures and forces a dump
- **Build JCL**: Assembles and links the program
- **Execution JCL**: Runs the program to generate a dump
- **Analysis JCL**: Demonstrates batch IPCS commands

## Quick Start

### 1. Build the Program

```jcl
// Submit jcl/BUILDDMP.jcl
// Update dataset names to match your environment
```

### 2. Generate a Dump

```jcl
// Submit jcl/RUNDUMP.jcl
// Program will ABEND U0013 (expected)
// Dump saved to userid.IPCS.DUMP
```

### 3. Analyze the Dump

**Option A - Batch:**

```jcl
// Submit jcl/IPCSANAL.jcl
```

**Option B - Interactive TSO:**

```
TSO IPCS
SETDEF DSNAME('userid.IPCS.DUMP') NOCONFIRM
SUMMARY
REGS
WHERE
LISTDUMP PSW,REGS,SAVE
```

## What's in the Dump?

The program creates several data structures for practice:

### 1. Header Structure

- Eye-catcher: **'DUMP'**
- Version, program name, timestamp

### 2. Sample Table

- 10 entries with sequential data
- Eye-catcher: **'ENTRY'** + number

### 3. Control Block Chain

- 3 linked control blocks
- Eye-catchers: **'CTL1'**, **'CTL2'**, **'CTL3'**
- Forward and backward pointers

### 4. Data Buffer

- 256 bytes with pattern fill
- Text strings: **"This is sample data for IPCS dump analysis practice"**
- Search string: **"Look for this string in the dump file!"**

## Practice Exercises

### Beginner Level

1. **Find the Eye-catchers**

   ```
   FIND 'DUMP' ASID(X'0001')
   FIND 'CTL1' ASID(X'0001')
   ```

2. **Display Registers**

   ```
   REGS
   VERBX REGS
   ```

3. **Show Failure Location**
   ```
   WHERE
   LISTDUMP PSW
   ```

### Intermediate Level

4. **Trace the Save Area Chain**

   ```
   LISTDUMP SAVE
   ```

5. **Find Text Strings**

   ```
   FIND 'This is sample data' ASID(X'0001')
   ```

6. **Examine Control Blocks**
   ```
   CBFORMAT
   ```

### Advanced Level

7. **Analyze Storage Patterns**

   ```
   VERBX STORAGE
   ```

8. **Follow Pointer Chains**
   - Locate CTL1
   - Follow forward pointer to CTL2
   - Follow forward pointer to CTL3
   - Verify backward pointers

9. **Reconstruct Program Flow**
   - Find PSW at failure
   - Trace back through save areas
   - Identify calling sequence

## Files

```
06-ipcs-dump-practice/
├── README.md              # This file
├── src/
│   └── DUMPPGM.asm       # Assembly source program
├── jcl/
│   ├── BUILDDMP.jcl      # Build JCL
│   ├── RUNDUMP.jcl       # Execution JCL
│   └── IPCSANAL.jcl      # IPCS analysis JCL
└── docs/
    └── DESIGN.md         # Detailed design documentation
```

## Key IPCS Commands

| Command    | Purpose               |
| ---------- | --------------------- |
| `SETDEF`   | Define dump dataset   |
| `STATUS`   | Show dump status      |
| `SUMMARY`  | Display dump summary  |
| `REGS`     | Show registers        |
| `WHERE`    | Show failure location |
| `LISTDUMP` | List dump components  |
| `VERBX`    | Verbose display       |
| `FIND`     | Search for strings    |
| `CBFORMAT` | Format control blocks |

## Expected Results

When you run RUNDUMP.jcl:

- Job will complete with **ABEND U0013** (this is intentional)
- Dump dataset will be created and cataloged
- WTO messages will appear in SYSOUT:
  - "DUMPPGM: Starting dump generation program"
  - "DUMPPGM: Data structures created, forcing dump..."

## Tips

1. **Start Simple**: Begin with SUMMARY and REGS commands
2. **Use Eye-catchers**: Search for known strings to locate structures
3. **Follow Chains**: Use pointers to navigate linked data
4. **Practice Regularly**: IPCS skills improve with hands-on practice
5. **Document Findings**: Use NOTE command to save your analysis

## Troubleshooting

### Dump dataset not found

- Verify dataset name in SETDEF matches actual dump
- Check if RUNDUMP.jcl completed successfully

### IPCS commands fail

- Ensure IPCS is installed and authorized
- Check TSO/ISPF environment

### Cannot find data structures

- Use FIND command with eye-catchers
- Verify correct ASID (usually X'0001')

## Learning Resources

- See `docs/DESIGN.md` for detailed technical information
- IBM z/OS IPCS User's Guide
- IBM z/OS IPCS Commands Reference
- IBM z/OS MVS Diagnosis: Tools and Service Aids

## Why Practice with IPCS?

IPCS is a critical tool for:

- **Problem Determination**: Analyzing system failures
- **Performance Analysis**: Understanding system behavior
- **Debugging**: Finding root causes of ABENDs
- **System Programming**: Essential skill for z/OS professionals

This practice system provides a safe, controlled environment to develop these skills without risk to production systems.

## Next Steps

After mastering this basic dump:

1. Try different ABEND codes (S0C1, S0C4, S0C7)
2. Create more complex data structures
3. Practice with multi-threaded scenarios
4. Develop custom IPCS REXX exits
5. Analyze real production dumps (with proper authorization)

## Contributing

This is a learning tool. Feel free to:

- Add more data structures to DUMPPGM
- Create additional practice exercises
- Develop automated analysis scripts
- Share your IPCS tips and techniques

## License

Educational use. Part of the mainframe-portfolio project.

---

**Happy Dump Analyzing!** 🔍💾
