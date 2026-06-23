# Fix: World Writable Directory Issue in WSL

## The Problem

```
[WARNING]: Ansible is being run in a world writable directory (/mnt/c/...),
ignoring it as an ansible.cfg source.
```

**Root Cause:** Windows filesystem mounted in WSL (`/mnt/c`) has permissive permissions that Ansible considers unsafe.

## Solution: Copy to WSL Filesystem

The best solution is to copy your project to the WSL native filesystem where you can control permissions.

### Step-by-Step Fix

#### 1. Copy Project to WSL Home Directory

```bash
# Copy the entire project to WSL filesystem
cp -r /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre

# Navigate to the new location
cd ~/andre
```

#### 2. Verify Permissions

```bash
# Check permissions (should NOT be world writable)
ls -la ~/andre

# Should show something like: drwxr-xr-x (not drwxrwxrwx)
```

#### 3. Test Ansible Configuration

```bash
# Ansible should now read ansible.cfg
ansible --version

# Look for: config file = /home/yourusername/andre/ansible.cfg
```

#### 4. Test Connection

```bash
cd ~/andre
ansible zos_sandbox -m ping
```

## Alternative Solutions

### Option A: Use Explicit Inventory (Quick Workaround)

```bash
# Always specify inventory explicitly
ansible -i ~/andre/inventory/hosts.yml zos_sandbox -m ping

# For playbooks
ansible-playbook -i ~/andre/inventory/hosts.yml playbooks/deploy_workflow.yml
```

### Option B: Set Environment Variables

```bash
# Set configuration via environment variables
export ANSIBLE_INVENTORY=~/andre/inventory/hosts.yml
export ANSIBLE_CONFIG=~/andre/ansible.cfg

# Test
ansible zos_sandbox -m ping
```

### Option C: Use ~/.ansible.cfg (Global Config)

```bash
# Copy ansible.cfg to home directory
cp ~/andre/ansible.cfg ~/.ansible.cfg

# Edit to use absolute paths
nano ~/.ansible.cfg
```

Change inventory line to:

```ini
inventory = /home/yourusername/andre/inventory/hosts.yml
```

## Recommended Setup Script

Create `~/andre/setup-env.sh`:

```bash
#!/bin/bash
# Ansible Environment Setup Script

# Set working directory
export ANSIBLE_DIR="$HOME/andre"
cd "$ANSIBLE_DIR"

# Set Ansible configuration
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"
export ANSIBLE_INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"

# Set z/OS password (CHANGE THIS!)
export ZOS_PASSWORD='your_password_here'

# Add Ansible to PATH
export PATH="$HOME/.local/bin:$PATH"

# Display configuration
echo "=========================================="
echo "Ansible Environment Configured"
echo "=========================================="
echo "Working Directory: $ANSIBLE_DIR"
echo "Config File: $ANSIBLE_CONFIG"
echo "Inventory: $ANSIBLE_INVENTORY"
echo "=========================================="
echo ""
echo "Ready to use Ansible!"
echo "Test with: ansible zos_sandbox -m ping"
echo ""
```

Make it executable:

```bash
chmod +x ~/andre/setup-env.sh
```

Use it:

```bash
# Source the script (note the dot)
source ~/andre/setup-env.sh

# Or add to ~/.bashrc for automatic setup
echo "source ~/andre/setup-env.sh" >> ~/.bashrc
```

## Complete Working Example

```bash
# 1. Copy to WSL filesystem
cp -r /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre

# 2. Navigate to directory
cd ~/andre

# 3. Set password
export ZOS_PASSWORD='your_password'

# 4. Update inventory with your z/OS details
nano inventory/hosts.yml

# 5. Test connection
ansible zos_sandbox -m ping

# 6. Deploy workflow
ansible-playbook playbooks/deploy_workflow.yml
```

## Syncing Files Between Windows and WSL

### Option 1: Edit in WSL, View in Windows

```bash
# Files in ~/andre are at:
# \\wsl$\Ubuntu\home\yourusername\andre
# Access via Windows Explorer
```

### Option 2: Use VS Code Remote-WSL

```bash
# Install VS Code Remote-WSL extension
# Open folder in WSL
code ~/andre
```

### Option 3: Sync Script

Create `~/andre/sync-from-windows.sh`:

```bash
#!/bin/bash
# Sync from Windows to WSL
rsync -av --delete \
  /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/ \
  ~/andre/
echo "Synced from Windows to WSL"
```

Create `~/andre/sync-to-windows.sh`:

```bash
#!/bin/bash
# Sync from WSL to Windows
rsync -av --delete \
  ~/andre/ \
  /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre/
echo "Synced from WSL to Windows"
```

## Verification Checklist

```bash
# 1. Check you're in WSL filesystem (not /mnt/c)
pwd
# Should show: /home/yourusername/andre

# 2. Check permissions are correct
ls -ld ~/andre
# Should show: drwxr-xr-x (NOT drwxrwxrwx)

# 3. Verify Ansible finds config
ansible --version | grep "config file"
# Should show: config file = /home/yourusername/andre/ansible.cfg

# 4. Test inventory
ansible-inventory --list
# Should show your zos_sandbox host

# 5. Test connection
ansible zos_sandbox -m ping
# Should show: SUCCESS
```

## Why This Happens

- **Windows filesystems** (`/mnt/c`) in WSL have different permission models
- **Ansible security**: Refuses to read config from world-writable directories
- **Solution**: Use WSL native filesystem (`~` or `/home`) with proper Unix permissions

## Quick Commands Reference

```bash
# Copy to WSL
cp -r /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre

# Navigate
cd ~/andre

# Set password
export ZOS_PASSWORD='password'

# Test
ansible zos_sandbox -m ping

# Deploy
ansible-playbook playbooks/deploy_workflow.yml

# List workflows
ansible-playbook playbooks/manage_workflows.yml -e "workflow_operation=list"
```

## Success!

Once you've copied to `~/andre`, all commands will work without warnings:

- ✅ ansible.cfg will be read
- ✅ Inventory will be found automatically
- ✅ No permission warnings
- ✅ Better performance (native filesystem)

**Next Step:** Run `cp -r /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre` and try again!
