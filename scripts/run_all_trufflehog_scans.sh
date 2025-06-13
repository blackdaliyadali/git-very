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

FINAL_OUTPUT_FILE="${REPO_ANALYSIS_DIR}/trufflehog_all_scan_results.json"
LOG_FILE="${REPO_ANALYSIS_DIR}/trufflehog_all_scans.log"

# Temporary files to store individual scan results before merging
# These will be deleted at the end of the script.
TEMP_GIT_RESULTS="${REPO_ANALYSIS_DIR}/.tmp_trufflehog_git_results.json"
TEMP_FS_RESULTS="${REPO_ANALYSIS_DIR}/.tmp_trufflehog_fs_results.json"

echo "--- Starting All TruffleHog Scans for Repo: ${REPO_NAME} ---" | tee "$LOG_FILE"
echo "Combined results will be saved to: $FINAL_OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "Combined log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Clean up any previous temporary files and final output file to ensure a clean run
rm -f "$TEMP_GIT_RESULTS" "$TEMP_FS_RESULTS" "$FINAL_OUTPUT_FILE"

# --- 1. Run TruffleHog Git Scan ---
echo "--- Running TruffleHog Git Scan on repository history ---" | tee -a "$LOG_FILE"
# TruffleHog's JSON output (STDOUT) goes to a temporary file
# TruffleHog's log/progress messages (STDERR) go to the main log file
trufflehog git file://. \
    --print-avg-detector-time \
    --include-detectors="all" \
    --json \
    > "$TEMP_GIT_RESULTS" 2>> "$LOG_FILE" \
    || { echo "Error: TruffleHog Git scan failed. Check logs in $LOG_FILE" | tee -a "$LOG_FILE"; exit 1; }
echo "--- Finished TruffleHog Git Scan ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# --- 2. Run TruffleHog Filesystem Scan on Recovered Data ---
echo "--- Running TruffleHog Filesystem Scan on recovered data in ${REPO_ANALYSIS_DIR} ---" | tee -a "$LOG_FILE"
# Scan the entire REPO_ANALYSIS_DIR, which includes recovered blobs and deleted files specific to this repo.
# TruffleHog's JSON output (STDOUT) goes to a temporary file
# TruffleHog's log/progress messages (STDERR) go to the main log file
trufflehog filesystem "${REPO_ANALYSIS_DIR}" \
    --print-avg-detector-time \
    --include-detectors="all" \
    --json \
    > "$TEMP_FS_RESULTS" 2>> "$LOG_FILE" \
    || { echo "Error: TruffleHog Filesystem scan failed. Check logs in $LOG_FILE" | tee -a "$LOG_FILE"; exit 1; }
echo "--- Finished TruffleHog Filesystem Scan ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# --- Combine Results using jq ---
echo "--- Combining scan results using jq ---" | tee -a "$LOG_FILE"
# Ensure temporary files are valid JSON arrays, defaulting to an empty array if a file is empty or not created
GIT_JSON=$(cat "$TEMP_GIT_RESULTS" 2>/dev/null || echo "[]")
FS_JSON=$(cat "$TEMP_FS_RESULTS" 2>/dev/null || echo "[]")

# Merge the two JSON arrays into one using jq's 'add' filter (works on arrays)
# If one or both files were empty/invalid, we default to '[]', so 'add' still works
echo "$GIT_JSON" "$FS_JSON" | jq -s 'add' > "$FINAL_OUTPUT_FILE" \
    || { echo "Error: Failed to combine JSON results using jq. Check logs." | tee -a "$LOG_FILE"; exit 1; }
echo "--- Results combined successfully into $FINAL_OUTPUT_FILE ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# --- Clean up temporary files ---
echo "--- Cleaning up temporary files ---" | tee -a "$LOG_FILE"
rm -f "$TEMP_GIT_RESULTS" "$TEMP_FS_RESULTS"
echo "--- Temporary files removed ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "--- All TruffleHog Scans Completed for Repo: ${REPO_NAME} ---" | tee -a "$LOG_FILE"
echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
