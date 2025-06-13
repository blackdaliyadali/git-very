#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# BASE_ANALYSIS_ROOT_DIR is the root directory where all __ANALYSIS output will go.
# It's passed as the first argument to this script, or defaults to current __ANALYSIS.
BASE_ANALYSIS_ROOT_DIR="${1:-$(pwd)/__ANALYSIS}"

# REPO_NAME is derived from the directory where the script is *run from*
REPO_NAME=$(basename "$(pwd)")

# The specific analysis directory for THIS repository's output
REPO_ANALYSIS_DIR="${BASE_ANALYSIS_ROOT_DIR}/${REPO_NAME}"

# Log file for this technique
LOG_FILE="${REPO_ANALYSIS_DIR}/unpack_objects.log"

# Ensure the analysis directory exists for logs
mkdir -p "${REPO_ANALYSIS_DIR}"

echo "--- Starting Technique 3: Unpacking Pack Files for Repo: ${REPO_NAME} ---" | tee "$LOG_FILE"
echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Find all pack files in the current repository's .git/objects/pack directory
PACK_FILES=$(find .git/objects/pack -name "*.pack")

if [ -z "$PACK_FILES" ]; then
    echo "No pack files found in .git/objects/pack." | tee -a "$LOG_FILE"
else
    for PACK_FILE in $PACK_FILES; do
        echo " Processing pack file: $PACK_FILE" | tee -a "$LOG_FILE"

        # Git unpack-objects unpacks objects from a pack file into the .git/objects/ directory
        # It's run with --strict to ensure integrity, but output is often minimal.
        # This command mainly populates .git/objects/ with loose objects, making them accessible.
        # It doesn't create user-readable files directly in your analysis output folder,
        # but ensures these objects are available for other git commands (like cat-file)
        # if they were previously only in pack files.
        git unpack-objects < "$PACK_FILE" 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            echo "  Warning: Failed to unpack objects from $PACK_FILE." | tee -a "$LOG_FILE"
        fi
    done
fi

echo "--- Finished Technique 3: Unpacking Pack Files for Repo: ${REPO_NAME} ---" | tee -a "$LOG_FILE"
echo "------------------------------------------------------------------------" | tee -a "$LOG_FILE"
