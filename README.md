# Azure DevOps ADF Automation Pipeline Documentation

## Overview

This documentation describes an automated Azure Data Factory (ADF) deployment system that manages repository creation, infrastructure deployment, and ADF pipeline configuration through Azure DevOps pipelines.

## System Architecture

### Main Pipeline: `facade-generate-code-adf-automation.yml`

The main orchestration pipeline consists of multiple stages that execute sequentially:

1. **CheckRepoExistence** - Validates if the target repository exists
2. **CreateADFRepoTerraformCode** - Generates Terraform infrastructure code
3. **WaitForApproval** - Manual approval gate for deployment
4. **DeployRepo** - Deploys repository infrastructure using Terraform
5. **ONPremIRCheck** - Checks Integration Runtime capacity
6. **DeployADFpublish** - Deploys ADF to test/production environments
7. **DeployADFmain** - Deploys ADF to development environment

---

## Stage Details

### 1. CheckRepoExistence

**Purpose**: Verify if the ADF Git repository already exists in Azure DevOps.

**Key Actions**:
- Installs Azure CLI DevOps extension
- Authenticates using System Access Token
- Checks repository existence
- Sets output variable `repoExists` (true/false)

**Output Variables**:
- `repoExists`: Boolean indicating repository existence

---

### 2. CreateADFRepoTerraformCode

**Purpose**: Generate Terraform code for creating the ADF repository.

**Condition**: Only runs if `repoExists = false`

**Key Steps**:
1. **Create Dynamic Branch**:
   - Branch name matches the repository name parameter
   - Creates new branch or checks out existing one
   - Configures Git with pipeline credentials

2. **Generate Terraform Code**:
   - Executes `generate-terraform.sh` script
   - Creates infrastructure-as-code for the repository

3. **Commit and Push**:
   - Commits generated Terraform files
   - Pushes to the dynamic branch

4. **Create Pull Request**:
   - Automatically creates PR for review
   - Uses encoded PAT for authentication

---

### 3. WaitForApproval

**Purpose**: Manual approval gate before deploying infrastructure.

**Condition**: Only runs if repository was newly created

**Configuration**:
- Timeout: 1440 minutes (24 hours)
- Options:
  - **APPROVE**: Continue with ADF deployment
  - **REJECT**: Skip ADF deployment (keep repository only)
- Default action on timeout: Reject

---

### 4. DeployRepo

**Purpose**: Deploy repository infrastructure using Terraform/Terragrunt.

**Condition**: Runs if repository is new AND approval was granted

**Key Steps**:
1. **Switch to Dynamic Branch**:
   - Fetches the branch created in CreateADFRepoTerraformCode stage
   - Pulls latest changes

2. **Login and Fetch Token**:
   - Uses managed identity for Azure authentication
   - Retrieves PAT from Key Vault (`kv-dm-pp-prd-we-1`)

3. **Detect Changed Folders**:
   - Compares latest two commits
   - Identifies folders with Terraform changes

4. **Apply Infrastructure Changes**:
   - Runs `terraform init` and `terraform apply`
   - Creates repository and associated resources

**Container Environment**:
- Image: `facade-template-tf-module-env_pnp:main`
- Runs as root user (0:0)

---

### 5. ONPremIRCheck (Integration Runtime Capacity Check)

**Purpose**: Determine optimal Integration Runtime for the new ADF.

**Condition**: Runs after successful repository deployment or if repository already existed

**Key Actions**:
1. Authenticates using managed identity
2. Lists all Data Factories in resource group `rg-dm-adf-ir-prd-we-1`
3. For each ADF:
   - Determines IR name (e.g., `TADMSELUPOOL1`, `TADMSELUPOOL2`)
   - Checks linked factory count
   - Calculates available capacity (MAX_CAPACITY - linked_count)
4. Selects IR with lowest linked count

**Output Variables**:
- `SELECTED_ADF`: Data Factory name with best capacity
- `SELECTED_IR`: Integration Runtime name to use
- `AVAILABLE_CAPACITY`: Remaining capacity
- `IR_LINKED_COUNT`: Current linked factories count

**Configuration**:
- Resource Group: `rg-dm-adf-ir-prd-we-1`
- Max Capacity: 100 (default)
- Client ID: `2b386df0-8e01-4f94-b6bb-3104a8a8f30c`

---

### 6. DeployADFpublish

**Purpose**: Generate and deploy ADF configuration to `adf_publish` branch for test/production.

**Condition**: Runs after successful IR capacity check

**Key Steps**:
1. **Clone Target Repository**:
   - Clones the dynamic repository using System Access Token

2. **Generate Configuration Files**:
   - Creates `ci/azure-pipelines.yml` with deployment parameters
   - Sets `dev_init_flag: true` and uses production flag from parameters
   - Configures Integration Runtime details from IR check stage

3. **Commit and Push**:
   - Commits files to `adf_publish` branch
   - Uses PAT authentication from Key Vault

**Generated Files**:
- `ci/azure-pipelines.yml`: Pipeline configuration for ADF deployment

---

### 7. DeployADFmain

**Purpose**: Generate complete ADF deployment configuration for the `main` branch (development).

**Condition**: Runs after successful `adf_publish` deployment

**Key Steps**:
1. **Clone Target Repository**

2. **Generate All Configuration Files**:
   - `ci/azure-pipelines.yml`: Deployment pipeline
   - `managedVirtualNetwork/default/default.json`: Virtual network config
   - `managedVirtualNetwork/default/managedPrivateEndpoint/AzureDatabricks.json`: Databricks endpoint
   - `publish_config.json`: ADF publish configuration

3. **Commit and Push**:
   - Commits all files to `main` branch
   - Uses PAT authentication

**Generated Files**:
- `ci/azure-pipelines.yml`
- `managedVirtualNetwork/` structure
- `publish_config.json`

---

## Pipeline Parameters

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `repository_name` | string | Name of the ADF repository | `adf-sales-pipeline` |
| `project_name` | string | Azure DevOps project name | `Data Management` |
| `project_abbv` | string | Project abbreviation | `dm` |
| `factory_name` | string | Azure Data Factory name | `adf-dm-sales-dev-we-1` |
| `deploy_pipeline_name` | string | Name of deployment pipeline | `adf-sales-deploy` |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `deploy_repo_branch` | string | `main` | Deploy repo branch name |
| `dev_init_flag` | string | `true` | Initialize dev environment |
| `prd_flag` | string | `false` | Enable production deployment |
| `branch_name` | string | `main` | Target branch (main/adf_publish) |
| `build_pipeline` | string | `true` | Create build pipeline |
| `deploy_pipeline` | string | `true` | Create deploy pipeline |
| `enable_deployment_trigger` | boolean | `true` | Enable automatic deployment |
| `location` | string | `westeurope` | Azure region |
| `key_vault_prefix` | string | `kv-dm-sd` | Key Vault prefix |
| `resource_group_prefix` | string | `rg-dm-datafactory` | Resource group prefix |
| `subscription_prefix` | string | `tp-dm-source-data` | Subscription prefix |
| `vnet_resource_group_prefix` | string | `rg-source-data-network` | VNet RG prefix |
| `vnet_prefix` | string | `vnet-source-data-network` | VNet prefix |
| `deployment_pipeline_yml` | string | `ci/azure-pipelines.yml` | Pipeline file path |

---

## Supporting Scripts

### 1. `adf_ir_capacity_checker.sh`

**Purpose**: Find the Integration Runtime with the most available capacity.

**Features**:
- Authenticates using managed identity
- Searches across subscriptions if needed
- Calculates capacity based on linked factories
- Outputs colored, formatted results
- Sets Azure DevOps pipeline variables

**Algorithm**:
```
For each Data Factory:
  1. Determine IR name from ADF suffix
  2. Get linked factories count
  3. Calculate available capacity (100 - linked_count)
  4. Track IR with lowest linked count
Return: Best ADF and IR combination
```

---

### 2. `generate-ci-file.sh`

**Purpose**: Generate `azure-pipelines.yml` for ADF deployment.

**Usage**:
```bash
./generate-ci-file.sh \
  -r "repo-name" \
  -p "project-abbv" \
  -s "service-abbv" \
  -d "true" \
  -P "false"
```

**Generated Pipeline Structure**:
- Extends from template repository
- Configures environment-specific parameters
- Sets up Integration Runtime linkage
- Configures diagnostics and networking

---

### 3. `generate-managedVirtualNetwork-json.sh`

**Purpose**: Create ADF Managed Virtual Network configuration.

**Generated Files**:
- `managedVirtualNetwork/default/default.json`
- `managedVirtualNetwork/default/managedPrivateEndpoint/AzureDatabricks.json`

**Databricks Configuration**:
- Subscription: `3271fd7f-3660-4f9c-86f1-17d40810ce49`
- Resource Group: `rg-dm-databricks-dev-we-1`
- Workspace: `dbw-dm-sd-dev-we-1`
- Group ID: `databricks_ui_api`

---

### 4. `generate-publish-config-json.sh`

**Purpose**: Create ADF publish configuration.

**Generated Content**:
```json
{
  "publishBranch": "adf_publish",
  "enableGitComment": true,
  "includeGlobalParamsTemplate": true
}
```

---

### 5. `commit-and-push.sh` (ADF version)

**Purpose**: Commit and push ADF configuration files.

**Features**:
- Handles branch creation/checkout
- Stashes uncommitted changes before branch operations
- Retrieves PAT from Key Vault
- Pushes to correct branch (`main` or `adf_publish`)
- Creates branches if they don't exist

**Branch Logic**:
1. Ensures `main` branch exists first
2. Creates target branch from `main` if needed
3. Restores stashed changes after branch switch
4. Commits and pushes changes

---

### 6. Common Scripts

#### `detect-changed-folders.sh`
- Compares last two commits
- Identifies folders with changes
- Outputs to `changed_folders.txt`

#### `apply-in-changed-folders.sh`
- Reads `changed_folders.txt`
- Runs Terraform/Terragrunt in changed folders
- Handles both Terraform and Terragrunt projects
- Configures authentication and proxy settings

#### `get-token.sh`
- Authenticates using managed identity
- Retrieves PAT from Key Vault
- URL-encodes PAT
- Sets pipeline variables

#### `create-pull-request.py`
- Creates PR using Azure DevOps REST API
- Authenticates with PAT
- Sets title and description
- Targets `main` branch

---

## Authentication & Security

### Managed Identity
- **Client ID**: `2b386df0-8e01-4f94-b6bb-3104a8a8f30c`
- Used for:
  - Azure CLI authentication
  - Key Vault access
  - Terraform provider authentication

### Personal Access Token (PAT)
- **Storage**: Azure Key Vault `kv-dm-pp-prd-we-1`
- **Secret Name**: `SRVSELUDEVOPS01-PAT`
- **Usage**:
  - Git operations
  - Azure DevOps API calls
  - Repository access
  - PR creation

### Git Configuration
- **User**: `Automation-Pipeline` / `SRVSELUDEVOPS01@tetrapak.com`
- **Authentication**: PAT-based HTTPS

---

## Environment Configuration

### Agent Pool
- **Name**: `vmss-dm-pp-prd-we-1`
- **Type**: VMSS (Virtual Machine Scale Set)

### Container Registry
- **Registry**: `crdmppbasewe1.azurecr.io`
- **Image**: `facade-template-tf-module-env_pnp:main`

### Azure Resources
- **Subscription**: `48fbff7b-2f91-4f9c-b299-fe4fb7a8a423`
- **IR Resource Group**: `rg-dm-adf-ir-prd-we-1`
- **Key Vault**: `kv-dm-pp-prd-we-1`

---

## Workflow Diagram

```
Start
  │
  ├─► CheckRepoExistence
  │     ├─► Exists? ──Yes──► Skip to ONPremIRCheck
  │     └─► No ──────┐
  │                  │
  ├─► CreateADFRepoTerraformCode
  │     ├─► Create branch (repo_name)
  │     ├─► Generate Terraform
  │     ├─► Commit & Push
  │     └─► Create PR
  │                  │
  ├─► WaitForApproval ◄─┘
  │     ├─► Approve ──┐
  │     └─► Reject ───┼─► End
  │                   │
  ├─► DeployRepo ◄────┘
  │     ├─► Switch to dynamic branch
  │     ├─► Run Terraform
  │     └─► Create repository
  │                   │
  ├─► ONPremIRCheck ◄─┴─────┐
  │     ├─► Check all ADFs   │
  │     ├─► Calculate capacity│
  │     └─► Select best IR    │
  │                   │       │
  ├─► DeployADFpublish◄┘      │
  │     ├─► Clone repo        │
  │     ├─► Generate ci file   │
  │     └─► Push to adf_publish│
  │                   │
  ├─► DeployADFmain ◄─┘
  │     ├─► Clone repo
  │     ├─► Generate all files
  │     ├─► managedVirtualNetwork
  │     ├─► publish_config.json
  │     └─► Push to main
  │
End
```

---

## Error Handling

### Pipeline Level
- All stages have explicit conditions
- Failed stages block dependent stages
- Manual approval timeout defaults to reject

### Script Level
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `set -o pipefail`: Fail on pipe errors
- Color-coded logging (RED, GREEN, YELLOW, BLUE)
- Explicit error messages with `error_exit()`

---

## Best Practices

### 1. Branch Management
- Use repository name as branch name for isolation
- Always create `main` branch first
- Stash changes before branch operations

### 2. Authentication
- Use managed identity where possible
- Store secrets in Key Vault
- URL-encode PAT for Git operations
- Mark PAT variables as secret

### 3. Terraform Operations
- Detect changes to minimize deployments
- Run init before plan/apply
- Use backend configuration files
- Output important values (repo URL, pipeline URLs)

### 4. Integration Runtime
- Always check capacity before assignment
- Select IR with lowest linked count
- Validate IR exists before proceeding
- Set max capacity limits

---

## Troubleshooting

### Common Issues

**1. Repository Already Exists**
- Pipeline skips to ONPremIRCheck stage
- No Terraform generation occurs
- Continues with ADF deployment

**2. IR Capacity Full**
- Script selects IR with most capacity
- Check `IR_LINKED_COUNT` output variable
- May need to add new IR pool

**3. Branch Conflicts**
- Script handles existing branches
- Stashes uncommitted changes
- Pulls latest before pushing

**4. PAT Authentication Fails**
- Verify Key Vault secret exists
- Check managed identity permissions
- Validate PAT hasn't expired

**5. Terraform Apply Fails**
- Check backend configuration
- Verify managed identity has contributor role
- Review Terraform plan output

---

## Monitoring & Outputs

### Pipeline Variables Set

**From ONPremIRCheck**:
- `SELECTED_ADF`
- `SELECTED_IR`
- `AVAILABLE_CAPACITY`
- `IR_LINKED_COUNT`

**From DeployRepo**:
- `ENCODED_PAT` (secret)
- `PAT` (secret)

### Logs to Review
- Capacity analysis results
- Terraform plan output
- Git operations (commit, push)
- PR creation confirmation

---

## Future Enhancements

### Potential Improvements
1. **Automatic IR Scaling**: Add new IR pools when capacity reaches threshold
2. **Rollback Mechanism**: Automated rollback on deployment failure
3. **Multi-Region Support**: Deploy to multiple Azure regions
4. **Health Checks**: Post-deployment validation
5. **Notification System**: Alert on failures or approvals needed
6. **Metrics Collection**: Track deployment times and success rates

---

## References

### Related Repositories
- `pnp-pipelines-automation`: Contains all automation scripts
- `pnp-deploy-repo-automation`: Infrastructure deployment repo
- `facade-template-tf-module-adf_pnp`: ADF Terraform template

### Documentation Links
- Azure Data Factory: [Microsoft Docs](https://docs.microsoft.com/azure/data-factory/)
- Azure DevOps Pipelines: [Microsoft Docs](https://docs.microsoft.com/azure/devops/pipelines/)
- Terraform: [terraform.io](https://www.terraform.io/)

---

## Contact & Support

For issues or questions:
1. Check pipeline run logs
2. Review Azure DevOps build history
3. Contact Platform and Process team
4. Check `pnp-pipelines-automation` repository README

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-03  
**Maintained By**: Platform and Process Team
