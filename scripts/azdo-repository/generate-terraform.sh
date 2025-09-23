#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "❌ $1" >&2; exit 1; }

REPO_NAME=$1
PROJECT_NAME=$2
BUILD_PIPELINE=$3
DEPLOY_PIPELINE=$4

if [[ -z "$REPO_NAME" ]]; then
  error_exit "Usage: $0 <REPO_NAME> <PROJECT_NAME>"
fi

log "Parameters used for Terraform:"
log "  project_name: $PROJECT_NAME"
log "  repo_name: $REPO_NAME"

log "📁 Creating directory: $REPO_NAME"
mkdir -p "$REPO_NAME" || error_exit "Failed to create directory $REPO_NAME"

log "📝 Copy files from blueprint."
cp -r blueprint-tf/* $REPO_NAME

log "📝 Generating terraform.tfvars"
cat <<EOF > "$REPO_NAME/terraform.tfvars"
project_name = "$PROJECT_NAME"
repo_name    = "$REPO_NAME"
build_pipeline = $BUILD_PIPELINE
deploy_pipeline = $DEPLOY_PIPELINE
EOF

log "📝 Generating backend.config"
cat <<EOF > "$REPO_NAME/backend.config"
subscription_id      = "2ec78152-def8-423f-a264-bebbf6cdd8e8"
resource_group_name  = "rg-dm-pp-tfbackend-we-1"
storage_account_name = "stdmpptfstatesprdwe1"
container_name       = "states"
key                  = "pnp-repositories/$REPO_NAME/terraform.tfstate"
use_msi              = true
use_azuread_auth     = true

EOF

log "✅ tfvars.tf and backend.config generated."