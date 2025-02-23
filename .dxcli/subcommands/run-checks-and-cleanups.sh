#!/usr/bin/env bash
#@metadata-start
#@name check
#@description Run all code quality checks and cleanups
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

DXCLI_ROOT=$( cd "$SCRIPT_FOLDER/../.." >/dev/null 2>&1 && pwd )
if [ -z "$DXCLI_ROOT" ]; then
    echo "Failed to determine dxcli root" >&2
    exit 1
fi

source "$DXCLI_ROOT/.dxcli/shared.sh"

# Validate environment
require_command php
require_command npm

log_info "Running PHP CS Fixer..."
pushd "$PROJECT_ROOT" > /dev/null || exit 1
    /usr/bin/env php "$PROJECT_ROOT/bin/php-cs-fixer.php" fix
popd > /dev/null || exit 1

log_info "Running frontend checks..."
pushd "$PROJECT_ROOT" > /dev/null || exit 1
    # Source NVM in a way that works both in CI and local dev
    if [ -f "$HOME/.nvm/nvm.sh" ]; then
        . "$HOME/.nvm/nvm.sh"
        nvm use
    fi
    
    log_info "Running Prettier..."
    /usr/bin/env npm run prettier:fix
    
    log_info "Running ESLint..."
    /usr/bin/env npm run lint
popd > /dev/null || exit 1

log_info "Running PHPStan..."
pushd "$PROJECT_ROOT" > /dev/null || exit 1
    /usr/bin/env php "$PROJECT_ROOT/vendor/bin/phpstan" --memory-limit=1024M
popd > /dev/null || exit 1

log_info "All checks and cleanups completed successfully! ✨"
