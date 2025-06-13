#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# BASE_ANALYSIS_ROOT_DIR is the root directory where all __ANALYSIS output will go.
# It's passed as the first argument to this script, or defaults to current __ANALYSIS.
BASE_ANALYSIS_ROOT_DIR="${1:-$(pwd)/__ANALYSIS}"

# REPO_NAME is derived from the directory where the script is *run from*
# (e.g., if you are in 'test_keys/', REPO_NAME will be 'test_keys')
REPO_NAME=$(basename "$(pwd)")

# The specific analysis directory for THIS repository's output
REPO_ANALYSIS_DIR="${BASE_ANALYSIS_ROOT_DIR}/${REPO_NAME}"

# Ensure the repository-specific analysis directory exists
mkdir -p "${REPO_ANALYSIS_DIR}"

OUTPUT_FILE="${REPO_ANALYSIS_DIR}/trufflehog_filesystem_scan_results.json"
LOG_FILE="${REPO_ANALYSIS_DIR}/trufflehog_filesystem_scan.log"

echo "--- Starting TruffleHog Filesystem Scan for Repo: ${REPO_NAME} ---" | tee "$LOG_FILE"
echo "Scanning directory: ${REPO_ANALYSIS_DIR}" | tee -a "$LOG_FILE" # Scan the analysis directory of THIS repo
echo "Results will be saved to: $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Clean up any previous results file
rm -f "$OUTPUT_FILE"

# Run TruffleHog on the filesystem of the current repository's analysis directory
# This includes files recovered by the other scripts (deleted files, unreachable blobs).
# --only-verified flag is removed to prevent hangs and capture all pattern matches.
trufflehog filesystem "${REPO_ANALYSIS_DIR}" \
    --print-avg-detector-time \
    --include-detectors="all" \
    --json \
    > "$OUTPUT_FILE" 2>> "$LOG_FILE" \
    || { echo "Error: TruffleHog Filesystem scan failed. Check logs." | tee -a "$LOG_FILE"; exit 1; }

echo "--- Finished TruffleHog Filesystem Scan for Repo: ${REPO_NAME} ---" | tee -a "$LOG_FILE"
echo "-----------------------------------------------------------------" | tee -a "$LOG_FILE"
