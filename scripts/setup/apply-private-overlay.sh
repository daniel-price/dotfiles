#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"

main() {
    usage() {
        printf '%s\n' \
            'Usage: bash scripts/setup/apply-private-overlay.sh --source DIR --target DIR' \
            'Preview and apply one explicitly selected directory symlink with mise.' \
            'Does not discover, clone, fetch, trust or update any private repository.'
    }

    source_dir=''
    target_dir=''
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --source)
            [[ $# -ge 2 && -n "$2" ]] || die '--source requires a directory.'
            source_dir=$2
            shift 2
            ;;
        --target)
            [[ $# -ge 2 && -n "$2" ]] || die '--target requires a directory.'
            target_dir=$2
            shift 2
            ;;
        *) die 'Unknown argument. Use --help for usage.' ;;
        esac
    done

    [[ -n "$source_dir" && -n "$target_dir" ]] ||
        die 'Both --source and --target are required.'
    case "$source_dir$target_dir" in
    *$'\n'* | *$'\r'* | *$'\t'*) die 'Paths must not contain control characters.' ;;
    esac
    [[ "$source_dir" == /* && "$target_dir" == /* ]] ||
        die 'Source and target must be absolute paths.'

    canonical_dir() {
        local path=$1
        (CDPATH='' cd -- "$path" 2>/dev/null && pwd -P) || return 1
    }

    [[ -d "$source_dir" && ! -L "$source_dir" ]] ||
        die 'Selected source is not an existing real directory.'
    source_dir=$(canonical_dir "$source_dir") ||
        die 'Could not resolve the selected source directory.'

    target_parent=${target_dir%/*}
    [[ -n "$target_parent" && "$target_parent" != "$target_dir" ]] ||
        die 'Target must be a directory path with a parent directory.'
    if [[ -e "$target_parent" || -L "$target_parent" ]]; then
        [[ -d "$target_parent" && ! -L "$target_parent" ]] ||
            die "Target parent is not a regular directory: $target_parent"
    else
        die "Target parent does not exist: $target_parent"
    fi

    if command -v git >/dev/null 2>&1 &&
        git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [[ -n "$(git -C "$source_dir" status --porcelain 2>/dev/null || :)" ]]; then
            die 'Selected source has uncommitted changes; resolve them before deployment.'
        fi
        upstream=$(git -C "$source_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || :)
        if [[ -n "$upstream" ]]; then
            counts=$(git -C "$source_dir" rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || :)
            if [[ -n "$counts" && "$counts" == *$'\t'* ]]; then
                behind=${counts%%$'\t'*}
                ahead=${counts#*$'\t'}
                if [[ "$behind" != 0 && "$ahead" != 0 ]]; then
                    die 'Selected source is diverged from its upstream; resolve it first.'
                fi
                if [[ "$behind" != 0 ]]; then
                    die 'Selected source is behind its upstream; update it explicitly first.'
                fi
            fi
        fi
    fi

    if [[ -L "$target_dir" ]]; then
        link=$(readlink "$target_dir") || die 'Could not read the existing target symlink.'
        case "$link" in
        /*) resolved=$link ;;
        *) resolved="$target_parent/$link" ;;
        esac
        if canonical=$(canonical_dir "$resolved") && [[ "$canonical" == "$source_dir" ]]; then
            log 'Selected overlay is already applied; no changes made.'
            exit 0
        fi
        die 'Existing target is a different symlink; resolve this conflict manually.'
    elif [[ -e "$target_dir" ]]; then
        die 'Existing target path is a real file or directory; resolve this conflict manually.'
    fi

    mise=$(mise_command) || die 'mise is unavailable; install it before applying an overlay.'
    mise_supports_dot "$mise" ||
        die 'mise 2026.11.9 or newer is required for dotfile deployment; bootstrap installs it.'
    work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-overlay.XXXXXX") ||
        die 'Could not create a temporary mise configuration directory.'
    trap 'rm -rf -- "$work"' EXIT

    printf '[dotfiles."%s"]\nsource = "%s"\nmode = "symlink"\n' \
        "$(toml_escape "$target_dir")" "$(toml_escape "$source_dir")" \
        >"$work/mise.toml" || die "Could not write the temporary overlay manifest."

    trust_mise_config_dir "$work"
    "$mise" -C "$work" dot diff || die 'mise dot diff failed; nothing changed.'
    "$mise" -C "$work" dot apply --dry-run ||
        die 'mise dot apply --dry-run failed; nothing changed.'

    if ! confirm "Apply the reviewed mise dotfile entry at $target_dir?"; then
        log 'Overlay application declined; no changes made.'
        exit 0
    fi
    "$mise" -C "$work" dot apply || die 'mise dot apply failed; inspect the target before retrying.'

    [[ -L "$target_dir" ]] || die 'mise did not create the expected symlink.'
    link=$(readlink "$target_dir") || die 'Could not read the applied target symlink.'
    case "$link" in
    /*) resolved=$link ;;
    *) resolved="$target_parent/$link" ;;
    esac
    canonical=$(canonical_dir "$resolved") ||
        die 'Applied symlink does not resolve to a directory.'
    [[ "$canonical" == "$source_dir" ]] ||
        die 'Applied symlink points to an unexpected directory.'
    log 'Applied selected overlay.'
}

main "$@"
