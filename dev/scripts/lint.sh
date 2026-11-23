#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=dev/lib/shell-files.sh
source "$ROOT/dev/lib/shell-files.sh"

main() {
    usage() {
        printf '%s\n' 'Usage: bash dev/scripts/lint.sh [-- FILE ...]' \
            'Without FILE arguments, lint all tracked *.sh files.' \
            'Linting never rewrites or stages files.'
    }

    case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    --) shift ;;
    -*)
        usage >&2
        exit 2
        ;;
    esac

    select_shell_files "$@"
    if [[ ${#files[@]} -eq 0 ]]; then
        printf 'No tracked shell scripts to lint.\n'
        exit 0
    fi
    exec "$ROOT/dev/scripts/run-mise.sh" exec -- shellcheck -x -- "${files[@]}"
}

main "$@"
