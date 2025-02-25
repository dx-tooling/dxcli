#!/usr/bin/env bash
#@metadata-start
#@name .install-globally
#@description Install a dxcli wrapper script globally (run once per user)
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

# Path to the global wrapper script
GLOBAL_WRAPPER_SRC="$SCRIPT_FOLDER/global-wrapper.sh"

# Check if the global wrapper script exists
if [ ! -f "$GLOBAL_WRAPPER_SRC" ]; then
    log_error "Global wrapper script not found at: $GLOBAL_WRAPPER_SRC"
    exit 1
fi

# Determine the appropriate bin directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - prefer /usr/local/bin
    BIN_DIR="/usr/local/bin"
    # Create if it doesn't exist
    if [[ ! -d "$BIN_DIR" ]]; then
        log_info "Creating $BIN_DIR directory (requires sudo)..."
        sudo mkdir -p "$BIN_DIR"
    fi
else
    # Linux - use ~/.local/bin
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
fi

# Install the wrapper script
WRAPPER_PATH="$BIN_DIR/dx"

# Copy the global wrapper script to its final location
if [[ "$OSTYPE" == "darwin"* ]]; then
    log_info "Installing wrapper script (requires sudo)..."
    sudo cp "$GLOBAL_WRAPPER_SRC" "$WRAPPER_PATH"
    sudo chmod 755 "$WRAPPER_PATH"
    sudo chown root:wheel "$WRAPPER_PATH"
else
    cp "$GLOBAL_WRAPPER_SRC" "$WRAPPER_PATH"
    chmod +x "$WRAPPER_PATH"
fi

# Ensure BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    # Determine shell configuration file
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi

    # Add to PATH if not already there
    echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_RC"
    log_info "Added $BIN_DIR to PATH in $SHELL_RC"
    log_warning "Please restart your shell or run: source $SHELL_RC"
fi

log_info "DX CLI wrapper installed successfully at: $WRAPPER_PATH"
log_info "You can now use 'dx' command from any directory within your project"
