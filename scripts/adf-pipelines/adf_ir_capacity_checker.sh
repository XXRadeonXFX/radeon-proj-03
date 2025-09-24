#!/bin/bash

# Configuration from environment variables
RESOURCE_GROUP="${ADF_RESOURCE_GROUP:-rg-dm-adf-ir-prd-we-1}"
TARGET_SUBSCRIPTION_ID="${TARGET_SUBSCRIPTION_ID:-48fbff7b-2f91-4f9c-b299-fe4fb7a8a423}"
CLIENT_ID="${AZURE_CLIENT_ID:-2b386df0-8e01-4f94-b6bb-3104a8a8f30c}"
MAX_CAPACITY="${IR_MAX_CAPACITY:-100}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${2:-$NC}$1${NC}"
}

error_exit() {
    log "$1" "$RED"
    exit 1
}

# Login with managed identity
log "=== ADF IR Capacity Checker ===" "$BLUE"
az login --identity --client-id "$CLIENT_ID" --output none 2>/dev/null || error_exit "Login failed!"

# Set subscription
az account set --subscription "$TARGET_SUBSCRIPTION_ID" --output none 2>/dev/null || {
    log "Target subscription not found, searching in available subscriptions..." "$YELLOW"
    
    # Find subscription with the resource group
    FOUND_SUB=$(az account list --query "[?contains(keys(@), 'id')].[id, name]" -o tsv 2>/dev/null | while read -r sub_id sub_name; do
        az account set --subscription "$sub_id" --output none 2>/dev/null
        if az group exists --name "$RESOURCE_GROUP" --output tsv 2>/dev/null | grep -q "true"; then
            echo "$sub_id"
            break
        fi
    done)
    
    [ -z "$FOUND_SUB" ] && error_exit "Resource group not found in any subscription"
    az account set --subscription "$FOUND_SUB" --output none 2>/dev/null
}

# Verify resource group exists
az group exists --name "$RESOURCE_GROUP" --output tsv 2>/dev/null | grep -q "true" || error_exit "Resource group does not exist"

# Get Data Factories
log "\n=== ANALYZING INTEGRATION RUNTIME CAPACITY ===" "$BLUE"

ADF_LIST=$(az datafactory list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null)
[ -z "$ADF_LIST" ] && error_exit "No Data Factories found"

BEST_ADF=""
BEST_IR=""
LOWEST_LINKED_COUNT=999
RESULTS=()

# Process each ADF
while read -r ADF_NAME; do
    [ -z "$ADF_NAME" ] && continue
    
    # Determine IR name based on ADF name
    if [[ $ADF_NAME =~ ([0-9]+)$ ]]; then
        SUFFIX="${BASH_REMATCH[1]}"
        IR_NAME="TADMSELUPOOL${SUFFIX}"
    else
        IR_NAME="TADMSELUPOOL1"
    fi
    
    log "\nProcessing ADF: $ADF_NAME" "$YELLOW"
    log "  Target IR: $IR_NAME"
    
    # Get IR status and linked count
    IR_STATUS=$(az datafactory integration-runtime get-status \
        --resource-group "$RESOURCE_GROUP" \
        --factory-name "$ADF_NAME" \
        --integration-runtime-name "$IR_NAME" \
        --query "properties.links" \
        -o json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ "$IR_STATUS" != "null" ] && [ "$IR_STATUS" != "[]" ]; then
        LINKED_COUNT=$(echo "$IR_STATUS" | jq length 2>/dev/null || echo 0)
    else
        LINKED_COUNT=0
    fi
    
    AVAILABLE_CAPACITY=$((MAX_CAPACITY - LINKED_COUNT))
    
    log "    Linked Count: $LINKED_COUNT" "$GREEN"
    log "    Available Capacity: $AVAILABLE_CAPACITY" "$GREEN"
    
    # Track best option (lowest linked count)
    if [ "$LINKED_COUNT" -lt "$LOWEST_LINKED_COUNT" ]; then
        LOWEST_LINKED_COUNT=$LINKED_COUNT
        BEST_ADF=$ADF_NAME
        BEST_IR=$IR_NAME
        log "    *** NEW BEST OPTION: $BEST_IR with $LINKED_COUNT linked factories ***" "$GREEN"
    fi
    
    # Store results for summary
    RESULTS+=("$ADF_NAME|$IR_NAME|$LINKED_COUNT|$AVAILABLE_CAPACITY")
    
done <<< "$ADF_LIST"

# Display results
log "\n=== CAPACITY ANALYSIS RESULTS ===" "$BLUE"
for result in "${RESULTS[@]}"; do
    IFS='|' read -r adf ir linked_count avail_capacity <<< "$result"
    log "ADF: $adf"
    log "  IR: $ir"
    log "  Linked Count: $linked_count"
    log "  Available Capacity: $avail_capacity"
    echo
done

# Show recommendation
if [ -n "$BEST_ADF" ] && [ -n "$BEST_IR" ]; then
    BEST_AVAILABLE_CAPACITY=$((MAX_CAPACITY - LOWEST_LINKED_COUNT))
    
    log "=== RECOMMENDED SELECTION ===" "$GREEN"
    log "Selected ADF: $BEST_ADF" "$GREEN"
    log "Selected IR: $BEST_IR" "$GREEN"
    log "Linked Count: $LOWEST_LINKED_COUNT" "$GREEN"
    log "Available Capacity: $BEST_AVAILABLE_CAPACITY" "$GREEN"
    
    # Set Azure DevOps pipeline variables
    echo "##vso[task.setvariable variable=SELECTED_ADF;isOutput=true]$BEST_ADF"
    echo "##vso[task.setvariable variable=SELECTED_IR;isOutput=true]$BEST_IR"
    echo "##vso[task.setvariable variable=AVAILABLE_CAPACITY;isOutput=true]$BEST_AVAILABLE_CAPACITY"
    echo "##vso[task.setvariable variable=IR_LINKED_COUNT;isOutput=true]$LOWEST_LINKED_COUNT"
    
    log "\nPipeline variables set successfully:" "$GREEN"
    log "  SELECTED_ADF = $BEST_ADF"
    log "  SELECTED_IR = $BEST_IR"
    log "  AVAILABLE_CAPACITY = $BEST_AVAILABLE_CAPACITY"
    log "  IR_LINKED_COUNT = $LOWEST_LINKED_COUNT"
else
    error_exit "No suitable ADF/IR combination found"
fi

log "\n=== ADF IR CAPACITY ANALYSIS COMPLETE ===" "$GREEN"