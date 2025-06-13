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
OUTPUT_DIR="${REPO_ANALYSIS_DIR}/deleted_from_commits"
LOG_FILE="${OUTPUT_DIR}/deleted_files.log"

# Ensure output directories exist
mkdir -p "${OUTPUT_DIR}"

echo "--- Starting Technique 1: Deleted Files from Commits for Repo: ${REPO_NAME} ---" | tee "$LOG_FILE"
echo "Output directory: ${OUTPUT_DIR}" | tee -a "$LOG_FILE"
echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Iterate over all commits in reverse chronological order
# Format: --pretty=format:"%H" outputs only the commit hash
git rev-list --all | while read commit_hash; do
    echo "Processing commit: $commit_hash" | tee -a "$LOG_FILE"

    # Get the parent commit hash
    parent_commit=$(git rev-parse "$commit_hash^" 2>/dev/null)

    if [ -z "$parent_commit" ]; then
        echo " No parent commit found (initial commit). Skipping." | tee -a "$LOG_FILE"
        continue
    fi

    # Compare the current commit with its parent to find deleted files
    # --diff-filter=D shows only deleted files
    # --name-only shows only the file names
    git diff --diff-filter=D --name-only "$parent_commit" "$commit_hash" | while read deleted_file; do
        if [ -n "$deleted_file" ]; then
            echo " Found deleted file: $deleted_file in commit $commit_hash" | tee -a "$LOG_FILE"

            # Reconstruct the file content from the parent commit
            # git show <parent_commit>:<path/to/deleted_file>
            # Use 'sed' to escape slashes in the filename for the output filename,
            # and replace slashes with underscores to avoid creating subdirectories.
            # Append commit hash to the filename to ensure uniqueness and context.
            sanitized_filename=$(echo "$deleted_file" | sed 's/\//___/g' | sed 's/^-/_/g') # Replaces / with ___ and handles leading -
            output_filepath="${OUTPUT_DIR}/${commit_hash}___${sanitized_filename}"

            git show "$parent_commit":"$deleted_file" > "$output_filepath" 2>> "$LOG_FILE"
            if [ $? -eq 0 ]; then
                echo "  Restored to: $output_filepath" | tee -a "$LOG_FILE"
            else
                echo "  Warning: Could not restore $deleted_file from commit $parent_commit." | tee -a "$LOG_FILE"
            fi
        fi
    done
done

echo "--- Finished Technique 1: Deleted Files from Commits for Repo: ${REPO_NAME} ---" | tee -a "$LOG_FILE"
echo "--------------------------------------------------------------------------------" | tee -a "$LOG_FILE"
