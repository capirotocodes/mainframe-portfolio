# WSL Setup Guide - Ansible for z/OSMF Workflows

Complete walkthrough for setting up Ansible in WSL (Windows Subsystem for Linux) to manage z/OSMF workflows.

## Prerequisites

- Windows 10/11 with WSL2 installed
- Ubuntu or Debian distribution in WSL
- Access to z/OS system with z/OSMF

## Step-by-Step Setup

### Step 1: Open WSL Terminal

```bash
# From Windows, open WSL
wsl

# Or open Ubuntu from Start Menu
```

### Step 2: Update System Packages

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 3: Install Python and Pip

```bash
# Install Python 3 and pip
sudo apt install python3 python3-pip -y

# Verify installation
python3 --version
pip3 --version
```

### Step 4: Install Ansible

```bash
# Install Ansible
pip3 install ansible

# Add to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
ansible --version
```

### Step 5: Install IBM z/OS Collections

```bash
# Install IBM collections for z/OS
ansible-galaxy collection install ibm.ibm_zos_core
ansible-galaxy collection install ibm.ibm_zosmf

# Verify collections
ansible-galaxy collection list | grep ibm
```

### Step 6: Access Your Files in WSL

```bash
# Navigate to your Windows files
# Windows C: drive is mounted at /mnt/c
cd /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre

# Or create a symbolic link for easier access
ln -s /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre
cd ~/andre
```

### Step 7: Configure Your z/OS Connection

```bash
# Edit inventory file
nano inventory/hosts.yml
```

Update these values:

```yaml
ansible_host: your-zos-hostname.example.com # Your z/OS system
zmf_host: your-zosmf-hostname.example.com # Your z/OSMF host
ansible_user: ANDRE # Your z/OS user ID
zmf_user: ANDRE # Your z/OSMF user ID
zos_hlq: ANDRE # Your high-level qualifier
zos_volume: USER01 # Target volume
```

Save: `Ctrl+O`, `Enter`, `Ctrl+X`

### Step 8: Set Your Password

```bash
# Set password as environment variable
export ZOS_PASSWORD='your_actual_password'

# To make it persistent, add to ~/.bashrc
echo "export ZOS_PASSWORD='your_actual_password'" >> ~/.bashrc
```

**Security Note:** For production, use ansible-vault instead:

```bash
ansible-vault encrypt group_vars/zos_systems.yml
```

### Step 9: Test Connection

```bash
# Test Ansible can reach your z/OS system
ansible zos_sandbox -m ping

# Expected output:
# zos_sandbox | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

### Step 10: Deploy Your First Workflow

```bash
# Deploy the sample workflow
ansible-playbook playbooks/deploy_workflow.yml

# Watch the output for:
# - Workflow uploaded to z/OS
# - Workflow instance created
# - Workflow key returned
```

### Step 11: Access z/OSMF Web Interface

1. Open browser on Windows
2. Navigate to: `https://your-zosmf-host:443`
3. Login with your credentials
4. Go to: **Workflows** → **Workflows**
5. Find your workflow: `ANDRE_PROVISION_DATASETS_*`
6. Click to open and execute steps

## Common WSL Commands

```bash
# List all workflows
ansible-playbook playbooks/manage_workflows.yml -e "workflow_operation=list"

# Check workflow status (replace with your workflow key)
ansible-playbook playbooks/manage_workflows.yml \
  -e "workflow_operation=check" \
  -e "workflow_key=YOUR_WORKFLOW_KEY"

# Deploy with custom variables
ansible-playbook playbooks/deploy_workflow.yml \
  -e "zos_hlq=ANDRE.TEST" \
  -e "zos_volume=USER02"

# Run with verbose output for debugging
ansible-playbook playbooks/deploy_workflow.yml -vvv
```

## Troubleshooting

### Issue: "ansible: command not found"

```bash
# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "No module named 'ansible'"

```bash
# Reinstall Ansible
pip3 install --upgrade ansible
```

### Issue: "Failed to connect to host"

```bash
# Test SSH connectivity
ssh ANDRE@your-zos-hostname

# Test z/OSMF REST API
curl -k -u ANDRE:password https://your-zosmf-host:443/zosmf/info
```

### Issue: "Collection not found"

```bash
# Reinstall collections
ansible-galaxy collection install --force ibm.ibm_zos_core
ansible-galaxy collection install --force ibm.ibm_zosmf
```

### Issue: "Permission denied" accessing Windows files

```bash
# Check file permissions
ls -la /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre

# If needed, copy to WSL home directory
cp -r /mnt/c/Users/075949631/Documents/Zowe/mainframe-portfolio/z/andre ~/andre
cd ~/andre
```

## File Editing in WSL

### Option 1: Use nano (simple)

```bash
nano inventory/hosts.yml
```

### Option 2: Use vim (advanced)

```bash
vim inventory/hosts.yml
```

### Option 3: Use VS Code from WSL

```bash
# Install VS Code extension for WSL
# Then open files directly
code inventory/hosts.yml
```

### Option 4: Edit in Windows

- Edit files in Windows using VS Code
- Changes are immediately visible in WSL
- Files are at: `C:\Users\075949631\Documents\Zowe\mainframe-portfolio\z\andre`

## Next Steps

1. ✅ Verify all connections work
2. ✅ Deploy sample workflow
3. ✅ Execute workflow steps in z/OSMF UI
4. 📝 Create your own workflow XML
5. 🚀 Deploy custom workflows

## Quick Reference Card

```bash
# Navigate to project
cd ~/andre  # or cd /mnt/c/Users/075949631/.../z/andre

# Set password
export ZOS_PASSWORD='password'

# Test connection
ansible zos_sandbox -m ping

# Deploy workflow
ansible-playbook playbooks/deploy_workflow.yml

# List workflows
ansible-playbook playbooks/manage_workflows.yml -e "workflow_operation=list"

# View logs
tail -f ansible.log
```

## Tips for WSL

- **Performance**: Copy files to WSL filesystem (`~/andre`) for better performance
- **Networking**: WSL2 has its own network stack, ensure firewall allows connections
- **File Permissions**: Windows files in `/mnt/c` may have different permissions
- **Line Endings**: Use `dos2unix` if you have CRLF issues: `sudo apt install dos2unix`

## Success Checklist

- [ ] WSL installed and updated
- [ ] Python 3 and pip installed
- [ ] Ansible installed and in PATH
- [ ] IBM collections installed
- [ ] Inventory configured with z/OS details
- [ ] Password set in environment
- [ ] Connection test successful (`ansible zos_sandbox -m ping`)
- [ ] Sample workflow deployed
- [ ] Workflow visible in z/OSMF UI

You're ready to automate z/OS workflows! 🎉
