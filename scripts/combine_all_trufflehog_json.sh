#!/bin/bash

# Exit on first error
set -e

# --- Configuration ---
PENTEST_WORKSPACE="$(pwd)"
GLOBAL_ANALYSIS_ROOT="${PENTEST_WORKSPACE}/__ANALYSIS"
OUTPUT_FILE="${PENTEST_WORKSPACE}/all_combined_trufflehog_results.json"
ERROR_LOG="${PENTEST_WORKSPACE}/json_combine_errors.log"

echo "--- Starting JSON Combination Process ---" | tee "$ERROR_LOG"
echo "Combining results from: ${GLOBAL_ANALYSIS_ROOT}/*/*/*/trufflehog_all_scan_results.json" | tee -a "$ERROR_LOG"
echo "Output will be saved to: $OUTPUT_FILE" | tee -a "$ERROR_LOG"
echo "Errors and warnings will be logged to: $ERROR_LOG" | tee -a "$ERROR_LOG"
echo "" | tee -a "$ERROR_LOG"

# Temporary file to store the list of valid JSON file paths to feed to jq
TEMP_VALID_JSON_LIST=$(mktemp)
# Ensure the temporary file is cleaned up when the script exits
trap "rm -f \"$TEMP_VALID_JSON_LIST\"" EXIT

# Find all potential result files using the correct three-asterisk pattern for your structure
ALL_RESULT_FILES=$(find "$GLOBAL_ANALYSIS_ROOT" -name "trufflehog_all_scan_results.json" -print)

if [ -z "$ALL_RESULT_FILES" ]; then
    echo "No 'trufflehog_all_scan_results.json' files found in ${GLOBAL_ANALYSIS_ROOT}." | tee -a "$ERROR_LOG"
    exit 0
fi

echo "--- Validating and Preparing Individual JSON Files ---" | tee -a "$ERROR_LOG"

# Validate and prepare each file for jq
for file in $ALL_RESULT_FILES; do
    echo "Processing: $file" | tee -a "$ERROR_LOG"
    
    file_content=$(cat "$file") # Read the entire file content once
    
    # Check if the file content is already a valid JSON array
    if echo "$file_content" | jq -e '.[0]' > /dev/null 2>&1; then
        # It's an array, good to go. No modification needed.
        true
    # Else, check if it's a valid JSON object (or scalar)
    elif echo "$file_content" | jq -e '.' > /dev/null 2>&1; then
        # It's valid JSON, but not an array (likely a single object). Wrap it in an array.
        echo "WARNING: '$file' is a valid JSON object (or scalar), but not an array. Wrapping content in '[]'." | tee -a "$ERROR_LOG"
        echo "[$file_content]" > "$file"
    else
        # It's completely invalid JSON or empty. Replace with an empty array.
        echo "WARNING: '$file' is NOT valid JSON or is empty. Replacing content with '[]'." | tee -a "$ERROR_LOG"
        echo "[]" > "$file" # Overwrite invalid content with an empty JSON array
    fi
    
    # Add the path of the (now guaranteed valid and array-formatted) file to our temporary list
    echo "$file" >> "$TEMP_VALID_JSON_LIST"
done

echo "" | tee -a "$ERROR_LOG"
echo "--- Attempting to Combine All Valid JSON Results ---" | tee -a "$ERROR_LOG"

# Use xargs to pass all valid file paths from the temporary list to jq
xargs -a "$TEMP_VALID_JSON_LIST" jq -s 'add' > "$OUTPUT_FILE" 2>> "$ERROR_LOG"

if [ $? -eq 0 ]; then
    echo "--- JSON Combination Completed Successfully! ---" | tee -a "$ERROR_LOG"
    echo "Combined results saved to: $OUTPUT_FILE" | tee -a "$ERROR_LOG"
else
    echo "ERROR: Failed to combine JSON results. Check '$ERROR_LOG' for details." | tee -a "$ERROR_LOG"
fi

echo "--- Process Finished ---" | tee -a "$ERROR_LOG"
