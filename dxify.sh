#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging helpers
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if .dxcli already exists
if [ -d ./.dxcli ]; then
    log_error "Project already has a .dxcli directory"
    exit 1
fi

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Clone the dxcli repository
log_info "Fetching latest dxcli..."
git clone --depth 1 https://github.com/dx-tooling/dxcli.git "$TMP_DIR/dxcli" >/dev/null 2>&1

# Copy the .dxcli directory to the project
log_info "Installing dxcli..."
cp -r "$TMP_DIR/dxcli/.dxcli" ./

# Make scripts executable
chmod +x ./.dxcli/dxcli.sh
find ./.dxcli/subcommands -type f -name "*.sh" -exec chmod +x {} \;

# Create dx symlink
ln -s ".dxcli/dxcli.sh" ./dx
chmod +x ./dx

log_info "DX CLI installed successfully!"

# Process .dxclirc file if it exists
if [ -f ./.dxclirc ]; then
    log_info "Found .dxclirc file, processing..."

    # Flag to track if we're in the install-commands section
    in_install_commands=0

    # Read the .dxclirc file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | xargs)

        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            continue
        fi

        # Check for section headers
        if [[ "$line" == \[*\] ]]; then
            if [ "$line" == "[install-commands]" ]; then
                in_install_commands=1
                log_info "Found [install-commands] section"
            else
                in_install_commands=0
            fi
            continue
        fi

        # Process git URLs in the install-commands section
        if [ $in_install_commands -eq 1 ] && [ -n "$line" ]; then
            log_info "Installing commands from: $line"
            ./dx .install-commands "$line"
        fi
    done < ./.dxclirc
fi

# Check if global dx command is available
if command -v dx >/dev/null 2>&1; then
    # Get the path of the global dx command
    GLOBAL_DX_PATH=$(command -v dx)

    # Check if the global wrapper script needs to be updated
    LOCAL_WRAPPER_PATH="./.dxcli/global-wrapper.sh"

    if [ -f "$LOCAL_WRAPPER_PATH" ] && [ -f "$GLOBAL_DX_PATH" ]; then
        # Compare the content of the wrapper scripts (ignoring whitespace)
        if ! diff -q -B -w "$LOCAL_WRAPPER_PATH" "$GLOBAL_DX_PATH" >/dev/null 2>&1; then
            log_warning "Your global dx wrapper script at $GLOBAL_DX_PATH is different from the latest version"
            log_warning "Run './dx .install-globally' to update your global dx command"
        else
            log_info "Your global dx wrapper script at $GLOBAL_DX_PATH is up to date"
        fi
    else
        log_warning "Could not verify if your global dx wrapper is up to date"
        log_warning "If you want to update your global dx command, run './dx .install-globally'"
    fi
else
    log_info "Run './dx .install-globally' to set up the global dx command"
fi
