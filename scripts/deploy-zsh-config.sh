#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"
trap 'report_error "$?" "$LINENO"' ERR

usage() {
    printf '%s\n' \
        'Usage: bash scripts/deploy-zsh-config.sh [--target FILE]' \
        'Preview and apply the reviewed zsh startup file with mise.' \
        'Defaults to $HOME/.zshrc. Never overwrites an existing target.'
}

target_file=''
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --target)
        [[ $# -ge 2 && -n "$2" ]] || die '--target requires a file path.'
        target_file=$2
        shift 2
        ;;
    *) die 'Unknown argument. Use --help for usage.' ;;
    esac
done

[[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must be an existing directory.'
if [[ -z "$target_file" ]]; then
    target_file="$HOME/.zshrc"
fi
case "$target_file" in
*$'\n'* | *$'\r'* | *$'\t'*) die 'Target path must not contain control characters.' ;;
esac
[[ "$target_file" == /* ]] || die 'Target path must be absolute.'

canonical_path() {
    local path=$1 parent base dir
    parent=${path%/*}
    base=${path##*/}
    [[ -n "$parent" && "$parent" != "$path" && -n "$base" ]] || return 1
    dir=$(CDPATH='' cd -- "$parent" 2>/dev/null && pwd -P) || return 1
    printf '%s/%s\n' "$dir" "$base"
}

source_file="$ROOT/.config/zsh/zshrc"
[[ -f "$source_file" && ! -L "$source_file" ]] ||
    die 'Reviewed zsh source is missing or is not a regular file.'
source_file=$(canonical_path "$source_file") ||
    die 'Could not resolve the reviewed zsh source.'

target_parent=${target_file%/*}
[[ -n "$target_parent" && "$target_parent" != "$target_file" ]] ||
    die 'Target must be a file path with a parent directory.'
if [[ -e "$target_parent" || -L "$target_parent" ]]; then
    [[ -d "$target_parent" && ! -L "$target_parent" ]] ||
        die "Target parent is not a regular directory: $target_parent"
else
    die "Target parent does not exist: $target_parent"
fi

if [[ -L "$target_file" ]]; then
    link=$(readlink "$target_file") || die 'Could not read the existing target symlink.'
    case "$link" in
    /*) resolved=$link ;;
    *) resolved="$target_parent/$link" ;;
    esac
    if canonical=$(canonical_path "$resolved") && [[ "$canonical" == "$source_file" ]]; then
        log 'Reviewed zsh startup file is already applied; no changes made.'
        exit 0
    fi
    die 'Existing target is a different symlink; resolve this conflict manually.'
elif [[ -e "$target_file" ]]; then
    die 'Existing target path is a real file or directory; resolve this conflict manually.'
fi

mise=$(mise_command) || die 'mise is unavailable; install it before deploying the zsh file.'
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zsh.XXXXXX") ||
    die 'Could not create a temporary mise configuration directory.'
trap 'rm -rf -- "$work"' EXIT

printf '[dotfiles."%s"]\nsource = "%s"\nmode = "symlink"\n' \
    "$(toml_escape "$target_file")" "$(toml_escape "$source_file")" \
    >"$work/mise.toml"

trust_mise_config_dir "$work"
"$mise" -C "$work" dot diff || die 'mise dot diff failed; nothing changed.'
"$mise" -C "$work" dot apply --dry-run ||
    die 'mise dot apply --dry-run failed; nothing changed.'

if ! confirm "Apply the reviewed zsh startup file at $target_file?"; then
    log 'Zsh deployment declined; no changes made.'
    exit 0
fi
"$mise" -C "$work" dot apply || die 'mise dot apply failed; inspect the target before retrying.'

[[ -L "$target_file" ]] || die 'mise did not create the expected symlink.'
link=$(readlink "$target_file") || die 'Could not read the applied target symlink.'
case "$link" in
/*) resolved=$link ;;
*) resolved="$target_parent/$link" ;;
esac
canonical=$(canonical_path "$resolved") ||
    die 'Applied symlink does not resolve to a file.'
[[ "$canonical" == "$source_file" ]] ||
    die 'Applied symlink points to an unexpected file.'
log 'Applied reviewed zsh startup file.'
