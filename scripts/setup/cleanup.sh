#!/usr/bin/env bash
# Conservative, opt-in cleanup of the public mise-managed machine setup.
# Does not remove system packages, mise, Git, checkout files or private overlays.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"
trap 'report_error "$?" "$LINENO"' ERR

usage() {
    printf '%s\n' \
        'Usage: bash scripts/setup/cleanup.sh [--apply|--help]' \
        'Default: preview removal of the reviewed zsh symlink and pinned mise tools.' \
        '--apply: approve each eligible removal interactively (defaults to no).' \
        'Never removes system packages, mise, Git, the checkout or private overlays.'
}

mode=preview
case "${1:-}" in
-h | --help)
    [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
    usage
    exit 0
    ;;
'') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
--apply)
    [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
    mode=apply
    ;;
*) die 'Unknown argument. Use --help for usage.' ;;
esac

[[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must be an existing directory.'
manifest="$ROOT/scripts/setup/mise.toml"
[[ -f "$manifest" && ! -L "$manifest" ]] || die 'Reviewed machine manifest is missing.'
mise=$(mise_command) || die 'mise is unavailable; no cleanup action was taken.'
mise_supports_dot "$mise" ||
    die 'mise 2026.11.9 or newer is required; no cleanup action was taken.'

# Prevent repo-development settings from affecting cleanup. Only the explicit
# reviewed machine manifest is active, even when invoked from another directory.
export MISE_GLOBAL_CONFIG_FILE="$manifest"
log 'Only the reviewed ~/.zshrc and exact pinned Neovim/Zellij versions are eligible.'
log 'Versions installed by mise are shared with other projects; uninstalling them may affect those projects.'
log 'System packages, mise, the Git checkout and private profiles are always preserved.'

target="$HOME/.zshrc"
source_file="$ROOT/.config/zsh/zshrc"
[[ -f "$source_file" && ! -L "$source_file" ]] ||
    die 'Reviewed zsh source file is missing.'
if [[ -L "$target" && "$target" -ef "$source_file" ]]; then
    log "Preview removal of reviewed zsh symlink: $target"
    "$mise" -C / dot unapply --dry-run "$target" ||
        die 'mise could not preview the reviewed zsh removal.'
    if [[ "$mode" == apply ]] && confirm "Remove the reviewed symlink at $target?"; then
        # Recheck immediately before acting; mise itself refuses changed links.
        [[ -L "$target" && "$target" -ef "$source_file" ]] ||
            die 'The reviewed zsh symlink changed after preview; refusing removal.'
        "$mise" -C / dot unapply --yes "$target" ||
            die 'mise failed to unapply the reviewed zsh link.'
        [[ ! -L "$target" ]] || die 'The reviewed zsh symlink still exists.'
        log 'Removed the reviewed zsh symlink.'
    fi
elif [[ -L "$target" || -e "$target" ]]; then
    log "Preserving existing ~/.zshrc: not the reviewed managed symlink."
else
    log 'No reviewed ~/.zshrc symlink to remove.'
fi

for tool in neovim zellij; do
    version=$("$mise" -C / config get --file "$manifest" "tools.$tool") ||
        die "Cannot read pinned $tool version from the machine manifest."
    # Never interpret 'latest', a range, or another unpinned request as a
    # destructive uninstall target. Versions must be exact numeric releases.
    [[ "$version" =~ ^[0-9]+([.][0-9]+)+$ ]] ||
        die "Refusing to remove $tool: manifest version is not an exact release."
    spec="$tool@$version"
    log "Preview removal of shared mise tool version: $spec"
    if "$mise" -C / uninstall --dry-run-code "$spec"; then
        log "$spec is not installed; skipped."
        continue
    else
        status=$?
    fi
    [[ "$status" -eq 1 ]] || die "mise could not inspect $spec for removal."
    if [[ "$mode" == apply ]] && confirm "Uninstall $spec? Other projects might use it."; then
        "$mise" -C / uninstall --yes "$spec" || die "mise could not uninstall $spec."
        log "Uninstalled $spec."
    fi
done

if [[ "$mode" == preview ]]; then
    log 'Preview only; no changes were made. Rerun with --apply to review removals.'
else
    log 'Cleanup finished. No system packages, private config, mise or checkout files were removed.'
fi
