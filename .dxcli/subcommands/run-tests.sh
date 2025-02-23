#!/usr/bin/env bash
#@metadata-start
#@name test
#@description Run the test suite
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

log_info "Running test suite..."
/usr/bin/env php "$PROJECT_ROOT/bin/phpunit.php" "$PROJECT_ROOT/tests/"

log_info "All tests completed successfully! ✨"
