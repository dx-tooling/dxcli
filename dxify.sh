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

# Validate we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_error "Not in a git repository"
    exit 1
fi

# Get the project root
PROJECT_ROOT=$(git rev-parse --show-toplevel)
if [ -z "$PROJECT_ROOT" ]; then
    log_error "Failed to determine project root"
    exit 1
fi

# Check if .dxcli already exists
if [ -d "$PROJECT_ROOT/.dxcli" ]; then
    log_error "Project already has a .dxcli directory"
    exit 1
fi

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Clone the dxcli repository
log_info "Fetching latest dxcli..."
git clone --depth 1 https://github.com/Enterprise-Tooling-for-Symfony/dxcli.git "$TMP_DIR/dxcli" >/dev/null 2>&1

# Copy the .dxcli directory to the project
log_info "Installing dxcli..."
cp -r "$TMP_DIR/dxcli/.dxcli" "$PROJECT_ROOT/"

# Make scripts executable
chmod +x "$PROJECT_ROOT/.dxcli/dxcli.sh"
find "$PROJECT_ROOT/.dxcli/subcommands" -type f -name "*.sh" -exec chmod +x {} \;
find "$PROJECT_ROOT/.dxcli/metacommands" -type f -name "*.sh" -exec chmod +x {} \;

# Create dx symlink
ln -s ".dxcli/dxcli.sh" "$PROJECT_ROOT/dx"
chmod +x "$PROJECT_ROOT/dx"

# Add to .gitignore if it doesn't contain the entries
GITIGNORE="$PROJECT_ROOT/.gitignore"
touch "$GITIGNORE"

log_info "DX CLI installed successfully!"
log_info "Run './dx .install' to set up the global dx command"
