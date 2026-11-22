#!/usr/bin/env bash
# Isolated POC: separate, local Git repositories per machine profile. Installs nothing.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    local selection profile existing work repos shared home repo seen=,
    local -a chosen=() tool_inputs=()

    case "${1:-}" in
    -h | --help)
        printf '%s\n' 'Usage: bash scripts/poc/private-profiles.sh [--apply personal[,home-server][,work-mac]]' \
            'Available profiles: personal, home-server, work-mac (select one or more, comma-separated).' \
            'Default: read-only preview. --apply requires interactive confirmation.'
        return
        ;;
    '')
        [[ $# -eq 0 ]] || return 2
        printf '%s\n' 'POC: one independent local Git repository per synthetic profile.' \
            'Combine public defaults with one or more selected repositories in a disposable staged HOME.' \
            'Preview only: no files, installations, GitHub access, or changes to the real HOME.'
        return
        ;;
    --apply)
        [[ $# -eq 2 ]] || {
            printf '%s\n' 'Provide --apply personal[,home-server][,work-mac].' >&2
            return 2
        }
        selection=$2
        if [[ -z "$selection" || "$selection" == ,* || "$selection" == *, || "$selection" == *,,* ]]; then
            printf '%s\n' 'Invalid profile list; use comma-separated names without empty entries.' >&2
            return 2
        fi
        local -a requested=()
        IFS=, read -r -a requested <<<"$selection"
        for profile in "${requested[@]}"; do
            case "$profile" in
            personal | home-server | work-mac) ;;
            *)
                printf 'Unknown profile: %s\n' "$profile" >&2
                return 2
                ;;
            esac
            if [[ "$seen" == *",$profile,"* ]]; then
                printf 'Duplicate profile: %s\n' "$profile" >&2
                return 2
            fi
            seen+="$profile,"
            chosen+=("$profile")
        done
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
    for existing in git python3; do
        command -v "$existing" >/dev/null 2>&1 || {
            printf 'Missing prerequisite: %s\n' "$existing" >&2
            return 1
        }
    done
    printf 'Create separate fake Git repositories and stage profile(s) %s? [y/N] ' "$selection"
    local answer
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
    repos="$work/profile-repos"
    shared="$work/public-fixture"
    home="$work/staged-home"
    mkdir -p "$shared/bin" "$shared/zsh" "$shared/config/demo" \
        "$home/.config/zsh" "$home/.config/demo" "$home/.config/mise" "$home/.local/bin"

    # Synthetic examples, never actual credentials or employer-owned files.
    printf '[tools]\nripgrep = "15.2.0"\n' >"$shared/mise.toml"
    printf "alias poc_shared='printf shared'\n" >"$shared/zsh/aliases.zsh"
    printf 'fixture=shared\n' >"$shared/config/demo/shared.conf"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "shared-fixture\n"' >"$shared/bin/,shared-demo"
    chmod 755 "$shared/bin/,shared-demo"

    for profile in personal home-server work-mac; do
        repo="$repos/$profile-profile"
        mkdir -p "$repo/bin" "$repo/zsh" "$repo/config/demo"
        case "$profile" in
        personal)
            printf '[tools]\ngh = "2.105.0"\n' >"$repo/mise.toml"
            printf "alias poc_personal='printf personal'\n" >"$repo/zsh/aliases.zsh"
            printf 'fixture=personal\n' >"$repo/config/demo/personal.conf"
            printf '%s\n' '#!/usr/bin/env bash' 'printf "personal-fixture\n"' >"$repo/bin/,personal-demo"
            ;;
        home-server)
            printf '[tools]\nfd = "10.5.2"\n' >"$repo/mise.toml"
            printf "alias poc_server='printf server'\n" >"$repo/zsh/aliases.zsh"
            printf 'fixture=home-server\n' >"$repo/config/demo/server.conf"
            printf '%s\n' '#!/usr/bin/env bash' 'printf "server-fixture\n"' >"$repo/bin/,server-demo"
            ;;
        work-mac)
            printf '[tools]\nnode = "22.14.0"\n' >"$repo/mise.toml"
            printf "alias poc_work='printf work'\n" >"$repo/zsh/aliases.zsh"
            printf 'fixture=work-mac\n' >"$repo/config/demo/work.conf"
            printf '%s\n' '#!/usr/bin/env bash' 'printf "work-fixture\n"' >"$repo/bin/,work-demo"
            ;;
        esac
        chmod 755 "$repo"/bin/*
        printf '%s\n' '# Synthetic, standalone machine profile; no real secrets or GitHub remote.' >"$repo/README.md"
        git init -q "$repo"
        git -C "$repo" add .
        git -C "$repo" -c user.name='Dotfiles POC' -c user.email='dotfiles-poc@example.invalid' \
            commit -qm "Create synthetic $profile profile"
    done

    tool_inputs=("$shared/mise.toml")
    for profile in "${chosen[@]}"; do
        tool_inputs+=("$repos/$profile-profile/mise.toml")
    done
    python3 "$ROOT/scripts/poc/private-profile-tools.py" \
        "${tool_inputs[@]}" "$home/.config/mise/config.toml"

    # Apply shared defaults first, then profiles in the user's declared order.
    # Alias definitions are treated as inert text; semantic alias conflicts are out of scope.
    cat "$shared/zsh/aliases.zsh" >"$home/.config/zsh/aliases.zsh"
    for profile in "${chosen[@]}"; do
        cat "$repos/$profile-profile/zsh/aliases.zsh" >>"$home/.config/zsh/aliases.zsh"
    done
    stage_files "$shared" "$home"
    for profile in "${chosen[@]}"; do
        stage_files "$repos/$profile-profile" "$home"
    done

    printf 'PASS: independent synthetic repositories composed without installing software.\n'
    printf 'Local Git profile repositories: %s\n' "$repos"
    printf 'Selected profiles: %s\n' "$selection"
    printf 'Isolated staged HOME: %s\n' "$home"
    printf 'Remove this disposable workspace after inspection: %s\n' "$work"
}

stage_files() {
    local source_dir=$1 home=$2 command_file config_file dest
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
}

main "$@"
