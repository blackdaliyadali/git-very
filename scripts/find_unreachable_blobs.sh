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

# Technique-specific output directory and log file
OUTPUT_DIR="${REPO_ANALYSIS_DIR}/unreachable_blobs"
LOG_FILE="${OUTPUT_DIR}/unreachable_blobs.log"

# Ensure output directories exist
mkdir -p "${OUTPUT_DIR}"

echo "--- Starting Technique 2: Unreachable Blobs for Repo: ${REPO_NAME} ---" | tee "$LOG_FILE"
echo "Output directory: ${OUTPUT_DIR}" | tee -a "$LOG_FILE"
echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Find unreachable blobs
# git fsck --unreachable outputs unreachable blobs and trees.
# We're interested in blobs, which represent file contents.
# grep 'unreachable blob' filters for only blob objects.
# cut -d' ' -f3 extracts the SHA-1 hash.
git fsck --unreachable | grep 'unreachable blob' | cut -d' ' -f3 | while read blob_hash; do
    echo "Found unreachable blob: $blob_hash" | tee -a "$LOG_FILE"

    # Save the blob content to a file named after its hash
    output_filepath="${OUTPUT_DIR}/${blob_hash}"
    git cat-file blob "$blob_hash" > "$output_filepath" 2>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        echo "  Saved blob content to: $output_filepath" | tee -a "$LOG_FILE"
    else
        echo "  Warning: Could not save content for blob $blob_hash." | tee -a "$LOG_FILE"
    fi
done

echo "--- Finished Technique 2: Unreachable Blobs for Repo: ${REPO_NAME} ---" | tee -a "$LOG_FILE"
echo "----------------------------------------------------------------------" | tee -a "$LOG_FILE"
