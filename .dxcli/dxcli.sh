#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# Resolve the actual script location, even when called through a symlink
SOURCE=${BASH_SOURCE[0]}
if [ -z "$SOURCE" ]; then
    echo "Failed to determine script source" >&2
    exit 1
fi

while [ -L "$SOURCE" ]; do
    DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
    if [ -z "$DIR" ]; then
        echo "Failed to resolve symlink directory" >&2
        exit 1
    fi
    SOURCE=$(readlink "$SOURCE")
    [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done

SCRIPT_FOLDER=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
if [ -z "$SCRIPT_FOLDER" ]; then
    echo "Failed to determine script folder" >&2
    exit 1
fi

source "$SCRIPT_FOLDER/shared.sh"

# Print a section of commands in the help output
print_command_section() {
    local title=$1
    local -n commands=$2  # nameref to array
    local padding=${3:-12}
    
    echo -e "\n$title:"
    for cmd in "${commands[@]}"; do
        IFS='|' read -r name description <<< "$cmd"
        printf "    %-${padding}s %s\n" "$name" "$description"
    done
}

# Get stacked subcommands from current and parent .dxcli installations
get_stacked_subcommands() {
    local -A command_map=()  # Use associative array to track unique commands
    local installations=()
    
    # Get all parent installations (ordered by priority)
    mapfile -t installations < <(find_parent_dxcli_installations)
    
    # Process each installation, with closer ones taking precedence
    for installation in "${installations[@]}"; do
        local subcommands_dir="$installation/subcommands"
        
        if [[ -d "$subcommands_dir" ]]; then
            while IFS= read -r cmd_info; do
                if [[ -n "$cmd_info" ]]; then
                    IFS='|' read -r name description <<< "$cmd_info"
                    # Only add if not already in the map (closer ones take precedence)
                    if [[ -z "${command_map[$name]:-}" ]]; then
                        command_map[$name]="$cmd_info"
                    fi
                fi
            done < <(get_commands "$subcommands_dir")
        fi
    done
    
    # Output the unique commands
    for cmd_info in "${command_map[@]}"; do
        echo "$cmd_info"
    done
}

# Show help message with available commands
show_help() {
    local subcommands
    local metacommands
    
    # Get all commands
    mapfile -t subcommands < <(get_stacked_subcommands)
    mapfile -t metacommands < <(get_commands "$SCRIPT_FOLDER/metacommands")
    
    # Calculate padding based on longest command name
    local max_length=0
    for cmd in "${subcommands[@]}" "${metacommands[@]}"; do
        IFS='|' read -r name _ <<< "$cmd"
        (( ${#name} > max_length )) && max_length=${#name}
    done
    local padding=$(( max_length + 2 ))
    
    cat << EOF
Developer Experience CLI

Usage: dx <subcommand>
EOF
    
    # Print command sections with dynamic padding
    [[ ${#subcommands[@]} -gt 0 ]] && print_command_section "Available subcommands" subcommands "$padding"
    [[ ${#metacommands[@]} -gt 0 ]] && print_command_section "Metacommands" metacommands "$padding"
    echo
}

# Find a command script by its metadata name
find_command_script() {
    local cmd=$1
    local dir=$2
    local script_path=""
    
    if [[ ! -d "$dir" ]]; then
        return 1
    fi
    
    while IFS= read -r -d '' script; do
        local metadata
        metadata=$(get_command_metadata "$script")
        if [[ -n "$metadata" ]]; then
            IFS='|' read -r name _ <<< "$metadata"
            if [[ "$name" == "$cmd" ]]; then
                echo "$script"
                return 0
            fi
        fi
    done < <(find "$dir" -type f -name "*.sh" -print0)
    
    return 1
}

# Find a stacked subcommand script by its name
find_stacked_subcommand_script() {
    local cmd=$1
    local installations=()
    
    # Get all parent installations (ordered by priority)
    mapfile -t installations < <(find_parent_dxcli_installations)
    
    # Search in each installation, with closer ones taking precedence
    for installation in "${installations[@]}"; do
        local subcommands_dir="$installation/subcommands"
        local script_path=""
        
        script_path=$(find_command_script "$cmd" "$subcommands_dir") || true
        if [[ -n "$script_path" ]]; then
            echo "$script_path"
            return 0
        fi
    done
    
    return 1
}

# Execute a command by name
execute_command() {
    local cmd=$1
    shift  # Remove the command name from the arguments
    local script_path=""
    
    # Special case for help
    if [[ "$cmd" == "help" || -z "$cmd" ]]; then
        show_help
        return
    fi
    
    # First check metacommands (they take precedence and are not stacked)
    script_path=$(find_command_script "$cmd" "$SCRIPT_FOLDER/metacommands") || true
    
    # Then check stacked subcommands if not found
    if [[ -z "$script_path" ]]; then
        script_path=$(find_stacked_subcommand_script "$cmd") || true
    fi
    
    if [[ -z "$script_path" ]]; then
        log_error "Unknown command: $cmd"
        
        # Try to find a suggestion
        local suggestion
        suggestion=$(find_closest_command "$cmd")
        if [[ -n "$suggestion" ]]; then
            log_warning "Did you mean '$suggestion'?"
            echo
        fi
        
        show_help
        exit 1
    fi
    
    # Execute the command
    local metadata
    metadata=$(get_command_metadata "$script_path")
    IFS='|' read -r name description <<< "$metadata"
    log_info "Running: $description"
    /usr/bin/env bash "$script_path" "$@"  # Pass all remaining arguments to the script
}

# Validate environment
require_command php
require_command npm

# Main execution
if [ $# -eq 0 ]; then
    execute_command "help"
else
    cmd="$1"
    shift
    execute_command "$cmd" "$@"
fi
