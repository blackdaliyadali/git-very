# git-very

## GitHub Repository Forensic & Secret Scanning Toolkit

This repository contains a suite of shell scripts designed to assist in the forensic analysis and recovery of potentially deleted files from GitHub repositories, followed by comprehensive secret scanning using [TruffleHog](https://github.com/trufflesecurity/trufflehog). The toolkit automates the process of cloning repositories, attempting various recovery methods, and then scanning for sensitive information across both current and historical data.



## Features

  * **Automated Repository Cloning:** Efficiently clones all target GitHub repositories.
  * **Multi-Method File Recovery:** Attempts to restore deleted files and data using various Git forensic techniques, including:
      * Analysis of commit history.
      * Identification and recovery of unreachable Git blobs.
      * Unpacking and inspection of Git pack files.
  * **Comprehensive Secret Scanning:** Integrates [TruffleHog](https://github.com/trufflesecurity/trufflehog) to scan for secrets across:
      * The current filesystem of cloned repositories.
      * The entire Git history (commits, branches, blobs).
  * **Consolidated Results:** Combines all TruffleHog scan results into a single, easy-to-analyze JSON file.
  * **Streamlined Workflow:** Provides orchestration scripts to run recovery and scanning processes end-to-end.

-----

## Prerequisites

Before running these scripts, ensure you have the following installed on your system:

  * **Git:** For cloning repositories and Git-based forensic operations.
  * **TruffleHog:** The secret scanning tool. Follow the installation instructions from the [official TruffleHog repository](https://github.com/trufflesecurity/trufflehog).
  * **Shell Environment:** A Unix-like environment (Linux, macOS, WSL on Windows).
  * **JQ (Optional but Recommended):** A lightweight and flexible command-line JSON processor, useful for working with the combined TruffleHog JSON output.

-----

## Installation

1.  **Clone this repository:**
    ```bash
    git clone https://github.com/blackdaliyadali/git-very.git
    cd git-very
    ```
2.  **Ensure scripts are executable:**
    ```bash
    chmod +x *.sh
    ```
3.  **Configure GitHub Access (if needed):**
    For cloning private repositories or large organizations, you might need to set up Git with a [Personal Access Token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token). Ensure your PAT has the necessary permissions (e.g., `repo` scope).

-----

## Usage

### Workflow Overview

The general workflow orchestrated by these scripts is as follows:

1.  **Repository Acquisition:** All target GitHub repositories are cloned into the `cloned_repos/` directory.
2.  **Data Recovery:** Various scripts attempt to recover potentially deleted or hidden data from the cloned repositories' Git objects and history.
3.  **Secret Scanning:** TruffleHog is run against the recovered and existing repository data.
4.  **Result Aggregation:** All TruffleHog JSON outputs are combined for consolidated analysis.

### Step-by-Step Execution

You can run the full process using the orchestration scripts, or execute individual steps as needed.

**1. Full Automated Run (Recommended):**

The `run_all_recovery.sh` and `run_all_trufflehog_scans.sh` scripts are designed to execute the full workflow.

```bash
echo "Starting full GitHub repository forensic and secret scanning..." | tee -a __ANALYSIS/organization_wide_scan.log

# 1. Run all recovery methods and prepare for scanning.
# This script is assumed to handle the initial cloning or expects 'cloned_repos' to be populated.
./run_all_recovery.sh 2>&1 | tee -a __ANALYSIS/organization_wide_scan.log

# 2. After recovery, run all TruffleHog scans.
./run_all_trufflehog_scans.sh 2>&1 | tee -a __ANALYSIS/organization_wide_scan.log

echo "Full scan complete. Check __ANALYSIS/ for results." | tee -a __ANALYSIS/organization_wide_scan.log
```

**2. Manual Step-by-Step Execution:**

You can also execute individual scripts for more granular control:

```bash
# Ensure 'cloned_repos' directory exists for cloned repositories
mkdir -p cloned_repos

# 1. Clone all repositories (You'll need to adapt this or have a separate script for it
# if 'run_all_recovery.sh' doesn't handle the initial cloning.
# Example: ./your_clone_script.sh <list_of_repos_or_org>

# 2. Recover deleted files from commit history
./restore_deleted_from_commits.sh

# 3. Find and recover unreachable blobs
./find_unreachable_blobs.sh

# 4. Unpack Git packs (if needed for deeper analysis/recovery)
./unpack_git_packs.sh

# 5. Run TruffleHog scans on the filesystem
./scan_trufflehog_filesystem.sh

# 6. Run TruffleHog scans on Git history
./scan_trufflehog_git.sh

# 7. Combine all TruffleHog JSON results
./combine_all_trufflehog_json.sh
```

-----

## Scripts Overview

Here's a breakdown of the scripts included in this repository:

  * `run_all_recovery.sh`: Orchestrates and executes all available data recovery methods (`restore_deleted_from_commits.sh`, `find_unreachable_blobs.sh`, `unpack_git_packs.sh`). *This script is assumed to also handle initial cloning or require `cloned_repos` to be populated.*
  * `restore_deleted_from_commits.sh`: Recovers files that might have been deleted but are still present in the Git commit history of the cloned repositories.
  * `find_unreachable_blobs.sh`: Identifies and attempts to recover Git "blobs" (file contents) that are no longer referenced by any commits, branches, or tags, but might still exist in the Git object database.
  * `unpack_git_packs.sh`: Processes Git pack files (compressed collections of Git objects) to make their contents accessible, potentially revealing older or deleted data.
  * `run_all_trufflehog_scans.sh`: Orchestrates the execution of both filesystem and Git history TruffleHog scans (`scan_trufflehog_filesystem.sh` and `scan_trufflehog_git.sh`).
  * `scan_trufflehog_filesystem.sh`: Runs TruffleHog against the live filesystem contents of the `cloned_repos` directory.
  * `scan_trufflehog_git.sh`: Runs TruffleHog specifically against the Git history (commits, trees, blobs) of the cloned repositories for deeper secret detection.
  * `combine_all_trufflehog_json.sh`: Gathers all individual `trufflehog_results_*.json` files generated by the scanning scripts and merges them into a single, comprehensive `scanresult.json` file.
  * `cloned_repos/`: (Directory) This directory will contain all the cloned GitHub repositories.
  * `__ANALYSIS/`: (Directory) This directory will store analysis logs and final combined scan results.
  * `__ANALYSIS/organization_wide_scan.log`: The main log file capturing output and errors from the entire scanning and recovery process.

-----

## Output

After running the scripts, the `__ANALYSIS/` directory will contain:

  * `scanresult.json`: The consolidated JSON file containing all findings from the TruffleHog scans. This file is crucial for reviewing detected secrets.
  * `organization_wide_scan.log`: A comprehensive log of the entire process, including output from cloning, recovery attempts, and scanning operations. Review this log for any errors or important messages.

Individual TruffleHog JSON files (e.g., `trufflehog_results_repo1.json`) might also be present in temporary locations before being combined, or directly in `__ANALYSIS/` depending on the individual script implementations.

-----

## Contributing

Contributions are welcome\! If you have ideas for improving these scripts, adding new recovery methods, or enhancing the scanning process, feel free to:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

-----

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
