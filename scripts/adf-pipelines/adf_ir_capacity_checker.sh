#!/bin/bash

# Configuration
RESOURCE_GROUP="rg-dm-adf-ir-prd-we-1"
MAX_CAPACITY=100
LOWEST_LINKED_COUNT=$MAX_CAPACITY
BEST_ADF=""
BEST_IR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ADF Integration Runtime Capacity Checker ===${NC}"
echo -e "Resource Group: ${YELLOW}$RESOURCE_GROUP${NC}"
echo -e "Max IR Capacity: ${YELLOW}$MAX_CAPACITY${NC}"
echo ""

# Function to extract IR name from ADF name
get_ir_name() {
    local adf_name=$1
    # Extract suffix from ADF name (e.g., adf-dm-ir-prd-we-1 -> 1)
    local suffix=$(echo "$adf_name" | grep -o '[0-9]*$')
    echo "TADMSELUPOOL$suffix"
}

# Function to get linked count for an integration runtime
get_ir_linked_count() {
    local adf_name=$1
    local ir_name=$2
    
    echo -e "  Checking IR: ${BLUE}$ir_name${NC}"
    
    # Get integration runtime details
    local ir_details=$(az datafactory integration-runtime show \
        --factory-name "$adf_name" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ir_name" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$ir_details" ]; then
        echo -e "    ${RED}Error: Could not retrieve IR details${NC}"
        return 1
    fi
    
    # Get monitoring info to find linked count
    local monitoring_data=$(az datafactory integration-runtime get-monitoring-data \
        --factory-name "$adf_name" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ir_name" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$monitoring_data" ]; then
        echo -e "    ${RED}Error: Could not retrieve monitoring data${NC}"
        return 1
    fi
    
    # Extract linked count (this might need adjustment based on actual API response)
    # The exact JSON path may vary - you might need to adjust this
    local linked_count=$(echo "$monitoring_data" | jq -r '.nodes[0].concurrentJobsLimit // 0' 2>/dev/null)
    
    # Alternative approach - try to get it from the status
    if [ "$linked_count" == "null" ] || [ "$linked_count" == "0" ]; then
        linked_count=$(echo "$monitoring_data" | jq -r '.nodes | length // 0' 2>/dev/null)
    fi
    
    # If still no luck, try to get status info
    if [ "$linked_count" == "null" ] || [ -z "$linked_count" ]; then
        # Get integration runtime status
        local ir_status=$(az datafactory integration-runtime get-status \
            --factory-name "$adf_name" \
            --resource-group "$RESOURCE_GROUP" \
            --name "$ir_name" \
            --output json 2>/dev/null)
        
        if [ $? -eq 0 ] && [ ! -z "$ir_status" ]; then
            # Try to extract linked count from status - adjust path as needed
            linked_count=$(echo "$ir_status" | jq -r '.properties.typeProperties.linkedInfo | length // 0' 2>/dev/null)
        fi
    fi
    
    # Fallback: if we can't get the exact linked count, return a default
    if [ "$linked_count" == "null" ] || [ -z "$linked_count" ] || ! [[ "$linked_count" =~ ^[0-9]+$ ]]; then
        echo -e "    ${YELLOW}Warning: Could not determine linked count, assuming 50${NC}"
        linked_count=50
    fi
    
    echo "$linked_count"
}

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    exit 1
fi

# Check if logged in
az account show &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    echo "Please run: az login"
    exit 1
fi

echo -e "${BLUE}Fetching ADFs from resource group...${NC}"

# Get all ADFs in the resource group
adf_list=$(az datafactory list --resource-group "$RESOURCE_GROUP" --output json)

if [ $? -ne 0 ] || [ -z "$adf_list" ]; then
    echo -e "${RED}Error: Could not retrieve ADFs from resource group $RESOURCE_GROUP${NC}"
    exit 1
fi

# Extract ADF names
adf_names=$(echo "$adf_list" | jq -r '.[].name' 2>/dev/null)

if [ -z "$adf_names" ]; then
    echo -e "${RED}Error: No ADFs found in resource group $RESOURCE_GROUP${NC}"
    exit 1
fi

echo -e "Found ADFs: ${GREEN}$(echo "$adf_names" | wc -l)${NC}"
echo ""

# Iterate through each ADF
while IFS= read -r adf_name; do
    echo -e "${YELLOW}Processing ADF: $adf_name${NC}"
    
    # Get corresponding IR name
    ir_name=$(get_ir_name "$adf_name")
    
    # Get linked count for this IR
    linked_count=$(get_ir_linked_count "$adf_name" "$ir_name")
    
    if [ $? -eq 0 ] && [[ "$linked_count" =~ ^[0-9]+$ ]]; then
        remaining_capacity=$((MAX_CAPACITY - linked_count))
        
        echo -e "  Linked Count: ${GREEN}$linked_count${NC}/$MAX_CAPACITY"
        echo -e "  Remaining Capacity: ${GREEN}$remaining_capacity${NC}"
        
        # Check if this is the best option so far
        if [ "$linked_count" -lt "$LOWEST_LINKED_COUNT" ]; then
            LOWEST_LINKED_COUNT=$linked_count
            BEST_ADF=$adf_name
            BEST_IR=$ir_name
            echo -e "  ${GREEN}✓ New best option!${NC}"
        else
            echo -e "  ${YELLOW}○ Not the best option${NC}"
        fi
    else
        echo -e "  ${RED}✗ Failed to get linked count${NC}"
    fi
    
    echo ""
done <<< "$adf_names"

# Output results
echo -e "${BLUE}=== RESULTS ===${NC}"
if [ ! -z "$BEST_ADF" ]; then
    remaining_capacity=$((MAX_CAPACITY - LOWEST_LINKED_COUNT))
    echo -e "${GREEN}Best ADF Found:${NC}"
    echo -e "  ADF Name: ${YELLOW}$BEST_ADF${NC}"
    echo -e "  IR Name: ${YELLOW}$BEST_IR${NC}"
    echo -e "  Current Linked Count: ${GREEN}$LOWEST_LINKED_COUNT${NC}/$MAX_CAPACITY"
    echo -e "  Available Capacity: ${GREEN}$remaining_capacity${NC}"
    
    # Export as environment variables for potential use in other scripts
    export SELECTED_ADF="$BEST_ADF"
    export SELECTED_IR="$BEST_IR"
    export AVAILABLE_CAPACITY="$remaining_capacity"
    
    echo ""
    echo -e "${BLUE}Environment variables set:${NC}"
    echo -e "  SELECTED_ADF=$SELECTED_ADF"
    echo -e "  SELECTED_IR=$SELECTED_IR"
    echo -e "  AVAILABLE_CAPACITY=$AVAILABLE_CAPACITY"
else
    echo -e "${RED}No suitable ADF/IR found${NC}"
    exit 1
fi