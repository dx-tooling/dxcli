#compdef dx
# ZSH completion script for dxcli

# Find the nearest .dxcli/dxcli.sh by traversing up the directory tree
_find_dxcli() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.dxcli/dxcli.sh" ]]; then
            echo "$dir/.dxcli"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get command metadata from a script
_get_command_metadata() {
    local script_path=$1
    local in_metadata=0
    local name=""
    local description=""

    while IFS= read -r line; do
        # Start of metadata block
        if [[ "$line" == "#@metadata-start" ]]; then
            in_metadata=1
            continue
        fi

        # End of metadata block
        if [[ "$line" == "#@metadata-end" ]]; then
            break
        fi

        # Inside metadata block
        if [[ $in_metadata -eq 1 ]]; then
            # Parse name
            if [[ "$line" =~ ^#@name[[:space:]]*(.+)$ ]]; then
                name="${BASH_REMATCH[1]}"
            fi
            # Parse description
            if [[ "$line" =~ ^#@description[[:space:]]*(.+)$ ]]; then
                description="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$script_path"

    # Return metadata as a formatted string
    if [[ -n "$name" && -n "$description" ]]; then
        echo "$name:$description"
    fi
}

# Find all parent directories containing .dxcli installations
_find_parent_dxcli_installations() {
    local current_dir="$PWD"
    local installations=()
    local dxcli_dir=$(_find_dxcli)
    
    if [[ -z "$dxcli_dir" ]]; then
        return
    fi
    
    # Add the current installation first (highest priority)
    installations+=("$dxcli_dir")
    
    # Find parent installations
    while [[ "$current_dir" != "/" ]]; do
        current_dir="$(dirname "$current_dir")"
        if [[ -d "$current_dir/.dxcli" && "$current_dir/.dxcli" != "$dxcli_dir" ]]; then
            installations+=("$current_dir/.dxcli")
        fi
    done
    
    printf "%s\n" "${installations[@]}"
}

# Get all available commands from stacked installations
_get_stacked_commands() {
    local -A command_map=()  # Use associative array to track unique commands
    local installations=()
    
    # Get all parent installations (ordered by priority)
    while IFS= read -r installation; do
        installations+=("$installation")
    done < <(_find_parent_dxcli_installations)
    
    # Add metacommands
    command_map[".install-commands"]="Install subcommands from a git repository"
    command_map[".install-globally"]="Install a dxcli wrapper script globally (run once per user)"
    command_map[".update"]="Update the dxcli installation in the current project"
    
    # Process each installation, with closer ones taking precedence
    for installation in "${installations[@]}"; do
        local subcommands_dir="$installation/subcommands"
        
        if [[ -d "$subcommands_dir" ]]; then
            while IFS= read -r -d '' script; do
                local metadata
                metadata=$(_get_command_metadata "$script")
                if [[ -n "$metadata" ]]; then
                    IFS=':' read -r name description <<< "$metadata"
                    # Only add if not already in the map (closer ones take precedence)
                    if [[ -z "${command_map[$name]:-}" ]]; then
                        command_map[$name]="$description"
                    fi
                fi
            done < <(find "$subcommands_dir" -type f -name "*.sh" -print0)
        fi
    done
    
    # Output the commands with descriptions
    for name in "${!command_map[@]}"; do
        echo "$name:${command_map[$name]}"
    done
}

# Main completion function
_dx() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1: :->command' \
        '*:: :->args'

    case $state in
        command)
            local -a commands
            while IFS=':' read -r name description; do
                commands+=("$name:$description")
            done < <(_get_stacked_commands | sort)
            
            _describe -t commands 'dx commands' commands
            ;;
        args)
            # Handle arguments for specific commands if needed
            # This would be expanded for commands that take specific arguments
            ;;
    esac
}

# Register the completion function
compdef _dx dx 