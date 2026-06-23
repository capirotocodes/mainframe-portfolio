# IPCS Commands Quick Reference

A comprehensive guide to IPCS commands for dump analysis.

## Table of Contents

1. [Setup Commands](#setup-commands)
2. [Display Commands](#display-commands)
3. [Search Commands](#search-commands)
4. [Analysis Commands](#analysis-commands)
5. [Navigation Commands](#navigation-commands)
6. [Advanced Commands](#advanced-commands)
7. [Command Examples](#command-examples)

## Setup Commands

### SETDEF - Define Dump Dataset

Define the dump dataset to be analyzed.

```
SETDEF DSNAME('userid.IPCS.DUMP') NOCONFIRM
```

**Parameters:**

- `DSNAME('dataset.name')` - Dump dataset name
- `NOCONFIRM` - Skip confirmation prompts
- `CONFIRM` - Prompt for confirmation (default)

**Example:**

```
SETDEF DSNAME('SYS1.DUMP.D062618') NOCONFIRM
```

### DROPDUMP - Release Dump Dataset

Release the current dump dataset.

```
DROPDUMP
```

## Display Commands

### STATUS - Display Dump Status

Show information about the current dump.

```
STATUS
```

**Output includes:**

- Dump dataset name
- Dump date and time
- System information
- ASID information
- Dump type

### SUMMARY - Dump Summary

Display a summary of dump contents.

```
SUMMARY
SUMMARY FORMAT
```

**Parameters:**

- `FORMAT` - Formatted output with more details

### REGS - Display Registers

Show register contents at time of failure.

```
REGS
REGS ALL
REGS GENERAL
REGS FLOAT
REGS ACCESS
```

**Parameters:**

- `ALL` - All register types
- `GENERAL` - General purpose registers (R0-R15)
- `FLOAT` - Floating point registers
- `ACCESS` - Access registers

### WHERE - Show Failure Location

Display PSW and location of failure.

```
WHERE
```

**Output includes:**

- PSW (Program Status Word)
- Instruction address
- Module name
- Offset within module

### LISTDUMP - List Dump Components

Display various components of the dump.

```
LISTDUMP PSW
LISTDUMP REGS
LISTDUMP SAVE
LISTDUMP SPLS
LISTDUMP TRACE
LISTDUMP PSW,REGS,SAVE
```

**Parameters:**

- `PSW` - Program Status Word
- `REGS` - Registers
- `SAVE` - Save areas
- `SPLS` - Subpool list
- `TRACE` - System trace
- `ALL` - All components

## Search Commands

### FIND - Search for Data

Search for strings or hex patterns in dump.

```
FIND 'string' ASID(X'asid')
FIND X'hexdata' ASID(X'asid')
FIND 'string' ASID(X'asid') NEXT
```

**Parameters:**

- `'string'` - Character string to find
- `X'hexdata'` - Hexadecimal data to find
- `ASID(X'asid')` - Address space ID (usually X'0001')
- `NEXT` - Find next occurrence

**Examples:**

```
FIND 'DUMP' ASID(X'0001')
FIND X'C4E4D4D7' ASID(X'0001')
FIND 'ERROR' ASID(X'0001') NEXT
```

### FINDSYM - Find Symbol

Search for a symbol in the dump.

```
FINDSYM symbolname
```

## Analysis Commands

### VERBX - Verbose Display

Display detailed information using IPCS exits.

```
VERBX REGS
VERBX STORAGE
VERBX REGS,STORAGE
```

**Parameters:**

- `REGS` - Detailed register display
- `STORAGE` - Storage display with formatting
- Multiple parameters can be combined

### CBFORMAT - Format Control Blocks

Format and display control blocks.

```
CBFORMAT
CBFORMAT TCB
CBFORMAT ASCB
CBFORMAT CVT
```

**Parameters:**

- No parameter - Format common control blocks
- `TCB` - Task Control Block
- `ASCB` - Address Space Control Block
- `CVT` - Communication Vector Table
- Many other control block types

### SYSTRACE - Display System Trace

Show system trace entries.

```
SYSTRACE
SYSTRACE ASID(X'0001')
SYSTRACE COMP(component)
```

**Parameters:**

- `ASID(X'asid')` - Filter by address space
- `COMP(component)` - Filter by component

### VERBEXIT - Verbose Exit Processing

Execute verbose exits for detailed analysis.

```
VERBEXIT LIST
VERBEXIT exitname
```

**Parameters:**

- `LIST` - List available exits
- `exitname` - Execute specific exit

## Navigation Commands

### BROWSE - Browse Storage

Browse dump storage interactively.

```
BROWSE address
BROWSE address LENGTH(length)
BROWSE address ASID(X'asid')
```

**Parameters:**

- `address` - Starting address (hex)
- `LENGTH(length)` - Number of bytes to display
- `ASID(X'asid')` - Address space ID

**Examples:**

```
BROWSE 80000000
BROWSE 80000000 LENGTH(256)
BROWSE 80000000 ASID(X'0001')
```

### LISTSYM - List Symbols

List symbols in the dump.

```
LISTSYM
LISTSYM MATCH(pattern)
```

**Parameters:**

- `MATCH(pattern)` - Filter symbols by pattern

### NOTE - Add Notes

Add notes to dump analysis.

```
NOTE 'text'
NOTE LIST
NOTE DELETE(number)
```

**Parameters:**

- `'text'` - Note text to add
- `LIST` - List all notes
- `DELETE(number)` - Delete note by number

## Advanced Commands

### COPYDUMP - Copy Dump

Copy dump to another dataset.

```
COPYDUMP DSNAME('target.dataset')
```

### EQUATE - Define Symbol

Define a symbol for an address.

```
EQUATE symbolname address
```

**Example:**

```
EQUATE MYDATA 80001000
```

### RUNCHAIN - Follow Chain

Follow a chain of control blocks.

```
RUNCHAIN address OFFSET(offset) LENGTH(length)
```

**Parameters:**

- `address` - Starting address
- `OFFSET(offset)` - Offset to next pointer
- `LENGTH(length)` - Length of each block

### ANALYZE - Automated Analysis

Perform automated analysis.

```
ANALYZE
ANALYZE WAIT
ANALYZE LOOP
```

**Parameters:**

- `WAIT` - Analyze wait state
- `LOOP` - Analyze loop condition

## Command Examples

### Basic Analysis Session

```
IPCS
SETDEF DSNAME('userid.IPCS.DUMP') NOCONFIRM
STATUS
SUMMARY
REGS
WHERE
LISTDUMP PSW,REGS,SAVE
END
```

### Finding Data Structures

```
FIND 'DUMP' ASID(X'0001')
FIND 'CTL1' ASID(X'0001')
FIND 'This is sample data' ASID(X'0001')
```

### Detailed Register Analysis

```
REGS ALL
VERBX REGS
```

### Control Block Analysis

```
CBFORMAT
CBFORMAT TCB
CBFORMAT ASCB
```

### Storage Examination

```
BROWSE 80000000 LENGTH(256)
VERBX STORAGE
```

### Save Area Chain

```
LISTDUMP SAVE
RUNCHAIN savearea OFFSET(8) LENGTH(72)
```

### System Trace

```
SYSTRACE
SYSTRACE ASID(X'0001')
```

### Search and Navigate

```
FIND 'ERROR' ASID(X'0001')
BROWSE <address_from_find>
FIND 'ERROR' ASID(X'0001') NEXT
```

## Tips and Best Practices

### 1. Start with Overview

Always begin with:

```
STATUS
SUMMARY
WHERE
```

### 2. Use Eye-catchers

Search for known strings:

```
FIND 'eyecatcher' ASID(X'0001')
```

### 3. Follow Chains

Use RUNCHAIN for linked structures:

```
RUNCHAIN address OFFSET(4) LENGTH(16)
```

### 4. Save Your Work

Document findings:

```
NOTE 'Found error at address 80001234'
NOTE LIST
```

### 5. Use Verbose Exits

Get more detail:

```
VERBX REGS,STORAGE
```

### 6. Check Multiple ASIDs

If needed:

```
STATUS ASID(ALL)
FIND 'string' ASID(X'0002')
```

## Common Scenarios

### Scenario 1: S0C4 ABEND

```
WHERE                    # Find failure location
REGS                     # Check registers
LISTDUMP PSW,REGS       # Get details
BROWSE <failing_address> # Examine storage
```

### Scenario 2: Loop Analysis

```
ANALYZE LOOP            # Automated loop detection
SYSTRACE                # Check trace
LISTDUMP SAVE           # Examine save areas
```

### Scenario 3: Wait State

```
ANALYZE WAIT            # Automated wait analysis
CBFORMAT TCB            # Check task status
SYSTRACE                # System activity
```

### Scenario 4: Storage Overlay

```
FIND 'eyecatcher'       # Locate structure
BROWSE <address>        # Examine contents
VERBX STORAGE           # Detailed view
```

## Exit Codes

Common IPCS exit codes:

- **0** - Successful completion
- **4** - Warning
- **8** - Error
- **12** - Severe error
- **16** - Terminal error

## Additional Resources

- IBM z/OS IPCS User's Guide
- IBM z/OS IPCS Commands
- IBM z/OS IPCS Customization
- IBM z/OS MVS Diagnosis: Tools and Service Aids

## Quick Reference Card

| Task           | Command                         |
| -------------- | ------------------------------- |
| Open dump      | `SETDEF DSNAME('dump.dataset')` |
| Show status    | `STATUS`                        |
| Show summary   | `SUMMARY`                       |
| Show registers | `REGS`                          |
| Find failure   | `WHERE`                         |
| Search string  | `FIND 'string' ASID(X'0001')`   |
| Browse storage | `BROWSE address`                |
| Format blocks  | `CBFORMAT`                      |
| Show trace     | `SYSTRACE`                      |
| Add note       | `NOTE 'text'`                   |
| Close dump     | `DROPDUMP`                      |
| Exit IPCS      | `END`                           |

---

**Remember**: Practice makes perfect! Use this reference while analyzing the DUMPPGM dump.
