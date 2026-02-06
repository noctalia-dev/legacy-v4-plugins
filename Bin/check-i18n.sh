#!/bin/bash

# Check i18n translation coverage script
# Identifies plugins that have English strings (en.json) but are missing the target language translation.

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default target language is zh-CN, can be overridden by first argument
TARGET_LANG="${1:-zh-CN}"

echo -e "${BLUE}=== Checking i18n coverage for language: ${TARGET_LANG} ===${NC}\n"

# Check if we are in the project root
if [ ! -d "Bin" ]; then
    echo -e "${YELLOW}Warning: Please run this script from the project root directory.${NC}"
fi

# Initialize counters and arrays
total_plugins=0
present_count=0
missing_count=0
missing_plugins=()
present_plugins=()

# Find all en.json files inside i18n directories
# We assume the structure is: ./PluginName/i18n/en.json
# We use 'find' for compatibility
while IFS= read -r en_file; do
    # Extract plugin directory path (remove /i18n/en.json)
    plugin_dir=$(dirname $(dirname "$en_file"))
    plugin_name=$(basename "$plugin_dir")
    
    # Construct target translation file path
    target_file="${plugin_dir}/i18n/${TARGET_LANG}.json"
    
    ((total_plugins++))
    
    if [ -f "$target_file" ]; then
        ((present_count++))
        present_plugins+=("$plugin_name")
        echo -e "${GREEN}✓${NC} ${plugin_name}"
    else
        ((missing_count++))
        missing_plugins+=("$plugin_name")
        echo -e "${RED}✗${NC} ${plugin_name}"
    fi
    
done < <(find . -type f -path "*/i18n/en.json" | sort)

# Calculate coverage
if [ "$total_plugins" -gt 0 ]; then
    # Bash doesn't support floating point arithmetic natively, use awk
    coverage=$(awk "BEGIN {printf \"%.1f\", ($present_count / $total_plugins) * 100}")
else
    coverage=0
fi

echo -e "\n${BLUE}=== Statistics ===${NC}"
echo "Total plugins (with i18n): ${total_plugins}"
echo -e "${GREEN}Translated: ${present_count}${NC}"
echo -e "${RED}Missing: ${missing_count}${NC}"
echo "Coverage: ${coverage}%"

# List missing plugins if any
if [ "$missing_count" -gt 0 ]; then
    echo -e "\n${YELLOW}=== Plugins missing ${TARGET_LANG} translation (${missing_count}) ===${NC}"
    for plugin in "${missing_plugins[@]}"; do
        echo "  - ${plugin}"
    done
fi

# Exit with error if missing translations found
if [ "$missing_count" -eq 0 ]; then
    exit 0
else
    exit 1
fi
