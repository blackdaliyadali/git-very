#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# BASE_ANALYSIS_ROOT_DIR is the root directory where all __ANALYSIS output will go.
# It's passed as the first argument to this script (from the master scan_org_repos.sh),
# or it defaults to a local __ANALYSIS directory if run individually.
BASE_ANALYSIS_ROOT_DIR="${1:-$(pwd)/__ANALYSIS}"

# REPO_NAME is derived from the directory where the script is *run from*
# (e.g., if you are in 'test_keys/', REPO_NAME will be 'test_keys')
REPO_NAME=$(basename "$(pwd)")

# REPO_ANALYSIS_DIR is the specific directory for THIS repository's analysis output
# It will be: /path/to/pentest_workspace/__ANALYSIS/owner_name/repo_name
REPO_ANALYSIS_DIR="${BASE_ANALYSIS_ROOT_DIR}/${REPO_NAME}"

# Ensure the repository-specific analysis directory exists
mkdir -p "${REPO_ANALYSIS_DIR}"

LOG_FILE="${REPO_ANALYSIS_DIR}/all_recovery.log"

echo "--- Starting All Recovery Methods for Repo: ${REPO_NAME} ---" | tee "$LOG_FILE"
echo "Analysis output will be saved to: ${REPO_ANALYSIS_DIR}" | tee -a "$LOG_FILE"
echo "Combined log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# --- Determine the directory where this combined script is located ---
# This ensures we can call the individual recovery scripts correctly,
# regardless of the current working directory.
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# --- 1. Run restore_deleted_from_commits.sh ---
echo "--- Running restore_deleted_from_commits.sh ---" | tee -a "$LOG_FILE"
# Pass the correct analysis directory to the individual script
"${SCRIPT_DIR}/restore_deleted_from_commits.sh" "${REPO_ANALYSIS_DIR}" 2>&1 | tee -a "$LOG_FILE" || { echo "Error: restore_deleted_from_commits.sh failed." | tee -a "$LOG_FILE"; exit 1; }
echo "--- Finished restore_deleted_from_commits.sh ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# --- 2. Run find_unreachable_blobs.sh ---
echo "--- Running find_unreachable_blobs.sh ---" | tee -a "$LOG_FILE"
# Pass the correct analysis directory to the individual script
"${SCRIPT_DIR}/find_unreachable_blobs.sh" "${REPO_ANALYSIS_DIR}" 2>&1 | tee -a "$LOG_FILE" || { echo "Error: find_unreachable_blobs.sh failed." | tee -a "$LOG_FILE"; exit 1; }
echo "--- Finished find_unreachable_blobs.sh ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# --- 3. Run unpack_git_packs.sh ---
echo "--- Running unpack_git_packs.sh ---" | tee -a "$LOG_FILE"
# Pass the correct analysis directory to the individual script
"${SCRIPT_DIR}/unpack_git_packs.sh" "${REPO_ANALYSIS_DIR}" 2>&1 | tee -a "$LOG_FILE" || { echo "Error: unpack_git_packs.sh failed." | tee -a "$LOG_FILE"; exit 1; }
echo "--- Finished unpack_git_packs.sh ---" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "--- All Recovery Methods Completed for Repo: ${REPO_NAME} ---" | tee -a "$LOG_FILE"
echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
