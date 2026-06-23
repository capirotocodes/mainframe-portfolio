# Quick Start - Ansible Automation

Get your first assembler program compiled via Ansible in under 5 minutes.

## Step 1: Install Ansible

```bash
wsl
pip3 install ansible
export PATH="$HOME/.local/bin:$PATH"
```

## Step 2: Set Password

```bash
export ZOS_PASSWORD='your_password'
```

## Step 3: Run Compilation

```bash
cd /mnt/c/Users/YOUR_USERNAME/Documents/Zowe/mainframe-portfolio/z/andre
bash compile-asm.sh
```

## Success!

You'll see:

```
=== Compilation Complete ===
Job ID: JOB12345
Return Code: CC 0000
```

Your program is now in `ANDRE.EPE.LOAD(MYPROG)`!

## Next Steps

- View listings: `zowe files view data-set "ANDRE.EPE.LISTCASM(MYPROG)"`
- Check jobs: `zowe jobs list jobs --owner ANDRE`
- Compile another: Edit `jcl/COMPASM.jcl` and change member name

---

_Happy automating! 🚀_
