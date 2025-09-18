#!/bin/bash
set -euo pipefail

# ==========================================================
# Script: generate-linkedService-json.sh
# Purpose: Generate ADF Linked Service JSON files
# ==========================================================

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "ERROR: $1" >&2; exit 1; }

# -------------------- Usage --------------------
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Linked Service JSON configuration for ADF.

OPTIONS:
    -k, --keyvault-name  Key Vault name (required, without https:// and .vault.azure.net)
    -o, --output-dir     Output directory (default: current working directory)
    -h, --help           Show this help message

EXAMPLE:
    $0 -k kv-dm-poc-x1-dev-we-1 -o ./output
EOF
}

# -------------------- Defaults --------------------
OUTPUT_DIR="."
KEYVAULT_NAME=""

# -------------------- Parse args --------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--keyvault-name) KEYVAULT_NAME="$2"; shift 2 ;;
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) show_usage; exit 0 ;;
        *) error_exit "Unknown option: $1" ;;
    esac
done

# -------------------- Validation --------------------
if [[ -z "$KEYVAULT_NAME" ]]; then
    error_exit "Missing required argument: --keyvault-name"
fi

# -------------------- Paths --------------------
LS_DIR="$OUTPUT_DIR/linkedService"
mkdir -p "$LS_DIR"

LS_FILE="$LS_DIR/ls_key_vault.json"

# -------------------- Generate JSON --------------------
log "Generating $LS_FILE"
cat > "$LS_FILE" <<EOF
{
  "name": "ls_key_vault",
  "type": "Microsoft.DataFactory/factories/linkedservices",
  "properties": {
    "annotations": [],
    "type": "AzureKeyVault",
    "typeProperties": {
      "baseUrl": "https://${KEYVAULT_NAME}.vault.azure.net/"
    }
  }
}
EOF

# -------------------- Output --------------------
log "Linked Service JSON generated successfully:"
log " - $LS_FILE"
