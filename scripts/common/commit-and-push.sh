#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "❌ $1" >&2; exit 1; }

REPO_NAME=$1
TARGET_DIR=$2
BRANCH_NAME="$REPO_NAME"
KEYVAULT_NAME="kv-dm-pp-prd-we-1"
SECRET_NAME="SRVSELUDEVOPS01-PAT"
CLIENT_ID="2b386df0-8e01-4f94-b6bb-3104a8a8f30c"

log "🔧 Configuring Git"
git config --global credential.helper "" || error_exit "Git config failed"
git config user.email "SRVSELUDEVOPS01@tetrapak.com" || error_exit "Git config email failed"
git config user.name "Automation-Pipeline" || error_exit "Git config name failed"

log "🌿 Creating new branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME" || error_exit "Failed to create branch $BRANCH_NAME"

log "📦 Staging and committing changes"
git add . || error_exit "Git add failed"
git commit -m "Add new configuration to $REPO_NAME." || error_exit "Git commit failed"

log "🔐 Logging in to Azure using managed identity"
az login --identity --client-id "$CLIENT_ID" >/dev/null || error_exit "Azure login failed"

log "🔑 Retrieving PAT from Azure Key Vault"
PAT=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --query value -o tsv) || error_exit "Failed to retrieve PAT"

if [[ -z "$PAT" ]]; then
  error_exit "PAT is empty after retrieval from Key Vault."
fi

ENCODED_PAT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$PAT'''))") || error_exit "Failed to encode PAT"
echo "##vso[task.setvariable variable=ENCODED_PAT;issecret=true]$ENCODED_PAT"

log "🌐 Updating Git remote URL with encoded PAT"
git remote set-url origin "https://anything:${ENCODED_PAT}@dev.azure.com/tetrapak-tpps/Platform%20and%20Process/_git/pnp-deploy-repo-automation" || error_exit "Failed to set git remote URL"

log "🚀 Pushing branch to remote"
git push origin "$BRANCH_NAME" || error_exit "Git push failed"
