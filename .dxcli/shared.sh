#!/usr/bin/env bash

set -e
set -u  # Treat unset variables as errors
set -o pipefail  # Pipeline fails on first failed command

# Resolve paths
SCRIPT_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [ -z "$SCRIPT_FOLDER" ]; then
    echo "Failed to determine script location" >&2
    exit 1
fi

PROJECT_ROOT="$( cd "$SCRIPT_FOLDER/.." >/dev/null 2>&1 && pwd )"
if [ -z "$PROJECT_ROOT" ]; then
    echo "Failed to determine project root" >&2
    exit 1
fi

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

# Check if we're running in CI
is_ci() {
    [ -n "${CI:-}" ]
}

# Check if whiptail is available
has_whiptail() {
    command -v whiptail >/dev/null 2>&1
}

# Get terminal dimensions
get_term_height() {
    tput lines 2>/dev/null || echo 24
}

get_term_width() {
    tput cols 2>/dev/null || echo 80
}

# Clear screen and move cursor to top
clear_screen() {
    printf '\033[2J\033[H'
}

# Hide cursor
hide_cursor() {
    printf '\033[?25l'
}

# Show cursor
show_cursor() {
    printf '\033[?25h'
}

# Read a single keypress without requiring Enter
read_key() {
    # Configure terminal for raw input
    exec </dev/tty
    old_tty_settings=$(stty -g)
    stty raw -echo min 0 time 0
    
    # Read a single character
    local c
    c=$(dd bs=1 count=1 2>/dev/null)
    
    # If it's an escape sequence, read more
    if [[ $c = $'\e' ]]; then
        read -rsn2 -t 0.001 more
        c+="$more"
    fi
    
    # Restore terminal settings
    stty "$old_tty_settings"
    
    # Return the key
    printf '%s' "$c"
}

# Cleanup function to ensure terminal is restored
cleanup() {
    show_cursor
    stty sane
    echo
}

# Calculate menu height based on number of items
calc_menu_height() {
    local num_items=$1
    local min_height=10
    local max_height=$(( $(get_term_height) - 7 ))
    local calculated=$(( num_items + 6 ))
    
    if [ "$calculated" -lt "$min_height" ]; then
        echo "$min_height"
    elif [ "$calculated" -gt "$max_height" ]; then
        echo "$max_height"
    else
        echo "$calculated"
    fi
}

# Validate required commands
require_command() {
    local cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
}

# Validate required environment variables
require_env() {
    local var=$1
    if [ -z "${!var:-}" ]; then
        log_error "Required environment variable not set: $var"
        exit 1
    fi
}

# Command discovery and metadata helpers
get_command_metadata() {
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
        echo "$name|$description"
    fi
}

# Get all available commands from a directory
get_commands() {
    local dir=$1
    local commands=()
    
    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        return
    fi
    
    # Find all executable shell scripts
    while IFS= read -r -d '' script; do
        local metadata
        metadata=$(get_command_metadata "$script")
        if [[ -n "$metadata" ]]; then
            commands+=("$metadata")
        fi
    done < <(find "$dir" -type f -name "*.sh" -print0)
    
    # Return commands as newline-separated list
    printf "%s\n" "${commands[@]}"
}

# Calculate Levenshtein distance between two strings
levenshtein_distance() {
    local str1=$1
    local str2=$2
    local len1=${#str1}
    local len2=${#str2}
    
    # Create a matrix of zeros
    declare -A matrix
    for ((i=0; i<=len1; i++)); do
        matrix[$i,0]=$i
    done
    for ((j=0; j<=len2; j++)); do
        matrix[0,$j]=$j
    done
    
    # Fill the matrix
    local cost
    for ((i=1; i<=len1; i++)); do
        for ((j=1; j<=len2; j++)); do
            if [[ "${str1:i-1:1}" == "${str2:j-1:1}" ]]; then
                cost=0
            else
                cost=1
            fi
            
            # Get minimum of three operations
            local del=$((matrix[$((i-1)),$j] + 1))
            local ins=$((matrix[$i,$((j-1))] + 1))
            local sub=$((matrix[$((i-1)),$((j-1))] + cost))
            
            # Find minimum
            matrix[$i,$j]=$del
            [[ $ins -lt ${matrix[$i,$j]} ]] && matrix[$i,$j]=$ins
            [[ $sub -lt ${matrix[$i,$j]} ]] && matrix[$i,$j]=$sub
        done
    done
    
    # Return final distance
    echo "${matrix[$len1,$len2]}"
}

# Find closest matching command
find_closest_command() {
    local input=$1
    local min_distance=1000
    local closest=""
    local all_commands=()
    
    # Collect all command names
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && all_commands+=("$cmd")
    done < <(
        if [[ -d "$SCRIPT_FOLDER/subcommands" ]]; then
            find "$SCRIPT_FOLDER/subcommands" -type f -name "*.sh" -print0 | 
            while IFS= read -r -d '' script; do
                metadata=$(get_command_metadata "$script")
                [[ -n "$metadata" ]] && echo "${metadata%%|*}"
            done
        fi
        if [[ -d "$SCRIPT_FOLDER/metacommands" ]]; then
            find "$SCRIPT_FOLDER/metacommands" -type f -name "*.sh" -print0 | 
            while IFS= read -r -d '' script; do
                metadata=$(get_command_metadata "$script")
                [[ -n "$metadata" ]] && echo "${metadata%%|*}"
            done
        fi
    )
    
    # Find the closest match
    for cmd in "${all_commands[@]}"; do
        local distance
        distance=$(levenshtein_distance "$input" "$cmd")
        if [[ $distance -lt $min_distance ]]; then
            min_distance=$distance
            closest=$cmd
        fi
    done
    
    # Only suggest if reasonably close (adjust threshold as needed)
    if [[ $min_distance -le 3 ]]; then
        echo "$closest"
    fi
}
