# Ansible Automation for z/OS Assembler Compilation

Automated compilation of mainframe assembler programs using Ansible and z/OSMF REST APIs.

## Overview

This project demonstrates how to automate z/OS assembler program compilation using Ansible playbooks. It eliminates manual JCL submission by integrating with z/OSMF REST APIs, enabling CI/CD pipelines for mainframe development.

## Features

- ✅ **Automated JCL Submission**: Submit compilation jobs via Ansible
- ✅ **CLIST Integration**: Leverages existing COMPILE CLIST for assembly and link-edit
- ✅ **Job Monitoring**: Waits for job completion and reports results
- ✅ **Error Handling**: Captures and displays job output for debugging
- ✅ **Cross-Platform**: Runs from Windows via WSL or native Linux

## Quick Start

### 1. Set Password

```bash
export ZOS_PASSWORD='your_password'
```

### 2. Run Compilation

```bash
cd scripts
bash compile-asm.sh
```

### 3. Check Results

```bash
cat ../workflows/last_compile_info.txt
```

## Files

- **jcl/COMPASM.jcl**: JCL that invokes COMPILE CLIST
- **playbooks/compile_assembler.yml**: Ansible playbook for automation
- **scripts/compile-asm.sh**: Helper script for easy execution
- **scripts/sync-and-run.sh**: Syncs files from Windows to WSL

## How It Works

1. **Sync Files**: Copies latest JCL and playbooks to WSL
2. **Read JCL**: Ansible reads COMPASM.jcl content
3. **Submit Job**: Sends JCL to z/OSMF REST API
4. **Execute**: z/OS runs job, invoking COMPILE CLIST
5. **Monitor**: Ansible polls job status every 2 seconds
6. **Report**: Displays job ID, return code, and output
7. **Save**: Writes summary to workflows/last_compile_info.txt

## Documentation

- [QUICKSTART.md](QUICKSTART.md) - Get started in 5 minutes
- [docs/DESIGN.md](docs/DESIGN.md) - Technical architecture and design

## Successfully Tested

✅ Compiled MYPROG via Ansible automation
✅ Job submitted and monitored automatically  
✅ Return code CC 0000 (success)
✅ Load module created in ANDRE.EPE.LOAD

## Benefits

- **Speed**: Automated compilation in seconds
- **Consistency**: Same process every time
- **Integration**: Works with modern DevOps tools
- **Auditability**: All actions logged

---

_Demonstrating modern DevOps practices on the mainframe_
