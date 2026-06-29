# 06 — IPCS Dump Practice (DUMPPGM)

A batch HLASM program that builds a set of clearly-labelled storage
structures and then forces a dump, giving you a known, controlled dump to
analyse with **IPCS** (Interactive Problem Control System). Pairs with the
author's debugging strength: the eye-catchers and pointer chains are placed
so each IPCS command has an obvious thing to find.

## Purpose

Provide a safe, repeatable target for practising dump analysis — locating
data by eye-catcher, walking pointer chains, and reading the failing PSW
and registers — without needing a real production dump.

## What the program builds, then dumps

`DUMPPGM` lays out, in a GETMAINed work area, structures designed to be
recognisable in a dump:

| Structure | Eye-catcher(s) | What to practise |
|-----------|----------------|------------------|
| Header | `DUMP` | version, program name, packed `TIME` stamp |
| Sample table | `ENTRY0`…`ENTRY9` (10 entries) | scanning repeated fixed-length entries |
| Control-block chain | `CTL1` → `CTL2` → `CTL3` | following forward/back pointers |
| Data buffer (256B) | pattern fill + text strings | `FIND` on a known string |

It then issues `ABEND 13,DUMP` — a **U0013** abend that produces the dump.

## Files

| File | What it is |
|------|------------|
| `src/DUMPPGM.asm` | The program — `AMODE 31 / RMODE ANY`, GETMAIN work area. |
| `jcl/BUILDDMP.jcl` | Assemble + link-edit into a load library. |
| `jcl/RUNDUMP.jcl` | Run the program; it abends U0013 and writes the dump. |
| `jcl/IPCSANAL.jcl` | Batch IPCS commands against the captured dump. |
| `docs/IPCS-COMMANDS.md` | IPCS command reference for the exercises. |
| `docs/DESIGN.md` | Structure layouts and analysis notes. |

(Several `BUILDDMP-*.jcl` variants are kept for different site setups.)

## How to use it

1. **Build** — submit `jcl/BUILDDMP.jcl` (retarget the dataset names).
2. **Generate the dump** — submit `jcl/RUNDUMP.jcl`. The step abends
   **U0013** by design and the dump is captured (to `SYSUDUMP`/`SYSABEND`,
   or a dump dataset for IPCS).
3. **Analyse** — either submit `jcl/IPCSANAL.jcl` for a batch IPCS run, or
   work interactively under `TSO IPCS`:

   ```
   SETDEF DSNAME('userid.IPCS.DUMP') NOCONFIRM
   SUMMARY ; REGS ; WHERE
   FIND 'DUMP'  ASID(X'0001')      locate the header
   FIND 'CTL1'  ASID(X'0001')      then walk CTL1 -> CTL2 -> CTL3
   LISTDUMP PSW,REGS,SAVE          failure point + save-area chain
   ```

## Skills demonstrated

- Reading dumps with IPCS: `SETDEF`, `SUMMARY`, `REGS`, `WHERE`,
  `LISTDUMP`, `FIND`, `CBFORMAT`, `VERBX`.
- Locating data structures by eye-catcher and walking pointer chains.
- Producing a controlled abend (`ABEND ...,DUMP`) for problem-determination
  practice.

**Status: built and verified on a real z/OS system** — `BUILDDMP.jcl`
assembles and links clean (CC 0000) and `RUNDUMP.jcl` abends **U0013** as
designed, capturing the dump to `ANDRE.IPCS.ABEND`. (The program was made
assemble-clean in the process: it had been missing its `R0`–`R15` register
equates and used a fragile inline literal continuation; both are fixed.)
