#!/usr/bin/env bash
# Isolated POC for optional, private machine profiles. Never installs tools.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    case "${1:-}" in
    -h | --help)
        printf '%s\n' 'Usage: bash scripts/poc/private-profiles.sh [--apply laptop|--apply home-server]' \
            'Default: preview only. --apply requires an interactive confirmation.'
        return
        ;;
    '')
        [[ $# -eq 0 ]] || return 2
        printf '%s\n' 'POC: create a temporary local Git repo containing fake laptop and home-server profiles.' \
            'Compose only the selected profile with a synthetic shared baseline in a disposable HOME.' \
            'Preview: nothing created or installed; no private GitHub repo or real HOME is touched.'
        return
        ;;
    --apply)
        [[ $# -eq 2 && ( "$2" == laptop || "$2" == home-server ) ]] || {
            printf '%s\n' 'Choose --apply laptop or --apply home-server.' >&2
            return 2
        }
        profile=$2
        ;;
    *)
        printf '%s\n' 'Unknown option; see --help.' >&2
        return 2
        ;;
    esac

    [[ -t 0 && -t 1 ]] || {
        printf '%s\n' 'Interactive terminal required; no files created.' >&2
        return 1
    }
    for tool in git python3; do
        command -v "$tool" >/dev/null 2>&1 || {
            printf 'Missing prerequisite: %s\n' "$tool" >&2
            return 1
        }
    done
    printf 'Create isolated fake private repo and stage the %s profile? [y/N] ' "$profile"
    IFS= read -r answer || answer=
    case "$answer" in
    y | Y | yes) ;;
    *)
        printf '%s\n' 'Declined; nothing created.'
        return
        ;;
    esac

    umask 077
    work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-profiles-poc.XXXXXXXX")
    private="$work/private-fixture"
    shared="$work/shared-fixture"
    home="$work/staged-home"
    mkdir -p "$private/profiles/laptop/bin" "$private/profiles/laptop/zsh" \
        "$private/profiles/laptop/config/demo" \
        "$private/profiles/home-server/bin" "$private/profiles/home-server/zsh" \
        "$private/profiles/home-server/config/demo" \
        "$shared/bin" "$shared/zsh" "$shared/config/demo" \
        "$home/.config/zsh" "$home/.config/demo" "$home/.config/mise" "$home/.local/bin"

    # These are deliberately inert, public test fixtures, never actual credentials.
    printf '[tools]\nripgrep = "15.2.0"\n' >"$shared/mise.toml"
    printf '[tools]\ngh = "2.105.0"\n' >"$private/profiles/laptop/mise.toml"
    printf '[tools]\nfd = "10.5.2"\n' >"$private/profiles/home-server/mise.toml"
    printf "alias poc_shared='printf shared'\n" >"$shared/zsh/aliases.zsh"
    printf "alias poc_laptop='printf laptop'\n" >"$private/profiles/laptop/zsh/aliases.zsh"
    printf "alias poc_server='printf server'\n" >"$private/profiles/home-server/zsh/aliases.zsh"
    printf 'fixture=shared\n' >"$shared/config/demo/shared.conf"
    printf 'fixture=laptop\n' >"$private/profiles/laptop/config/demo/laptop.conf"
    printf 'fixture=home-server\n' >"$private/profiles/home-server/config/demo/server.conf"
    printf '#!/usr/bin/env bash\nprintf "shared-fixture\\n"\n' >"$shared/bin/,shared-demo"
    printf '#!/usr/bin/env bash\nprintf "laptop-fixture\\n"\n' >"$private/profiles/laptop/bin/,laptop-demo"
    printf '#!/usr/bin/env bash\nprintf "server-fixture\\n"\n' >"$private/profiles/home-server/bin/,server-demo"
    chmod 755 "$shared/bin/,shared-demo" "$private/profiles/laptop/bin/,laptop-demo" \
        "$private/profiles/home-server/bin/,server-demo"
    printf '%s\n' '# Synthetic profiles, not real secrets. No GitHub remote is configured.' \
        'Profiles can contain pinned tools, shell aliases, commands and application config.' \
        >"$private/README.md"
    git init -q "$private"
    git -C "$private" add .
    git -C "$private" -c user.name='Dotfiles POC' \
        -c user.email='dotfiles-poc@example.invalid' commit -qm 'Create two synthetic machine profiles'

    selected="$private/profiles/$profile"
    python3 "$ROOT/scripts/poc/private-profile-tools.py" \
        "$shared/mise.toml" "$selected/mise.toml" "$home/.config/mise/config.toml"
    cat "$shared/zsh/aliases.zsh" "$selected/zsh/aliases.zsh" >"$home/.config/zsh/aliases.zsh"
    for source_dir in "$shared" "$selected"; do
        for command_file in "$source_dir"/bin/*; do
            [[ -f "$command_file" ]] || continue
            dest="$home/.local/bin/$(basename "$command_file")"
            [[ ! -e "$dest" && ! -L "$dest" ]] || {
                printf 'Refusing conflicting command: %s\n' "$dest" >&2
                return 1
            }
            cp -p "$command_file" "$dest"
        done
        for config_file in "$source_dir"/config/demo/*; do
            [[ -f "$config_file" ]] || continue
            dest="$home/.config/demo/$(basename "$config_file")"
            [[ ! -e "$dest" && ! -L "$dest" ]] || {
                printf 'Refusing conflicting config: %s\n' "$dest" >&2
                return 1
            }
            cp "$config_file" "$dest"
        done
    done
    printf 'PASS: selected synthetic profile staged without installing software.\n'
    printf 'Local Git fixture: %s\n' "$private"
    printf 'Selected profile: %s\n' "$profile"
    printf 'Isolated HOME: %s\n' "$home"
    printf 'Remove this disposable workspace after inspection: %s\n' "$work"
}

main "$@"
