#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"
trap 'report_error "$?" "$LINENO"' ERR

case "${1:-}" in
-h | --help)
    [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
    printf '%s\n' 'Usage: bash scripts/setup/deploy-zsh-config.sh' \
        'Preview and deploy the reviewed ~/.zshrc using declarative mise dotfiles.'
    exit 0
    ;;
'') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
*) die 'Unknown argument; use --help.' ;;
esac

[[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must be an existing directory.'
target="$HOME/.zshrc"
source_file="$ROOT/.config/zsh/zshrc"
[[ -f "$source_file" && ! -L "$source_file" ]] || die 'Reviewed zsh source is missing.'
if [[ -L "$target" ]]; then
    if [[ "$target" -ef "$source_file" ]]; then
        log 'Reviewed zsh startup file is already applied; no changes made.'
        exit 0
    fi
    die 'Existing target is a different symlink; resolve this conflict manually.'
elif [[ -e "$target" ]]; then
    die 'Existing target is a real file or directory; resolve this conflict manually.'
fi

mise=$(mise_command) || die 'mise is unavailable; bootstrap it first.'
mise_supports_dot "$mise" || die 'mise 2026.11.9 or newer is required for dotfile deployment.'
export MISE_GLOBAL_CONFIG_FILE="$ROOT/.config/mise/config.toml"
"$mise" -C / dot diff || die 'mise dot diff failed.'
"$mise" -C / dot apply --dry-run || die 'mise dot dry run failed.'
if ! confirm "Apply the reviewed ~/.zshrc symlink at $target?"; then
    log 'Zsh deployment declined; no changes made.'
    exit 0
fi
"$mise" -C / dot apply || die 'mise dot apply failed.'
[[ -L "$target" && "$target" -ef "$source_file" ]] || die 'mise did not deploy the expected symlink.'
log 'Applied reviewed zsh startup file.'
