# Troubleshooting: Inventory Not Found

## Problem

```
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available
[WARNING]: Could not match supplied host pattern, ignoring: zos_sandbox
```

## Solution

### Option 1: Specify Inventory Explicitly (Quick Fix)

```bash
# Use -i flag to specify inventory
ansible zos_sandbox -i inventory/hosts.yml -m ping

# For playbooks
ansible-playbook -i inventory/hosts.yml playbooks/deploy_workflow.yml
```

### Option 2: Ensure You're in the Right Directory

```bash
# Check current directory
pwd

# Should show: /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre
# Or: ~/andre (if you created symlink)

# If not, navigate there
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre

# Verify files exist
ls -la inventory/hosts.yml
ls -la ansible.cfg
```

### Option 3: Fix ansible.cfg Path

The `ansible.cfg` file should be in your current directory. Verify:

```bash
# Check if ansible.cfg exists
cat ansible.cfg | grep inventory

# Should show: inventory = ./inventory/hosts.yml
```

### Option 4: Use Absolute Path in ansible.cfg

Edit `ansible.cfg` and change inventory path to absolute:

```bash
nano ansible.cfg
```

Change this line:

```ini
inventory = ./inventory/hosts.yml
```

To (use your actual path):

```ini
inventory = /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/inventory/hosts.yml
```

### Option 5: Set ANSIBLE_INVENTORY Environment Variable

```bash
# Set inventory location
export ANSIBLE_INVENTORY=/mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/inventory/hosts.yml

# Add to ~/.bashrc for persistence
echo "export ANSIBLE_INVENTORY=/mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/inventory/hosts.yml" >> ~/.bashrc

# Test
ansible zos_sandbox -m ping
```

## Verification Steps

### Step 1: Verify Directory Structure

```bash
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre
tree -L 2
# Or
find . -type f -name "*.yml"
```

Expected output:

```
./ansible.cfg
./inventory/hosts.yml
./group_vars/zos_systems.yml
./playbooks/deploy_workflow.yml
./playbooks/manage_workflows.yml
```

### Step 2: Test Inventory File

```bash
# List all hosts in inventory
ansible-inventory -i inventory/hosts.yml --list

# Should show your zos_sandbox host
```

### Step 3: Verify ansible.cfg is Being Used

```bash
# Check which config file Ansible is using
ansible --version

# Look for "config file" line
# Should show: config file = /path/to/z/andre/ansible.cfg
```

### Step 4: Test with Explicit Inventory

```bash
# This should work regardless of ansible.cfg
ansible -i inventory/hosts.yml zos_sandbox -m ping
```

## Common Issues and Fixes

### Issue: "ansible.cfg not found"

**Solution:** Ensure you're in the z/andre directory

```bash
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre
```

### Issue: "hosts.yml has wrong format"

**Solution:** Verify YAML syntax

```bash
# Check for syntax errors
ansible-inventory -i inventory/hosts.yml --list --yaml
```

### Issue: "Permission denied on Windows files"

**Solution:** Copy to WSL filesystem

```bash
# Copy entire directory to WSL home
cp -r /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre
cd ~/andre

# Update ansible.cfg inventory path
nano ansible.cfg
# Change to: inventory = ./inventory/hosts.yml
```

### Issue: "CRLF line endings"

**Solution:** Convert to Unix line endings

```bash
# Install dos2unix
sudo apt install dos2unix

# Convert files
dos2unix ansible.cfg
dos2unix inventory/hosts.yml
dos2unix group_vars/zos_systems.yml
```

## Recommended Setup

### Create a Setup Script

Create `z/andre/setup.sh`:

```bash
#!/bin/bash
# Setup script for Ansible environment

# Set working directory
export ANSIBLE_DIR="/mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre"
cd "$ANSIBLE_DIR"

# Set inventory
export ANSIBLE_INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"

# Set password (replace with your password)
export ZOS_PASSWORD='your_password'

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"

echo "Ansible environment configured!"
echo "Current directory: $(pwd)"
echo "Inventory: $ANSIBLE_INVENTORY"
echo ""
echo "Test connection with: ansible zos_sandbox -m ping"
```

Make it executable and run:

```bash
chmod +x setup.sh
source setup.sh
```

Add to ~/.bashrc for automatic setup:

```bash
echo "source /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/setup.sh" >> ~/.bashrc
```

## Quick Test Commands

```bash
# 1. Check Ansible can find config
ansible --version

# 2. List inventory
ansible-inventory --list

# 3. Test with explicit inventory
ansible -i inventory/hosts.yml zos_sandbox -m ping

# 4. Test from correct directory
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre
ansible zos_sandbox -m ping

# 5. Test with full path
ansible -i /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/inventory/hosts.yml zos_sandbox -m ping
```

## Working Command Examples

Once fixed, these should work:

```bash
# From z/andre directory
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre

# Test connection
ansible zos_sandbox -m ping

# List workflows
ansible-playbook playbooks/manage_workflows.yml -e "workflow_operation=list"

# Deploy workflow
ansible-playbook playbooks/deploy_workflow.yml

# With verbose output
ansible-playbook playbooks/deploy_workflow.yml -vvv
```

## Still Not Working?

Run this diagnostic:

```bash
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre
echo "=== Ansible Version ==="
ansible --version
echo ""
echo "=== Current Directory ==="
pwd
echo ""
echo "=== Files Present ==="
ls -la ansible.cfg inventory/hosts.yml
echo ""
echo "=== Inventory Content ==="
cat inventory/hosts.yml
echo ""
echo "=== Test Inventory Parse ==="
ansible-inventory -i inventory/hosts.yml --list
```

Share the output for further troubleshooting.
