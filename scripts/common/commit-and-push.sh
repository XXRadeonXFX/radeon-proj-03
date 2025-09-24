#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "❌ $1" >&2; exit 1; }

RESOURCE_NAME=$1
BRANCH_NAME=$2
INFRA_REPO_NAME=$3
KEYVAULT_NAME="kv-dm-pp-prd-we-1"
SECRET_NAME="SRVSELUDEVOPS01-PAT"
CLIENT_ID="2b386df0-8e01-4f94-b6bb-3104a8a8f30c"

log "🔧 Configuring Git"
git config --global credential.helper "" || error_exit "Git config failed"
git config user.email "SRVSELUDEVOPS01@tetrapak.com" || error_exit "Git config email failed"
git config user.name "Automation-Pipeline" || error_exit "Git config name failed"

log "📦 Checking for changes to commit first"
git add . || error_exit "Git add failed"

# Check if there are any changes to commit BEFORE creating branches
if git diff --cached --quiet; then
  log "✅ No changes detected. Working tree is clean."
  log "🎯 This is normal - no new files were generated or existing files were not modified."
  log "📋 Skipping all branch creation, commit, and push operations."
  log "✅ Script completed successfully - nothing to do."
  exit 0
fi

log "📝 Changes detected, proceeding with branch creation and commit..."

log "🌿 Creating/switching to branch: $BRANCH_NAME"
if [[ -n "$(git ls-remote --heads origin $BRANCH_NAME)" ]]; then
  log "Branch exists on remote, fetching and switching..."
  git fetch --all || error_exit "Failed to fetch branch $BRANCH_NAME"
  git switch "$BRANCH_NAME" || error_exit "Failed to switch to branch $BRANCH_NAME"
  git pull origin "$BRANCH_NAME" || error_exit "Failed to pull latest changes"
else
  log "Branch does not exist on remote, creating new branch..."
  git checkout -b "$BRANCH_NAME" || error_exit "Failed to create branch $BRANCH_NAME"
fi

# Re-stage changes after branch switch
git add . || error_exit "Git add failed after branch switch"

log "📝 Committing changes..."
git commit -m "Add new configuration to $RESOURCE_NAME - $(date +'%Y-%m-%d %H:%M:%S')" || error_exit "Git commit failed"

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

log "🚀 Pushing changes to remote"
git push origin "$BRANCH_NAME" || error_exit "Git push failed"

log "✅ Script completed successfully - changes committed and pushed."