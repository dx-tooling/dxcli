#!/usr/bin/env bash
#@metadata-start
#@name .update
#@description Update the dxcli installation in the current project
#@metadata-end

set -e
set -u
set -o pipefail

# Resolve the actual script location, even when called through a symlink
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
    DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
    SOURCE=$(readlink "$SOURCE")
    [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
SCRIPT_FOLDER=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
if [ -z "$SCRIPT_FOLDER" ]; then
    echo "Failed to determine script location" >&2
    exit 1
fi

source "$SCRIPT_FOLDER/../shared.sh"

# Validate git command
require_command git

# Define repository URL and temporary directory
REPO_URL="https://github.com/Enterprise-Tooling-for-Symfony/dxcli.git"
TEMP_DIR=$(mktemp -d)
DXCLI_DIR="$PROJECT_ROOT/.dxcli"

# Ensure cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log_info "Updating dxcli installation..."

# Clone the repository to get the latest version
log_info "Fetching latest version from $REPO_URL..."
if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR" >/dev/null 2>&1; then
    log_error "Failed to clone repository"
    exit 1
fi

# Create backup of current installation in system temp directory
BACKUP_DIR=$(mktemp -d)/dxcli-backup-$(date +%Y%m%d%H%M%S)
log_info "Creating backup of current installation at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -R "$DXCLI_DIR" "$BACKUP_DIR"

# List of files/directories to preserve (user customizations)
PRESERVE=(
    "subcommands"
)

# Temporarily move preserved directories
for item in "${PRESERVE[@]}"; do
    if [ -e "$DXCLI_DIR/$item" ]; then
        log_info "Preserving your custom $item..."
        mv "$DXCLI_DIR/$item" "$TEMP_DIR/$item.preserved"
    fi
done

# Copy new files
log_info "Installing updated files..."
cp -R "$TEMP_DIR/.dxcli/"* "$DXCLI_DIR/"

# Restore preserved directories
for item in "${PRESERVE[@]}"; do
    if [ -e "$TEMP_DIR/$item.preserved" ]; then
        log_info "Restoring your custom $item..."
        rm -rf "$DXCLI_DIR/$item"
        mv "$TEMP_DIR/$item.preserved" "$DXCLI_DIR/$item"
    fi
done

# Make all scripts executable
find "$DXCLI_DIR" -type f -name "*.sh" -exec chmod +x {} \;

log_info "dxcli has been successfully updated!"
log_info "Your previous installation was backed up to $BACKUP_DIR"
log_info "If you encounter any issues, you can restore from the backup."
