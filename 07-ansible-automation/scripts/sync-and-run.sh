#!/bin/bash
# Sync files from Windows to WSL and prepare for compilation

echo "=== Syncing files from Windows to WSL ==="

# Create directories if they don't exist
mkdir -p ~/andre/playbooks
mkdir -p ~/andre/group_vars
mkdir -p ~/andre/workflows
mkdir -p ~/andre/inventory

# Sync all files
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/playbooks/*.yml ~/andre/playbooks/
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/group_vars/*.yml ~/andre/group_vars/
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/*.jcl ~/andre/ 2>/dev/null || true
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/inventory/*.yml ~/andre/inventory/ 2>/dev/null || true
cp -v /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/ansible.cfg ~/andre/ 2>/dev/null || true

echo ""
echo "=== Files synced successfully ==="
ls -la ~/andre/playbooks/

echo ""
echo "=== Checking password ==="
if [ -z "$ZOS_PASSWORD" ]; then
    echo "ERROR: ZOS_PASSWORD not set!"
    echo "Run: export ZOS_PASSWORD='your_password'"
    exit 1
else
    echo "Password is set: ${ZOS_PASSWORD:0:4}****"
fi

echo ""
echo "=== Ready to run playbooks ==="
echo "Available playbooks:"
ls ~/andre/playbooks/*.yml

# Made with Bob
