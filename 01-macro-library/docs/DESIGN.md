# Design — Personal Macro Library

## Goal

A small, self-contained set of HLASM macros that make assembler source
read like structured code, plus two utilities (`@HEXOUT`, `@PCALL`). The
library is meant to be assembled into real programs and to read cleanly in
a code review, so the macros favour clarity of generated code over cleverness.

## Members

| Member   | Kind      | Role |
|----------|-----------|------|
| `@ENTER` | linkage   | Standard entry: save caller regs, set base, chain save area. |
| `@LEAVE` | linkage   | Standard exit: restore regs, set return code, return. |
| `@IF`    | structure | Begin conditional; test + branch-if-false. |
| `@ELSE`  | structure | Alternate path. |
| `@ENDIF` | structure | Close conditional. |
| `@DO`    | structure | Begin loop; optional top-tested `WHILE=`. |
| `@ENDDO` | structure | Close loop; optional bottom-tested `UNTIL=`. |
| `@HEXOUT`| utility   | Convert binary to printable EBCDIC hex. |
| `@PCALL` | utility   | Build a VL parameter list and call. |
| `@XINVB` | internal  | Helper: map a relation to its inverse branch. |

## Conditional-assembly mechanics

### Unique labels with `&SYSNDX`
Every structured construct needs private labels (skip-then targets, loop
top/bottom). `&SYSNDX` is the system macro-invocation counter — unique per
macro call — so a label like `#IZ&SYSNDX` (e.g. `#IZ00042`) can never
collide, even with nested or repeated constructs. Generated labels use the
`#` prefix (a valid HLASM ordinary-symbol start character) to stay clearly
distinct from user labels.

### Nesting with `GBLA` stacks
`@IF`/`@ELSE`/`@ENDIF` and `@DO`/`@ENDDO` span multiple macro calls, so
state is carried in global arrays:

- `&@IFLV` / `&@IFNX(64)` / `&@IFEL(64)` — IF nesting depth, the `&SYSNDX`
  captured at each open `@IF` (so the matching `@ELSE`/`@ENDIF` rebuild the
  same label), and an "else seen" flag per level.
- `&@DOLV` / `&@DONX(64)` — DO nesting depth and captured `&SYSNDX` per level.

`@ELSE`/`@ENDIF`/`@ENDDO` check the depth counter and issue `MNOTE 8` if
they are used without a matching opener, so an unbalanced construct fails
the assembly with a clear message instead of producing wrong code.

### Inverse-branch helper (`@XINVB`)
`@IF (C,R5,=F'0'),EQ` means "execute the THEN part when R5 = 0", so the
generated branch must skip the THEN part when the relation is **false**.
`@XINVB` maps each relation to the branch mnemonic that fires when the
relation is false:

| Relation | Branch-if-false |
|----------|-----------------|
| EQ       | BNE |
| NE       | BE  |
| GT / H   | BNH |
| LT / L   | BNL |
| GE / NL  | BL  |
| LE / NH  | BH  |

These extended mnemonics test only the condition code, so they work after
either signed (`C`,`CR`) or logical (`CL`,`CLR`,`CLI`,`CLC`) compares — the
caller chooses the compare mnemonic, which decides signed vs unsigned.
A bad relation produces `MNOTE 8`.

## Linkage design (`@ENTER` / `@LEAVE`)

- `@ENTER` is issued immediately after the `CSECT`/`AMODE`/`RMODE`
  statements so the entry address in R15 maps the control section. It uses
  `&SYSECT` for the `USING` so the macro never hardcodes the program name.
- Save-area chaining is the standard forward/backward chain. The save area
  is defined inline (18 fullwords) and jumped over with a relative `J`.
- `@LEAVE` restores R14 and R0–R12 but deliberately **does not** reload
  R15 from the save area, so a return code set with `RC=` survives the
  restore. `RC=` accepts a literal (`RC=0`) or a register (`RC=(R3)`).

These programs are non-reentrant (static save area, writable WTO list
form). That is a conscious simplification for a demonstration; the DESIGN
note exists so a reviewer knows it was a choice, not an oversight. A
reentrant variant would `GETMAIN` the save/work areas.

## `@HEXOUT` — the UNPK + TR technique

Converting N bytes to 2N EBCDIC hex characters:

1. `UNPK` of an (L+1)-byte source into a (2L+1)-byte target spreads each
   source nibble into its own byte with an `X'F'` zone — except the final
   source byte, whose nibbles are swapped (the sign-nibble rule). By
   feeding L data bytes plus one throwaway byte, the first 2L target bytes
   land as `X'F0'`–`X'FF'`, one per nibble, in order.
2. `TR` against a 256-byte table whose entries `X'F0'`–`X'FF'` hold
   `C'0'`–`C'F'` converts those to printable hex in place.

A single `UNPK` operand is limited to 16 bytes, which caps one pass at 7
data bytes (2·7+1 = 15). So `@HEXOUT` uses **macro-time chunking**: an
`AIF`/`AGO` loop emits one `UNPK`/`TR`/`MVC` group per ≤7-byte chunk,
supporting `LEN=1..16` while keeping the work areas tiny (`CL8` in, `CL15`
out). The throwaway byte is supplied from a private work area (`MVI ...
X'00'`) so the macro never reads past the caller's `SRC`.

`@HEXOUT MODE=DEFINE` emits the shared translate table and work areas once
(guarded by `&@HEXD` so a second `MODE=DEFINE` is `MNOTE 8`); place it in
the program's data area. `SRC`/`DST` must be plain relocatable labels (the
macro appends `+offset`), not base-displacement operands.

## `@PCALL` — parameter list + call

Builds a standard VL parameter list as inline constants (jumped over with
`J`), each `A(parm)` with the high-order bit set on the last entry
(`X'80',AL3(...)`), loads R1 to point at it, loads R15 (`=V(ep)` for an
external, `LA` for `TYPE=INTERNAL`), and `BALR 14,15`. With no `PARMS=` it
zeroes R1. Parameters are relocatable labels.

## Edge cases / what could go wrong

- **Unbalanced constructs** — caught at open/close by depth checks
  (`MNOTE 8`). A missing `@ENDIF` at end-of-assembly is not auto-detected;
  it surfaces as an undefined `#IE/#IZ` symbol.
- **Base register range** — `@ENTER` establishes a single base; programs
  over 4K need additional `USING`s. Documented, not enforced.
- **`@HEXOUT` operands** — must be labels; `LEN` outside 1..16 is `MNOTE 8`.
- **Register collisions** — generated linkage code uses absolute register
  numbers (12–15, 0) so it does not depend on the caller defining `Rn`
  equates; structured-construct compares use whatever the caller writes.
- **Reentrancy** — see linkage note above; current macros are simple/
  non-reentrant by design.

## On-system build

See `../jcl/BUILDEX.jcl`. Upload the `.mac` members into a macro PDS
(e.g. `ANDRE.EPE.MACLIB`) as members without extensions, concatenate it
ahead of `SYS1.MACLIB` on the assembler `SYSLIB` DD, and assemble the
example in `examples/`.
