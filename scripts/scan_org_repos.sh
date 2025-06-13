#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# PENTEST_WORKSPACE is the directory where you run this script from
PENTEST_WORKSPACE="$(pwd)"
GLOBAL_LOG_FILE="${PENTEST_WORKSPACE}/organization_wide_scan.log"
CLONED_REPOS_DIR="${PENTEST_WORKSPACE}/cloned_repos" # New directory for all cloned repos
GLOBAL_ANALYSIS_ROOT="${PENTEST_WORKSPACE}/__ANALYSIS" # Central directory for all analysis output

echo "--- Starting Organization-Wide Repository Scan (including members' public repos) ---" | tee "$GLOBAL_LOG_FILE"
echo "Scan started at: $(date)" | tee -a "$GLOBAL_LOG_FILE"
echo "Cloned repositories will be stored in: ${CLONED_REPOS_DIR}" | tee -a "$GLOBAL_LOG_FILE"
echo "All analysis results will be stored in: ${GLOBAL_ANALYSIS_ROOT}" | tee -a "$GLOBAL_LOG_FILE"
echo "Global log for this entire process: $GLOBAL_LOG_FILE" | tee -a "$GLOBAL_LOG_FILE"
echo "" | tee -a "$GLOBAL_LOG_FILE"

# --- Input Validation and Organization Name Extraction ---
ORG_URL="$1" # Get the organization URL from the first command-line argument

if [ -z "$ORG_URL" ]; then
    echo "Error: Please provide the GitHub organization/user URL as an argument." | tee -a "$GLOBAL_LOG_FILE"
    echo "Usage: ./scan_org_repos.sh <github.com/orgname_or_user_name>" | tee -a "$GLOBAL_LOG_FILE"
    echo "Example: ./scan_org_repos.sh https://github.com/trufflesecurity" | tee -a "$GLOBAL_LOG_FILE"
    echo "Or:      ./scan_org_repos.sh github.com/octocat" | tee -a "$GLOBAL_LOG_FILE"
    exit 1
fi

# Extract the organization/user name from the provided URL using regular expressions
if [[ "$ORG_URL" =~ ^https?://github.com/([^/]+)/?$ ]]; then
    ORG_NAME="${BASH_REMATCH[1]}"
elif [[ "$ORG_URL" =~ ^github.com/([^/]+)/?$ ]]; then
    ORG_NAME="${BASH_REMATCH[1]}"
else
    echo "Error: Invalid GitHub organization/user URL format: $ORG_URL" | tee -a "$GLOBAL_LOG_FILE"
    echo "Expected format: github.com/name or https://github.com/name" | tee -a "$GLOBAL_LOG_FILE"
    exit 1
fi

echo "Targeting GitHub Organization/User: ${ORG_NAME}" | tee -a "$GLOBAL_LOG_FILE"
echo "" | tee -a "$GLOBAL_LOG_FILE"

# --- Pre-Checks ---
# 1. Check for GitHub CLI (gh) installation
if ! command -v gh &> /dev/null
then
    echo "Error: GitHub CLI (gh) is not installed. Please install it to proceed." | tee -a "$GLOBAL_LOG_FILE"
    echo "Refer to: https://cli.github.com/ or your OS package manager." | tee -a "$GLOBAL_LOG_FILE"
    exit 1
fi

# 2. Check if gh CLI is authenticated (optional, but highly recommended for avoiding rate limits)
if ! gh auth status &> /dev/null
then
    echo "Warning: GitHub CLI (gh) is not authenticated. Some operations might be rate-limited or fail." | tee -a "$GLOBAL_LOG_FILE"
    echo "Please run 'gh auth login' to authenticate for more reliable scanning." | tee -a "$GLOBAL_LOG_FILE"
fi

# Create base directories if they don't exist
mkdir -p "$CLONED_REPOS_DIR"
mkdir -p "$GLOBAL_ANALYSIS_ROOT"

# --- Fetch all unique repository URLs (Owner/RepoName format) ---
declare -A UNIQUE_REPOS # Associative array to store unique repos (owner/repo_name as key)

# 1. Get public repositories directly from the organization/user
echo "--- Fetching public repositories for ${ORG_NAME} (direct owner) ---" | tee -a "$GLOBAL_LOG_FILE"
# Capture output into a temporary array using mapfile/readarray to avoid subshell issues
mapfile -t direct_repos_list < <(gh repo list "$ORG_NAME" --visibility=public --json name,owner --jq '.[] | .owner.login + "/" + .name' 2>> "$GLOBAL_LOG_FILE")

for repo_full_name in "${direct_repos_list[@]}"; do
    UNIQUE_REPOS["$repo_full_name"]=1
done
# Re-calculating the found count directly for logging clarity
echo "Found $(echo "${#direct_repos_list[@]}" | xargs) direct repositories." | tee -a "$GLOBAL_LOG_FILE"

# 2. Get members of the organization and their public, non-forked repositories
# Only if the target is actually an organization, not just a user
gh api users/"$ORG_NAME" --jq '.type' 2>> "$GLOBAL_LOG_FILE" | grep -q "Organization"
if [ $? -eq 0 ]; then
    echo "--- Fetching members for organization ${ORG_NAME} ---" | tee -a "$GLOBAL_LOG_FILE"
    MEMBERS=$(gh api orgs/"$ORG_NAME"/members --jq '.[].login' 2>> "$GLOBAL_LOG_FILE")
    echo "Found $(echo "$MEMBERS" | wc -l) members." | tee -a "$GLOBAL_LOG_FILE"

    for MEMBER in $MEMBERS; do
        echo "--- Fetching public, non-forked repositories for member: ${MEMBER} ---" | tee -a "$GLOBAL_LOG_FILE"
        # Capture output into a temporary array using mapfile/readarray to avoid subshell issues
        mapfile -t member_repos_list < <(gh repo list "$MEMBER" --visibility=public --json name,isFork,owner --jq '.[] | select(.isFork == false and .owner.login == "'"$MEMBER"'") | .owner.login + "/" + .name' 2>> "$GLOBAL_LOG_FILE")

        for repo_full_name in "${member_repos_list[@]}"; do
            UNIQUE_REPOS["$repo_full_name"]=1
        done
        echo "Found $(echo "${#member_repos_list[@]}" | xargs) non-forked public repositories for ${MEMBER}." | tee -a "$GLOBAL_LOG_FILE"
    done
else
    echo "--- Target ${ORG_NAME} is a User, not an Organization. Skipping member repo collection. ---" | tee -a "$GLOBAL_LOG_FILE"
fi

TOTAL_REPOS_TO_SCAN=${#UNIQUE_REPOS[@]}
if [ "$TOTAL_REPOS_TO_SCAN" -eq 0 ]; then
    echo "Error: No public repositories found to scan for ${ORG_NAME} or its members." | tee -a "$GLOBAL_LOG_FILE"
    exit 1
fi


echo "Total unique repositories to scan: ${TOTAL_REPOS_TO_SCAN}" | tee -a "$GLOBAL_LOG_FILE"
echo "--- Starting scan of individual repositories ---" | tee -a "$GLOBAL_LOG_FILE"
echo "" | tee -a "$GLOBAL_LOG_FILE"

# --- Loop through each unique repository ---
# Sort the keys (owner/repo_name) for consistent order
for REPO_FULL_NAME in "${!UNIQUE_REPOS[@]}"; do
    OWNER=$(echo "$REPO_FULL_NAME" | cut -d'/' -f1)
    REPO_NAME=$(echo "$REPO_FULL_NAME" | cut -d'/' -f2)

    echo "################################################################################" | tee -a "$GLOBAL_LOG_FILE"
    echo "--- Processing Repository: ${OWNER}/${REPO_NAME} ---" | tee -a "$GLOBAL_LOG_FILE"
    echo "################################################################################" | tee -a "$GLOBAL_LOG_FILE"

    REPO_URL="https://github.com/${OWNER}/${REPO_NAME}.git"
    # Local path where this specific repository will be cloned
    LOCAL_CLONE_PATH="${CLONED_REPOS_DIR}/${OWNER}/${REPO_NAME}"
    # Specific analysis output path for this repository
    CURRENT_REPO_ANALYSIS_PATH="${GLOBAL_ANALYSIS_ROOT}/${OWNER}/${REPO_NAME}"

    # Ensure clone target directory exists
    mkdir -p "$(dirname "$LOCAL_CLONE_PATH")"

    # 1. Clone the repository or pull latest changes if it already exists
    if [ -d "$LOCAL_CLONE_PATH" ]; then
        echo "Repository ${OWNER}/${REPO_NAME} already exists locally. Pulling latest changes..." | tee -a "$GLOBAL_LOG_FILE"
        (cd "$LOCAL_CLONE_PATH" && git pull) 2>&1 | tee -a "$GLOBAL_LOG_FILE" || { echo "Error: Failed to pull latest changes for ${OWNER}/${REPO_NAME}. Skipping its scan." | tee -a "$GLOBAL_LOG_FILE"; continue; }
    else
        echo "Cloning ${OWNER}/${REPO_NAME} from ${REPO_URL} into ${LOCAL_CLONE_PATH}..." | tee -a "$GLOBAL_LOG_FILE"
        git clone "$REPO_URL" "$LOCAL_CLONE_PATH" 2>&1 | tee -a "$GLOBAL_LOG_FILE" || { echo "Error: Failed to clone ${OWNER}/${REPO_NAME}. Skipping its scan." | tee -a "$GLOBAL_LOG_FILE"; continue; }
    fi

    # Navigate into the cloned repository's directory for processing
    if [ -d "$LOCAL_CLONE_PATH" ]; then
        cd "$LOCAL_CLONE_PATH" || { echo "Error: Failed to change directory to ${LOCAL_CLONE_PATH}. Cannot proceed with scan." | tee -a "$GLOBAL_LOG_FILE"; continue; }

        # Ensure its specific analysis output directory exists
        mkdir -p "$CURRENT_REPO_ANALYSIS_PATH"

        # 2. Run all recovery methods for the current repository
        echo "Running all recovery methods for ${OWNER}/${REPO_NAME}..." | tee -a "$GLOBAL_LOG_FILE"
        # Pass the desired analysis output path as the first argument to the script
        "${PENTEST_WORKSPACE}/run_all_recovery.sh" "$CURRENT_REPO_ANALYSIS_PATH" 2>&1 | tee -a "$GLOBAL_LOG_FILE" || { echo "Warning: Recovery methods for ${OWNER}/${REPO_NAME} failed. Attempting scan anyway." | tee -a "$GLOBAL_LOG_FILE"; }

        # 3. Run all TruffleHog scans for the current repository
        echo "Running all TruffleHog scans for ${OWNER}/${REPO_NAME}..." | tee -a "$GLOBAL_LOG_FILE"
        # Pass the desired analysis output path as the first argument to the script
        "${PENTEST_WORKSPACE}/run_all_trufflehog_scans.sh" "$CURRENT_REPO_ANALYSIS_PATH" 2>&1 | tee -a "$GLOBAL_LOG_FILE" || { echo "Error: TruffleHog scans for ${OWNER}/${REPO_NAME} failed. Check its specific log in ${CURRENT_REPO_ANALYSIS_PATH}." | tee -a "$GLOBAL_LOG_FILE"; }

        # Navigate back to the 'pentest_workspace' for the next repository
        cd "$PENTEST_WORKSPACE"
    else
        echo "Directory ${LOCAL_CLONE_PATH} not found after cloning attempt. Skipping further steps for this repository." | tee -a "$GLOBAL_LOG_FILE"
    fi
    echo "" | tee -a "$GLOBAL_LOG_FILE"
done

echo "--- All Organization-Wide Scans Completed for: ${ORG_NAME} ---" | tee -a "$GLOBAL_LOG_FILE"
echo "Scan finished at: $(date)" | tee -a "$GLOBAL_LOG_FILE"
echo "----------------------------------------------------------------" | tee -a "$GLOBAL_LOG_FILE"
echo "Final results for each repo are in ${GLOBAL_ANALYSIS_ROOT}/<owner_name>/<repo_name>/trufflehog_all_scan_results.json" | tee -a "$GLOBAL_LOG_FILE"
echo "Full process log: $GLOBAL_LOG_FILE" | tee -a "$GLOBAL_LOG_FILE"
