#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "ERROR: $1" >&2; exit 1; }

REPO_NAME=$1
TARGET_DIR=$2
BRANCH_NAME=$3
KEYVAULT_NAME="kv-dm-pp-prd-we-1"
SECRET_NAME="SRVSELUDEVOPS01-PAT"
CLIENT_ID="2b386df0-8e01-4f94-b6bb-3104a8a8f30c"

echo "REPO NAME = $REPO_NAME"
echo "BRANCH NAME = $BRANCH_NAME"

# ----------------- Configure Git -----------------
log "Configuring Git"
git config --global credential.helper "" || error_exit "Git config failed"
git config user.email "SRVSELUDEVOPS01@tetrapak.com" || error_exit "Git config email failed"
git config user.name "Automation-Pipeline" || error_exit "Git config name failed"

# ----------------- Azure Login -----------------
log "Logging in to Azure using managed identity"
az login --identity --client-id "$CLIENT_ID" >/dev/null || error_exit "Azure login failed"

log "Retrieving PAT from Azure Key Vault"
PAT=$(az keyvault secret show \
    --vault-name "$KEYVAULT_NAME" \
    --name "$SECRET_NAME" \
    --query value -o tsv) || error_exit "Failed to retrieve PAT"

if [[ -z "$PAT" ]]; then
  error_exit "PAT is empty after retrieval from Key Vault."
fi

ENCODED_PAT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$PAT'''))") \
    || error_exit "Failed to encode PAT"

echo "##vso[task.setvariable variable=ENCODED_PAT;issecret=true]$ENCODED_PAT"

log "Updating Git remote URL with encoded PAT"
git remote set-url origin "https://anything:${ENCODED_PAT}@dev.azure.com/tetrapak-tpps/Data%20Management/_git/$REPO_NAME" \
    || error_exit "Failed to set git remote URL"

# ----------------- Check for uncommitted changes first -----------------
log "Checking for uncommitted changes"
if ! git diff --quiet || ! git diff --cached --quiet; then
    log "Found uncommitted changes. Stashing them temporarily."
    git stash push -m "Temporary stash before branch operations - $(date)" || error_exit "Failed to stash changes"
    STASH_CREATED=true
else
    log "No uncommitted changes detected"
    STASH_CREATED=false
fi

# ----------------- Branch Handling -----------------
log "Fetching remote references"
git fetch origin || log "No remote refs found yet, continuing."

# Ensure main branch exists before anything else
if ! git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    log "No 'main' branch exists in remote. Creating it as default."
    git checkout --orphan main || error_exit "Failed to create orphan main branch"
    git commit --allow-empty -m "Initial commit for $REPO_NAME" || error_exit "Failed to create initial commit"
    git push -u origin main || error_exit "Failed to push main branch"
    log "'main' branch created and pushed."
fi

# Now handle the target branch (e.g., adf_publish)
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    log "Local branch $BRANCH_NAME exists. Checking out."
    git checkout "$BRANCH_NAME" || error_exit "Failed to checkout local branch $BRANCH_NAME"
    
    # Try to pull latest changes, but don't fail if remote doesn't exist yet
    if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
        git pull origin "$BRANCH_NAME" || log "Warning: Failed to pull latest changes from $BRANCH_NAME"
    else
        log "Remote branch $BRANCH_NAME doesn't exist yet"
    fi
elif git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
    log "Remote branch $BRANCH_NAME exists. Checking out."
    git checkout -b "$BRANCH_NAME" origin/"$BRANCH_NAME" \
        || error_exit "Failed to checkout remote branch $BRANCH_NAME"
else
    log "Branch $BRANCH_NAME does not exist. Creating it locally."
    git checkout -b "$BRANCH_NAME" || error_exit "Failed to create branch $BRANCH_NAME"
    git push -u origin "$BRANCH_NAME" || error_exit "Failed to push new branch $BRANCH_NAME"
fi

# ----------------- Restore stashed changes -----------------
if [ "$STASH_CREATED" = true ]; then
    log "Restoring stashed changes"
    if git stash list | grep -q "stash@{0}"; then
        git stash pop || {
            log "Warning: Failed to apply stash cleanly. Checking stash contents..."
            git stash show -p || log "Could not show stash contents"
            error_exit "Failed to restore stashed changes"
        }
    else
        log "Warning: No stash found to restore"
    fi
fi

# ----------------- Apply Changes -----------------
log "Staging all changes"
git add . || error_exit "Git add failed"

if git diff --cached --quiet; then
    log "No changes detected. Nothing to commit."
else
    log "Committing changes"
    git commit -m "Update configuration for $REPO_NAME - $(date +'%Y-%m-%d %H:%M:%S')" || error_exit "Git commit failed"
    
    log "Pushing changes to remote branch $BRANCH_NAME"
    git push origin "$BRANCH_NAME" || error_exit "Git push failed"
    
    log "Successfully pushed changes to $BRANCH_NAME"
fi

log "Script completed successfully."