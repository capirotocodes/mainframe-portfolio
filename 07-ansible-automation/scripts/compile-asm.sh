#!/bin/bash
# Compile assembler program using Ansible and CLIST

echo "=== Assembler Compilation via Ansible ==="
echo ""

# Check if password is set
if [ -z "$ZOS_PASSWORD" ]; then
    echo "ERROR: ZOS_PASSWORD not set!"
    echo "Run: export ZOS_PASSWORD='your_password'"
    exit 1
fi

# Sync files from Windows to WSL first
echo "=== Syncing files from Windows to WSL ==="
mkdir -p ~/andre/playbooks
mkdir -p ~/andre/group_vars
mkdir -p ~/andre/workflows
mkdir -p ~/andre/inventory

cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/playbooks/*.yml ~/andre/playbooks/
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/group_vars/*.yml ~/andre/group_vars/ 2>/dev/null || true
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/*.jcl ~/andre/ 2>/dev/null || true
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/inventory/*.yml ~/andre/inventory/ 2>/dev/null || true
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/ansible.cfg ~/andre/ 2>/dev/null || true

echo ""
echo "=== Files synced ==="
echo "Working directory: ~/andre"
echo "Member to compile: ${1:-MYPROG}"
echo ""

# Navigate to project directory
cd ~/andre

# Verify playbook exists
if [ ! -f "playbooks/compile_assembler.yml" ]; then
    echo "ERROR: playbooks/compile_assembler.yml not found!"
    echo "Contents of ~/andre/playbooks:"
    ls -la ~/andre/playbooks/
    exit 1
fi

# Run the compilation playbook
echo "=== Running Ansible playbook ==="
ansible-playbook playbooks/compile_assembler.yml

echo ""
echo "=== Compilation Complete ==="
echo "Check workflows/last_compile_info.txt for details"

# Made with Bob