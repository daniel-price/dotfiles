#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=dev/lib/shell-files.sh
source "$ROOT/dev/lib/shell-files.sh"

main() {
    usage() {
        printf '%s\n' 'Usage: bash dev/scripts/format.sh [--check] [-- FILE ...]' \
            'Without FILE arguments, format all tracked *.sh files.' \
            '--check reports differences without rewriting or staging files.'
    }

    mode=-w
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --check) mode=-d ;;
        -h | --help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            usage >&2
            exit 2
            ;;
        *) break ;;
        esac
        shift
    done

    select_shell_files "$@"
    if [[ ${#files[@]} -eq 0 ]]; then
        printf 'No tracked shell scripts to format.\n'
        exit 0
    fi
    exec "$ROOT/dev/scripts/run-mise.sh" exec -- shfmt "$mode" -i 4 -- "${files[@]}"
}

main "$@"
