#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$SCRIPT_DIR/scripts/lib/os.sh"
trap 'report_error "$?" "$LINENO"' ERR

usage() {
    printf '%s\n' \
        'Usage: bash bootstrap.sh [--help]' \
        'Scaffolding only: detect the platform and describe future setup.' \
        'Requires this checkout and its scripts/lib files. Makes no changes.'
}

if [[ $# -gt 1 ]]; then
    die 'Expected no arguments or --help.'
fi
case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
'') ;;
*) die 'Unknown argument. Use --help for usage.' ;;
esac

# No arguments selects host detection rather than test fixture parameters.
# shellcheck disable=SC2119
platform=$(detect_os)
log "bootstrap.sh: scaffolding only. Detected platform: $platform."
log 'Not implemented: prerequisite installation, SSH setup, mise installation,'
log 'repository cloning, or delegation to update.sh.'
log 'No changes made.'
