#!/bin/bash
# Quick fix for ansible.cfg callback plugin issue

echo "Fixing ansible.cfg..."

# Backup original
cp ~/andre/ansible.cfg ~/andre/ansible.cfg.backup

# Fix the callback plugin configuration
sed -i 's/^stdout_callback = yaml$/stdout_callback = default\nresult_format = yaml/' ~/andre/ansible.cfg

echo "Fixed! Testing..."
cat ~/andre/ansible.cfg | grep -A1 "stdout_callback"

echo ""
echo "Done! Now try: ansible zos_sandbox -m ping"

# Made with Bob
