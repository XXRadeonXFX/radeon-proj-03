#!/bin/bash
set -euo pipefail

# ==========================================================
# Script: generate-managedVirtualNetwork-json.sh
# Purpose: Generate ADF Managed Virtual Network JSON files
# ==========================================================

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "ERROR: $1" >&2; exit 1; }

# -------------------- Usage --------------------
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Azure Databricks Managed VNet JSON configuration for ADF.

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
VNET_DIR="$OUTPUT_DIR/managedVirtualNetwork/default"
PE_DIR="$VNET_DIR/managedPrivateEndpoint"

log "Creating directories..."
mkdir -p "$PE_DIR"

# -------------------- Generate default.json --------------------
DEFAULT_FILE="$VNET_DIR/default.json"
log "Generating $DEFAULT_FILE"
cat > "$DEFAULT_FILE" <<EOF
{
  "name": "default",
  "type": "Microsoft.DataFactory/factories/managedVirtualNetworks"
}
EOF

# -------------------- Generate AzureDatabricks.json --------------------
ADB_FILE="$PE_DIR/AzureDatabricks.json"
log "Generating $ADB_FILE"
cat > "$ADB_FILE" <<EOF
{
    "name": "AzureDatabricks",
    "properties": {
        "privateLinkResourceId": "/subscriptions/3271fd7f-3660-4f9c-86f1-17d40810ce49/resourceGroups/rg-dm-databricks-dev-we-1/providers/Microsoft.Databricks/workspaces/dbw-dm-sd-dev-we-1",
        "groupId": "databricks_ui_api"
    }
}
EOF

# -------------------- Output --------------------
log "JSON files generated successfully:"
log " - $DEFAULT_FILE"
log " - $ADB_FILE"
