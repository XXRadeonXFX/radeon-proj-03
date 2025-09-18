#!/bin/bash
set -e

log() { echo "[Apply] $(date +'%Y-%m-%d %H:%M:%S') $*"; }
error_exit() { echo "❌ [Apply] $1" >&2; exit 1; }

if [ ! -f changed_folders.txt ]; then
  error_exit "changed_folders.txt not found!"
fi

log "🔧 Configuring Git credentials"
git config --global url."https://automation:${ENCODED_PAT}@tetrapak-tpps.visualstudio.com/".insteadOf "https://tetrapak-tpps.visualstudio.com/"
git config --global --list

export ARM_USE_MSI=true
export ARM_CLIENT_ID="2b386df0-8e01-4f94-b6bb-3104a8a8f30c"

export NO_PROXY=blob.core.windows.net,stdmpptfstatesprdwe1.blob.core.windows.net
export TF_VAR_azure_devops_pat=$AZURE_DEVOPS_EXT_PAT
export AZDO_PERSONAL_ACCESS_TOKEN=$AZURE_DEVOPS_EXT_PAT

echo "PAT length: ${#AZURE_DEVOPS_EXT_PAT}"



if [ -n "$AGENT_PROXYURL" ]; then
    echo "Setting HTTP(S) proxy to: $AGENT_PROXYURL"
    export HTTP_PROXY=$AGENT_PROXYURL
    export HTTPS_PROXY=$AGENT_PROXYURL
fi

while read folder; do
  if [ -z "$folder" ]; then continue; fi

  if [ -f "$folder/terragrunt.hcl" ]; then
    log "📁 Running terragrunt apply in $folder"
    cd "$folder" || error_exit "Failed to cd into $folder"
    terragrunt init || error_exit "terragrunt init failed in $folder"
    terragrunt plan -auto-approve || error_exit "terragrunt apply failed in $folder"
    cd - >/dev/null

  elif [ -f "$folder/terraform.tfvars" ]; then
    log "📁 Running terraform apply in $folder"
    cd "$folder" || error_exit "Failed to cd into $folder"

    # Optional: Replace version= with ref= in module sources
   # sed -i 's/version=/ref=/g' main.tf || true


    terraform init -backend-config=backend.config || error_exit "terraform init failed in $folder"
    terraform plan -out plan-to-apply.tfplan -var-file=terraform.tfvars || error_exit "terraform plan failed in $folder"
    terraform show -json plan-to-apply.tfplan > plan-to-apply.tfplan.json
    terraform apply -auto-approve  plan-to-apply.tfplan || error_exit "terraform apply failed in $folder"
    # terraform apply destroy -auto-approve 
    # terraform destroy -auto-approve 

    # Print the new repo URL from Terraform output
    REPO_URL=$(terraform output repository_url 2>/dev/null || echo "")
    BUILD_PIPELINE_URL=$(terraform output build_pipeline_url 2>/dev/null || echo "")
    DEPLOY_PIPELINE_URL=$(terraform output deploy_pipeline_url 2>/dev/null || echo "")


    cd - >/dev/null

  else
    log "⚠️ No terragrunt.hcl or terraform.tfvars in $folder, skipping."
  fi
done < changed_folders.txt
