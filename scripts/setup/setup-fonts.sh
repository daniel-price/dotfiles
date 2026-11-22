#!/usr/bin/env bash
# Optional user-local MesloLGS Nerd Font installation for Powerlevel10k/Ghostty.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$ROOT/scripts/lib/os.sh"

main() {
    usage() {
        printf '%s\n' \
            'Usage: bash scripts/setup/setup-fonts.sh [--apply|--help]' \
            'Preview installation of the four Powerlevel10k MesloLGS Nerd Font faces.' \
            '--apply: explicitly approve downloading and installing missing fonts.' \
            'Existing font files are never overwritten.'
    }

    local mode=preview platform target font file scratch url header
    local media_commit='389133fb8c9a2347929a23702ce3039aacc46c3d'
    local -a fonts missing

    case "${1:-}" in
    -h | --help)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        usage
        return
        ;;
    '') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
    --apply)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        mode=apply
        ;;
    *) die 'Unknown argument. Use --help for usage.' ;;
    esac

    [[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must be an existing directory.'
    [[ "$(id -u)" != 0 ]] || die 'Do not install user fonts as root.'
    # shellcheck disable=SC2119
    platform=$(detect_os) || die 'Unsupported OS for user font installation.'
    case "$platform" in
    macos) target="$HOME/Library/Fonts" ;;
    debian) target="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
    *) die 'Unsupported platform for fonts.' ;;
    esac

    [[ ! -L "$target" ]] || die "Font directory is a symlink; refusing: $target"
    [[ ! -e "$target" || -d "$target" ]] || die "Font path is not a directory: $target"

    fonts=(
        'MesloLGS NF Regular.ttf'
        'MesloLGS NF Bold.ttf'
        'MesloLGS NF Italic.ttf'
        'MesloLGS NF Bold Italic.ttf'
    )
    missing=()
    for font in "${fonts[@]}"; do
        file="$target/$font"
        if [[ -L "$file" || (-e "$file" && ! -f "$file") ]]; then
            die "Conflicting font path; refusing to replace it: $file"
        fi
        [[ -f "$file" ]] || missing+=("$font")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log "All four MesloLGS NF font files are already present at $target."
        return
    fi
    log "Missing ${#missing[@]} MesloLGS NF font file(s) in $target:"
    printf '  %s\n' "${missing[@]}"
    log "Source: https://github.com/romkatv/powerlevel10k-media (commit $media_commit)."

    if [[ "$mode" == preview ]]; then
        log 'Preview only; no fonts downloaded. Run --apply to approve.'
        return
    fi
    if ! confirm "Download and install ${#missing[@]} missing font file(s) in $target?"; then
        log 'Font installation declined; nothing changed.'
        return
    fi
    command -v curl >/dev/null 2>&1 || die 'curl is required to download the fonts.'
    scratch=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fonts.XXXXXX") ||
        die 'Could not create temporary font download directory.'
    trap 'rm -rf -- "$scratch"' EXIT

    # Stage and inspect every download before making changes to the font directory.
    for font in "${missing[@]}"; do
        url="https://raw.githubusercontent.com/romkatv/powerlevel10k-media/$media_commit/${font// /%20}"
        file="$scratch/$font"
        curl --fail --location --silent --show-error --output "$file" "$url" ||
            die "Font download failed: $font (no fonts installed)."
        header=$(od -An -tx1 -N4 "$file" | tr -d '[:space:]')
        [[ "$header" == 00010000 || "$header" == 4f54544f ]] ||
            die "Downloaded file is not an OpenType/TrueType font: $font."
    done

    mkdir -p -- "$target" || die "Could not create font directory: $target"
    for font in "${missing[@]}"; do
        file="$target/$font"
        [[ ! -e "$file" && ! -L "$file" ]] ||
            die "Font destination appeared during download; preserving it: $file"
        mv -- "$scratch/$font" "$file" || die "Could not install font: $font"
    done
    if [[ "$platform" == debian ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$target" || log 'Font files installed, but fc-cache failed; restart Ghostty if needed.'
    fi
    rm -rf -- "$scratch"
    trap - EXIT
    log 'MesloLGS NF installed. Restart Ghostty (or reload its configuration).'
}

main "$@"
