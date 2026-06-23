# Manual Workflow Upload Guide

Since the automated upload has API limitations, here's how to upload and use workflows manually in z/OSMF.

## 📋 Method 1: Upload via z/OSMF Web UI (Easiest)

### Step 1: Access z/OSMF

1. Open browser: `https://9.12.19.209:443`
2. Login with your credentials (ANDRE)

### Step 2: Navigate to Workflows

1. Click **Workflows** in the left menu
2. Click **Workflows** submenu

### Step 3: Create New Workflow

1. Click **Actions** → **Create Workflow**
2. Fill in the form:
   - **Workflow Definition File**: Browse and select `sample_provision.xml` from your local machine
   - **Workflow Name**: `ANDRE_PROVISION_DATASETS`
   - **System**: `9.12.19.209` (or your system name)
   - **Owner**: `ANDRE`

### Step 4: Set Variables

1. **HLQ**: `ANDRE.DEMO`
2. **VOLUME**: `USER01`

### Step 5: Execute Workflow

1. Click on your newly created workflow
2. Execute each step:
   - Step 1: Allocate Source Dataset
   - Step 2: Allocate Load Library
   - Step 3: Allocate JCL Library
   - Step 4: Verify Dataset Creation

## 📋 Method 2: Use Zowe CLI (Alternative)

If you have Zowe CLI installed:

```bash
# Create profile
zowe profiles create zosmf-profile zosmf_profile \
  --host 9.12.19.209 \
  --port 443 \
  --user ANDRE \
  --password your_password \
  --reject-unauthorized false

# Upload workflow
zowe zos-workflows create workflow-from-local-file \
  "sample_provision.xml" \
  --workflow-name "ANDRE_PROVISION_DATASETS" \
  --system-name "9.12.19.209" \
  --owner "ANDRE" \
  --variables HLQ=ANDRE.DEMO VOLUME=USER01
```

## 📋 Method 3: Ansible for Workflow Management Only

Use Ansible to manage existing workflows (not create them):

```bash
# List workflows
cd ~/andre
export ZOS_PASSWORD='your_password'
ansible-playbook playbooks/manage_workflows.yml -e "workflow_operation=list"

# Check workflow status
ansible-playbook playbooks/manage_workflows.yml \
  -e "workflow_operation=check" \
  -e "workflow_key=YOUR_WORKFLOW_KEY"

# Delete workflow
ansible-playbook playbooks/manage_workflows.yml \
  -e "workflow_operation=delete" \
  -e "workflow_key=YOUR_WORKFLOW_KEY"
```

## 🎯 Recommended Workflow

1. **Create workflows manually** via z/OSMF UI (one-time setup)
2. **Manage workflows** via Ansible (list, check status, delete)
3. **Execute steps** via z/OSMF UI (interactive)

## 📝 Your Workflow XML Location

The sample workflow is at:

- **Windows**: `C:\Users\075949631\Documents\Zowe\mainframe-portfolio\z\andre\workflows\sample_provision.xml`
- **WSL**: `~/andre/workflows/sample_provision.xml`

## ✨ What the Sample Workflow Does

Creates 3 datasets:

1. **ANDRE.DEMO.SOURCE** - Source code (FB, LRECL=80)
2. **ANDRE.DEMO.LOADLIB** - Load modules (PDSE, U format)
3. **ANDRE.DEMO.JCLLIB** - JCL procedures (FB, LRECL=80)

## 🚀 Next Steps

1. Upload `sample_provision.xml` via z/OSMF UI
2. Execute the workflow steps
3. Verify datasets were created
4. Create your own custom workflows
5. Use Ansible to manage them

## 💡 Tips

- **Workflow XML** can be edited in VS Code
- **Test locally** before uploading
- **Use variables** for flexibility
- **Document steps** clearly
- **Version control** your workflows in Git

## 🔧 Creating Custom Workflows

Edit `~/andre/workflows/sample_provision.xml` or create new files:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<workflow>
    <workflowInfo>
        <workflowID>YOUR_WORKFLOW_ID</workflowID>
        <workflowDescription>Your description</workflowDescription>
    </workflowInfo>

    <variable name="VAR_NAME" scope="instance">
        <label>Variable Label</label>
        <string>
            <default>default_value</default>
        </string>
    </variable>

    <step name="step1">
        <title>Step Title</title>
        <instructions substitution="true">
            Instructions with ${VAR_NAME}
        </instructions>
        <template>
            <inlineTemplate substitution="true">
//JOBNAME JOB CLASS=A
//STEP1   EXEC PGM=IEFBR14
            </inlineTemplate>
            <submitAs>JCL</submitAs>
        </template>
    </step>
</workflow>
```

Upload via z/OSMF UI and execute!
