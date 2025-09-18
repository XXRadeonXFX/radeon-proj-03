#!/bin/bash
set -e

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Azure DevOps pipeline YAML for ADF deployment

OPTIONS:
    -r, --repo-name         Repository name (required)
    -p, --project-abbv      Project abbreviation (required)
    -s, --service-abbv      Service abbreviation (required)
    -d, --dev-init          Enable dev initialization (true/false, default: false)
    -P, --deploy-prod       Enable production deployment (true/false, default: false)
    -o, --output            Output file name (default: azure-pipelines.yml)
    -h, --help              Show this help message

EXAMPLE:
    $0 -r "my-adf-repo" -p "poc-x1" -s "dm" -d true -P false

ADVANCED OPTIONS (optional):
    --key-vault-prefix      Key vault prefix (default: kv-{service_abbv}-{project_abbv})
    --rg-prefix            Resource group prefix (default: rg-{service_abbv}-datafactory)
    --sub-prefix           Subscription prefix (default: tp-{service_abbv}-source-data)
    --vnet-rg-prefix       VNet resource group prefix (default: rg-source-data-network)
    --vnet-prefix          VNet prefix (default: vnet-source-data-network)
    --diag-sub             Diagnostics subscription (default: tp-{service_abbv}-data-management-prd)
    --diag-rg              Diagnostics resource group (default: rg-{service_abbv}-log-prd-we-1)
    --diag-law             Log analytics workspace (default: log-{service_abbv}-prd-we-1)
    --adf-suffix           ADF suffix (default: we-1)
    --ir-enable            Enable integration runtime (true/false, default: true)
    --ir-name              Integration runtime name (default: TA{SERVICE_ABBV}SELUPOOL1)
    --ir-adf               IR ADF name (default: adf-{service_abbv}-ir-prd-we-1)
    --ir-rg                IR resource group (default: rg-{service_abbv}-adf-ir-prd-we-1)
    --ir-sub               IR subscription (default: tp-{service_abbv}-adf-ir-prd)
    --ir-selection-list    Available IR list (default: TA{SERVICE_ABBV}SELUPOOL1,TA{SERVICE_ABBV}SELUPOOL2)
    --force-ir-change      Force IR change on existing ADFs (true/false, default: false)
    --auto-select-ir       Auto-select available IR (true/false, default: true)

EOF
}

# Default values
REPO_NAME=""
PROJECT_ABBV=""
SERVICE_ABBV=""
DEV_INIT="false"
DEPLOY_TO_PROD="false"
OUTPUT_FILE="azure-pipelines.yml"

# Advanced options with defaults (will be set after parsing required params)
KEY_VAULT_PREFIX=""
RG_PREFIX=""
SUB_PREFIX=""
VNET_RG_PREFIX="rg-source-data-network"
VNET_PREFIX="vnet-source-data-network"
DIAG_SUB=""
DIAG_RG=""
DIAG_LAW=""
ADF_SUFFIX="we-1"
IR_ENABLE="true"
IR_NAME=""
IR_ADF=""
IR_RG=""
IR_SUB=""

# New IR selection parameters
IR_SELECTION_LIST=""
FORCE_IR_CHANGE="false"
AUTO_SELECT_IR="true"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo-name)
            REPO_NAME="$2"
            shift 2
            ;;
        -p|--project-abbv)
            PROJECT_ABBV="$2"
            shift 2
            ;;
        -s|--service-abbv)
            SERVICE_ABBV="$2"
            shift 2
            ;;
        -d|--dev-init)
            DEV_INIT="$2"
            shift 2
            ;;
        -P|--deploy-prod)
            DEPLOY_TO_PROD="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --key-vault-prefix)
            KEY_VAULT_PREFIX="$2"
            shift 2
            ;;
        --rg-prefix)
            RG_PREFIX="$2"
            shift 2
            ;;
        --sub-prefix)
            SUB_PREFIX="$2"
            shift 2
            ;;
        --vnet-rg-prefix)
            VNET_RG_PREFIX="$2"
            shift 2
            ;;
        --vnet-prefix)
            VNET_PREFIX="$2"
            shift 2
            ;;
        --diag-sub)
            DIAG_SUB="$2"
            shift 2
            ;;
        --diag-rg)
            DIAG_RG="$2"
            shift 2
            ;;
        --diag-law)
            DIAG_LAW="$2"
            shift 2
            ;;
        --adf-suffix)
            ADF_SUFFIX="$2"
            shift 2
            ;;
        --ir-enable)
            IR_ENABLE="$2"
            shift 2
            ;;
        --ir-name)
            IR_NAME="$2"
            shift 2
            ;;
        --ir-adf)
            IR_ADF="$2"
            shift 2
            ;;
        --ir-rg)
            IR_RG="$2"
            shift 2
            ;;
        --ir-sub)
            IR_SUB="$2"
            shift 2
            ;;
        --ir-selection-list)
            IR_SELECTION_LIST="$2"
            shift 2
            ;;
        --force-ir-change)
            FORCE_IR_CHANGE="$2"
            shift 2
            ;;
        --auto-select-ir)
            AUTO_SELECT_IR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$REPO_NAME" || -z "$PROJECT_ABBV" || -z "$SERVICE_ABBV" ]]; then
    echo "Error: Missing required parameters"
    echo "Required: --repo-name, --project-abbv, --service-abbv"
    show_usage
    exit 1
fi

# Validate boolean parameters
validate_boolean() {
    local param_name="$1"
    local param_value="$2"
    if [[ "$param_value" != "true" && "$param_value" != "false" ]]; then
        echo "Error: $param_name must be 'true' or 'false', got: $param_value"
        exit 1
    fi
}

validate_boolean "dev_init" "$DEV_INIT"
validate_boolean "deploy_to_prod" "$DEPLOY_TO_PROD"
validate_boolean "ir_enable" "$IR_ENABLE"
validate_boolean "force_ir_change" "$FORCE_IR_CHANGE"
validate_boolean "auto_select_ir" "$AUTO_SELECT_IR"

# Set default values for advanced options if not provided
[[ -z "$KEY_VAULT_PREFIX" ]] && KEY_VAULT_PREFIX="kv-${SERVICE_ABBV}-${PROJECT_ABBV}"
[[ -z "$RG_PREFIX" ]] && RG_PREFIX="rg-${SERVICE_ABBV}-datafactory"
[[ -z "$SUB_PREFIX" ]] && SUB_PREFIX="tp-${SERVICE_ABBV}-source-data"
[[ -z "$DIAG_SUB" ]] && DIAG_SUB="tp-${SERVICE_ABBV}-data-management-prd"
[[ -z "$DIAG_RG" ]] && DIAG_RG="rg-${SERVICE_ABBV}-log-prd-we-1"
[[ -z "$DIAG_LAW" ]] && DIAG_LAW="log-${SERVICE_ABBV}-prd-we-1"
[[ -z "$IR_NAME" ]] && IR_NAME="TA$(echo ${SERVICE_ABBV} | tr '[:lower:]' '[:upper:]')SELUPOOL1"
[[ -z "$IR_ADF" ]] && IR_ADF="adf-${SERVICE_ABBV}-ir-prd-we-1"
[[ -z "$IR_RG" ]] && IR_RG="rg-${SERVICE_ABBV}-adf-ir-prd-we-1"
[[ -z "$IR_SUB" ]] && IR_SUB="tp-${SERVICE_ABBV}-adf-ir-prd"

# Set default values for IR selection if not provided
[[ -z "$IR_SELECTION_LIST" ]] && IR_SELECTION_LIST="${IR_NAME},TA$(echo ${SERVICE_ABBV} | tr '[:lower:]' '[:upper:]')SELUPOOL2,TA$(echo ${SERVICE_ABBV} | tr '[:lower:]' '[:upper:]')SELUPOOL3"

# Function to generate the YAML content
generate_pipeline_yaml() {
    cat << EOF
name: \$(Build.SourceBranchName).\$(Date:yyyyMMdd)\$(Rev:.r)
resources:
  repositories:
    - repository: templates
      type: git
      name: Platform and Process/facade-template-tf-module-adf_pnp
      ref: refs/heads/main-new
variables:
  - group: vmss_group
extends:
    template: pipeline.yml@templates
    parameters:
      # Always send VM id and agent pool name in ES
      vm_id: \$(vmss_identity) # \$[ stageDependencies.InitScript.GetVmAgentDetails.outputs['VmAgentDetails.vm_id'] ]
      agent_pool: \$(agent_pool) # \$[ stageDependencies.InitScript.GetVmAgentDetails.outputs['VmAgentDetails.agent_pool'] ]
      dev_init: ${DEV_INIT} # Set to true when initializing new env
      deploy_to_prod: ${DEPLOY_TO_PROD} # turn on only when deploying to prod
      repo_name: "${REPO_NAME}" # adf integration repo name
      project_abbv: "${PROJECT_ABBV}" # project abbreviation - eg - mo, sd
      service_abbv: "${SERVICE_ABBV}" # service abbreviation - eg - dm
      key_vault_prefix: "${KEY_VAULT_PREFIX}" # prefix for key vault name (string before env)
      resource_group_prefix: "${RG_PREFIX}" # prefix for resource group name (string before env)
      subscription_prefix: "${SUB_PREFIX}" # prefix for subscription name (string before env)
      vnet_rg_prefix: "${VNET_RG_PREFIX}" # prefix for vnet resource group name (string before env)
      vnet_prefix: "${VNET_PREFIX}" # prefix for vnet name (string before env)
      diagnostics_subscription: "${DIAG_SUB}" # subscription name of log analytics workspace
      diagnostics_rg: "${DIAG_RG}" # resouce group of log analytics workspace
      diagnostics_law: "${DIAG_LAW}" # name of log analytics workspace
      adf_suffix: ${ADF_SUFFIX}
      # Send below 5 parameters if you want to enable integration runtime on adf
      ir_enable: ${IR_ENABLE} # true if you want to enable integration runtime
      ir_name: "${IR_NAME}" # integration runtime name, defaults this value
      ir_adf: "${IR_ADF}" # integration runtime adf name, defaults this value
      ir_rg: "${IR_RG}" # integration runtime adf resource group name, defaults this value
      ir_sub: "${IR_SUB}" # integration runtime adf subscription name, defaults this value
      # IR Selection Parameters - NEW
      ir_selection_list: "${IR_SELECTION_LIST}" # comma-separated list of available IRs
      force_ir_change: ${FORCE_IR_CHANGE} # force IR change on existing ADFs
      auto_select_ir: ${AUTO_SELECT_IR} # enable automatic IR selection
      
EOF
}

# Generate the pipeline YAML
echo "Generating Azure DevOps ADF pipeline..."
echo "Repository Name: $REPO_NAME"
echo "Project Abbreviation: $PROJECT_ABBV"
echo "Service Abbreviation: $SERVICE_ABBV"
echo "Dev Init: $DEV_INIT"
echo "Deploy to Prod: $DEPLOY_TO_PROD"
echo "Output File: $OUTPUT_FILE"
echo ""

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [[ "$OUTPUT_DIR" != "." && ! -d "$OUTPUT_DIR" ]]; then
    echo "Creating directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Generate and save the YAML
generate_pipeline_yaml > "$OUTPUT_FILE"

echo "Pipeline YAML generated successfully: $OUTPUT_FILE"
echo ""
echo "Generated configuration:"
echo "- Key Vault Prefix: $KEY_VAULT_PREFIX"
echo "- Resource Group Prefix: $RG_PREFIX"
echo "- Subscription Prefix: $SUB_PREFIX"
echo "- Integration Runtime Name: $IR_NAME"
echo "- Integration Runtime Enabled: $IR_ENABLE"
echo "- IR Selection List: $IR_SELECTION_LIST"
echo "- Force IR Change: $FORCE_IR_CHANGE"
echo "- Auto Select IR: $AUTO_SELECT_IR"
echo ""
echo "You can now commit this file to your repository and use it in Azure DevOps."

# Display test examples
echo ""
echo "TESTING EXAMPLES:"
echo ""
echo "1. Safe mode (existing ADFs unchanged):"
echo "   ./$(basename "$0") -r \"test-repo\" -p \"tst\" -s \"dm\" -d true"
echo ""
echo "2. Multiple IRs available:"
echo "   ./$(basename "$0") -r \"test-repo\" -p \"tst\" -s \"dm\" -d true \\"
echo "     --ir-selection-list \"TADMSELUPOOL1,TADMSELUPOOL2,TADMSELUPOOL3\""
echo ""
echo "3. Force IR migration:"
echo "   ./$(basename "$0") -r \"test-repo\" -p \"tst\" -s \"dm\" -d false \\"
echo "     --force-ir-change true --ir-selection-list \"TADMSELUPOOL2,TADMSELUPOOL3\""
echo ""
echo "4. Manual IR selection:"
echo "   ./$(basename "$0") -r \"test-repo\" -p \"tst\" -s \"dm\" -d false \\"
echo "     --auto-select-ir false --ir-name \"TADMSELUPOOL2\""

# Make the script executable
chmod +x "$0" 2>/dev/null || true