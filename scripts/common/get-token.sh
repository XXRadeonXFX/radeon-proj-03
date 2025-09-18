#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { echo "❌ $1" >&2; exit 1; }

KEYVAULT_NAME="kv-dm-pp-prd-we-1"
SECRET_NAME="SRVSELUDEVOPS01-PAT"
#SECRET_NAME="DEVOPS-TEMP-TOKEN"
CLIENT_ID="2b386df0-8e01-4f94-b6bb-3104a8a8f30c"

log "🔐 Logging in to Azure using managed identity"
az login --identity --client-id "$CLIENT_ID" >/dev/null || error_exit "Azure login failed"

log "🔑 Retrieving PAT from Azure Key Vault"
PAT=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --query value -o tsv) || error_exit "Failed to retrieve PAT"

echo "PAT length: ${#PAT}"

echo "##vso[task.setvariable variable=PAT;issecret=true]$PAT"

if [[ -z "$PAT" ]]; then
  error_exit "PAT is empty after retrieval from Key Vault."
fi

ENCODED_PAT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$PAT'''))") || error_exit "Failed to encode PAT"
echo "##vso[task.setvariable variable=ENCODED_PAT;issecret=true]$ENCODED_PAT"

