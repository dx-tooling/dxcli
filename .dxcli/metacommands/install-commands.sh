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

# Check if subcommands directory exists in the cloned repo
if [ ! -d "$TEMP_DIR/subcommands" ]; then
    log_error "No subcommands directory found in the repository"
    exit 1
fi

# Create subcommands directory if it doesn't exist
mkdir -p "$SUBCOMMANDS_DIR"

# Copy all subcommands
log_info "Installing subcommands..."
cp -R "$TEMP_DIR/subcommands/"* "$SUBCOMMANDS_DIR/"

# Make all scripts executable
find "$SUBCOMMANDS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

log_info "Successfully installed subcommands from $REPO_URL"
