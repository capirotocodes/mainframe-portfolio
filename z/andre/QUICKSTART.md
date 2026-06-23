# Quick Start Guide - z/OSMF Workflows with Ansible

## Setup (5 minutes)

### 1. Update Configuration

Edit `inventory/hosts.yml`:

```yaml
ansible_host: your-zos-hostname.example.com
zmf_host: your-zosmf-hostname.example.com
ansible_user: ANDRE
zmf_user: ANDRE
```

### 2. Set Password

```bash
export ZOS_PASSWORD='your_password'
```

### 3. Install Dependencies

```bash
pip3 install -r requirements.txt
ansible-galaxy collection install ibm.ibm_zos_core
ansible-galaxy collection install ibm.ibm_zosmf
```

## Deploy Your First Workflow (2 minutes)

```bash
cd z/andre
ansible-playbook playbooks/deploy_workflow.yml
```

## View in z/OSMF

1. Open: https://your-zosmf-host:443
2. Go to: Workflows → Workflows
3. Find: ANDRE*PROVISION_DATASETS*\*
4. Execute steps

## What Was Created?

- **Ansible inventory**: Connection details for your z/OS system
- **Sample workflow**: XML definition for dataset provisioning
- **Deploy playbook**: Uploads and starts workflows
- **Manage playbook**: List, check, start, delete workflows

## Next Steps

1. Customize `workflows/sample_provision.xml` for your needs
2. Create new workflow XML files
3. Update playbook variables
4. Deploy and test

## Common Commands

```bash
# List workflows
ansible-playbook playbooks/manage_workflows.yml -e "workflow_operation=list"

# Test connection
ansible zos_sandbox -m ping

# Deploy with custom HLQ
ansible-playbook playbooks/deploy_workflow.yml -e "zos_hlq=ANDRE.PROD"
```

## Need Help?

See full documentation in README.md
