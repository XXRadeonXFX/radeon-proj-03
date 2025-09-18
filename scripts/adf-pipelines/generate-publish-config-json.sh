#!/bin/bash
set -euo pipefail

# ==========================================================
# Script: generate-publish-config-json.sh
# Purpose: Generate publish_config.json for ADF
# ==========================================================

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "ERROR: $1" >&2; exit 1; }

# -------------------- Usage --------------------
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate publish_config.json file for ADF.

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

# -------------------- Path --------------------
CONFIG_FILE="$OUTPUT_DIR/publish_config.json"
mkdir -p "$OUTPUT_DIR"

# -------------------- Generate JSON --------------------
log "Generating $CONFIG_FILE"
cat > "$CONFIG_FILE" <<EOF
{"publishBranch":"adf_publish","enableGitComment":true,"includeGlobalParamsTemplate":true}
EOF

# -------------------- Output --------------------
log "publish_config.json generated successfully:"
log " - $CONFIG_FILE"
