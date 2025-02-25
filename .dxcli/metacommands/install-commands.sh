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

# Function to install commands from a repository URL
install_from_repo() {
    local REPO_URL="$1"
    local TEMP_DIR=$(mktemp -d)
    local SUBCOMMANDS_DIR="$PROJECT_ROOT/.dxcli/subcommands"

    # Setup cleanup trap inside the function
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
        return 1
    fi

    # Get the latest commit ID from the main/master branch
    cd "$TEMP_DIR"
    COMMIT_ID=$(git rev-parse HEAD)
    cd - > /dev/null

    # Check if subcommands directory exists in the cloned repo
    if [ ! -d "$TEMP_DIR/subcommands" ]; then
        log_error "No subcommands directory found in the repository"
        return 1
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
    
    # Remove the trap before returning
    trap - EXIT
    # Clean up manually
    rm -rf "$TEMP_DIR"
    
    return 0
}

# Check if a URL was provided as an argument
if [ $# -eq 1 ]; then
    # Install from the provided URL
    install_from_repo "$1"
    exit $?
fi

# No URL provided, check for .dxclirc file
if [ $# -eq 0 ]; then
    DXCLIRC_FILE="$PROJECT_ROOT/.dxclirc"
    
    if [ ! -f "$DXCLIRC_FILE" ]; then
        log_error "No repository URL provided and no .dxclirc file found."
        log_error "Usage: dx .install-commands <git-repository-url>"
        exit 1
    fi
    
    log_info "No URL provided. Looking for URLs in .dxclirc file..."
    
    # Flag to track if we're in the install-commands section
    in_install_commands=0
    # Flag to track if we found any URLs
    found_urls=0
    
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
            install_from_repo "$line"
            found_urls=1
        fi
    done < "$DXCLIRC_FILE"
    
    if [ $found_urls -eq 0 ]; then
        log_error "No repository URLs found in the [install-commands] section of .dxclirc"
        log_error "Usage: dx .install-commands <git-repository-url>"
        exit 1
    fi
    
    exit 0
fi

# If we get here, wrong number of arguments was provided
log_error "Usage: dx .install-commands <git-repository-url>"
exit 1
