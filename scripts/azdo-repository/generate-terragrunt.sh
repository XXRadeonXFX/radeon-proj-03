#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "❌ $1" >&2; exit 1; }

REPO_NAME=$1
PROJECT_NAME=$2

log "Parameters used for terragrunt.hcl:"
log "  project_name: $PROJECT_NAME"
log "  repo_name: $REPO_NAME"

log "📁 Creating directory: $REPO_NAME"
mkdir -p "$REPO_NAME" || error_exit "Failed to create directory $REPO_NAME"

log "📝 Generating terragrunt.hcl"
cat <<EOF > "$REPO_NAME/terragrunt.hcl"
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

inputs = {
  project_name = "$PROJECT_NAME"
  repo_name    = "$REPO_NAME"
}
EOF

log "📝 Generating main.tf"
cat <<EOF > "$REPO_NAME/main.tf"
terraform {
  backend "azurerm" {}
}
EOF

log "✅ terragrunt.hcl and main.tf generated."