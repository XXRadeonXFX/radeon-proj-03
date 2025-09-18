#!/bin/bash
set -euo pipefail

# ==========================================================
# Script: generate-integrationRuntime-json.sh
# Purpose: Generate ADF Integration Runtime JSON files
# ==========================================================

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "ERROR: $1" >&2; exit 1; }

# -------------------- Usage --------------------
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Integration Runtime JSON configuration for ADF.

OPTIONS:
    -o, --output-dir     Output directory (default: current working directory)
    -h, --help           Show this help message

EXAMPLE:
    $0 -o ./output
EOF
}

# -------------------- Defaults --------------------
OUTPUT_DIR="."

# -------------------- Parse args --------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) show_usage; exit 0 ;;
        *) error_exit "Unknown option: $1" ;;
    esac
done

# -------------------- Paths --------------------
IR_DIR="$OUTPUT_DIR/integrationRuntime"

log "Creating directories..."
mkdir -p "$IR_DIR"

# -------------------- Generate AutoResolveIntegrationRuntime.json --------------------
AUTO_FILE="$IR_DIR/AutoResolveIntegrationRuntime.json"
log "Generating $AUTO_FILE"
cat > "$AUTO_FILE" <<EOF
{
  "name": "AutoResolveIntegrationRuntime",
  "properties": {
    "type": "Managed",
    "typeProperties": {
      "computeProperties": {
        "location": "AutoResolve",
        "dataflowProperties": {
          "computeType": "General",
          "coreCount": 8,
          "timeToLive": 0
        }
      }
    }
  }
}
EOF


# ---------- Generate JSON ----------
OUTPUT_DIR="."
LOCATION="West Europe"
CORE_COUNT=8
TTL=10
PIPELINE_TTL=60

AUTO_FILE="$IR_DIR/AutoResolveIntegrationRuntimeVnet.json"
log "Generating $AUTO_FILE"
cat > "$AUTO_FILE" <<EOF
{
  "name": "AutoResolveIntegrationRuntimeVnet",
  "properties": {
    "type": "Managed",
    "typeProperties": {
      "computeProperties": {
        "location": "$LOCATION",
        "dataFlowProperties": {
          "computeType": "General",
          "coreCount": $CORE_COUNT,
          "timeToLive": $TTL,
          "cleanup": false,
          "customProperties": []
        },
        "pipelineExternalComputeScaleProperties": {
          "timeToLive": $PIPELINE_TTL,
          "numberOfPipelineNodes": 1,
          "numberOfExternalNodes": 1
        }
      },
      "managedVirtualNetwork": {
        "type": "ManagedVirtualNetworkReference",
        "referenceName": "default"
      }
    }
  }
}
EOF

# -------------------- Generate TADMSELUP00L1.json --------------------
SELFHOSTED_FILE="$IR_DIR/TADMSELUPOOL1.json"
log "Generating $SELFHOSTED_FILE"
cat > "$SELFHOSTED_FILE" <<EOF
{
  "name": "TADMSELUP00L1",
  "properties": {
    "type": "SelfHosted",
    "typeProperties": {
      "linkedInfo": {
        "resourceId": "/subscriptions/48fbf7fb-2f91-4f9c-b299-fe4fb7a8a423/resourcegroups/rg-dm-adf-ir-prd-we-1/providers/Microsoft.DataFactory/factories/adf-dm-ir-prd-we-1/integrationruntimes/TADMSELUP00L1",
        "authorizationType": "Rbac"
      }
    }
  }
}
EOF

# -------------------- Output --------------------
log "JSON files generated successfully:"
log " - $AUTO_FILE"
log " - $SELFHOSTED_FILE"
