#compdef dx
# ZSH completion script for dxcli

# Enable ZSH compatibility features
setopt BASH_REMATCH
setopt KSH_ARRAYS

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
            if [[ "$line" =~ "#@name[[:space:]]*(.+)" ]]; then
                name="${match[1]}"
            fi
            # Parse description
            if [[ "$line" =~ "#@description[[:space:]]*(.+)" ]]; then
                description="${match[1]}"
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
    local dxcli_dir
    dxcli_dir=$(_find_dxcli)
    
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
    
    for inst in "${installations[@]}"; do
        echo "$inst"
    done
}

# Get all available commands from stacked installations
_get_stacked_commands() {
    # Explicitly declare associative array for ZSH
    typeset -A command_map
    local installations=()
    local installation
    
    # Get all parent installations (ordered by priority)
    installations=($(_find_parent_dxcli_installations))
    
    # Add metacommands
    command_map[".install-commands"]="Install subcommands from a git repository"
    command_map[".install-globally"]="Install a dxcli wrapper script globally (run once per user)"
    command_map[".update"]="Update the dxcli installation in the current project"
    
    # Process each installation, with closer ones taking precedence
    for installation in "${installations[@]}"; do
        local subcommands_dir="$installation/subcommands"
        
        if [[ -d "$subcommands_dir" ]]; then
            local scripts
            scripts=($(find "$subcommands_dir" -type f -name "*.sh"))
            
            for script in "${scripts[@]}"; do
                local metadata
                metadata=$(_get_command_metadata "$script")
                if [[ -n "$metadata" ]]; then
                    local cmd_name cmd_desc
                    IFS=':' read -r cmd_name cmd_desc <<< "$metadata"
                    # Only add if not already in the map (closer ones take precedence)
                    if [[ -z "${command_map[$cmd_name]}" ]]; then
                        command_map[$cmd_name]="$cmd_desc"
                    fi
                fi
            done
        fi
    done
    
    # Output the commands with descriptions
    for name in "${(k)command_map[@]}"; do
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
            local cmd_list
            cmd_list=($(_get_stacked_commands | sort))
            
            for cmd in "${cmd_list[@]}"; do
                local name description
                IFS=':' read -r name description <<< "$cmd"
                commands+=("$name:$description")
            done
            
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