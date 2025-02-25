#!/usr/bin/env bash

#@metadata-start
#@name .install-commands
#@description Install subcommands from a git repository
#@metadata-end

set -e
set -u
set -o pipefail

# Source shared functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../shared.sh"

# Validate input
if [ $# -ne 1 ]; then
    log_error "Usage: dx .install-commands <git-repository-url>"
    exit 1
fi

REPO_URL="$1"
TEMP_DIR=$(mktemp -d)
SUBCOMMANDS_DIR="$PROJECT_ROOT/.dxcli/subcommands"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Validate git command
require_command git

# Clone the repository
log_info "Cloning repository $REPO_URL..."
if ! git clone "$REPO_URL" "$TEMP_DIR" >/dev/null 2>&1; then
    log_error "Failed to clone repository"
    exit 1
fi

# Get the latest commit ID from the main/master branch
cd "$TEMP_DIR"
COMMIT_ID=$(git rev-parse HEAD)
cd - > /dev/null

# Check if subcommands directory exists in the cloned repo
if [ ! -d "$TEMP_DIR/subcommands" ]; then
    log_error "No subcommands directory found in the repository"
    exit 1
fi

# Create subcommands directory if it doesn't exist
mkdir -p "$SUBCOMMANDS_DIR"

# Get list of subcommands in the repo
REPO_SUBCOMMANDS=()
while IFS= read -r -d '' script; do
    REPO_SUBCOMMANDS+=("$(basename "$script")")
done < <(find "$TEMP_DIR/subcommands" -type f -name "*.sh" -print0)

# Copy all subcommands
log_info "Installing subcommands..."
cp -R "$TEMP_DIR/subcommands/"* "$SUBCOMMANDS_DIR/"

# Add source metadata to each subcommand that was just installed
log_info "Adding source metadata to subcommands..."
for script_name in "${REPO_SUBCOMMANDS[@]}"; do
    script="$SUBCOMMANDS_DIR/$script_name"
    if [ -f "$script" ]; then
        # Check if the file has a metadata section
        if grep -q "#@metadata-start" "$script"; then
            # Remove any existing source metadata lines to avoid duplication
            sed -i.bak "/#@source-repo/d" "$script"
            sed -i.bak "/#@source-commit-id/d" "$script"
            # Add source metadata before metadata-end
            sed -i.bak "/#@metadata-end/i\\
#@source-repo $REPO_URL\\
#@source-commit-id $COMMIT_ID\\
" "$script"
            rm -f "${script}.bak"
        else
            # If no metadata section exists, add one
            sed -i.bak "1a\\
#@metadata-start\\
#@source-repo $REPO_URL\\
#@source-commit-id $COMMIT_ID\\
#@metadata-end" "$script"
            rm -f "${script}.bak"
        fi
    fi
done

# Make all scripts executable
find "$SUBCOMMANDS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

log_info "Successfully installed $(echo ${#REPO_SUBCOMMANDS[@]}) subcommands from $REPO_URL (commit: $COMMIT_ID)"
