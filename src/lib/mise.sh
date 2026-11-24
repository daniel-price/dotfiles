#!/usr/bin/env bash
mise_command() {
    local candidate
    if command -v mise >/dev/null 2>&1; then
        printf 'mise\n'
        return 0
    fi
    if [[ -n "${HOME:-}" ]]; then
        candidate="$HOME/.local/bin/mise"
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi
    return 1
}

trust_mise_config_dir() {
    local dir=$1
    local trusted=${MISE_TRUSTED_CONFIG_PATHS:-}
    if [[ -n "$trusted" ]]; then
        export MISE_TRUSTED_CONFIG_PATHS="$dir:$trusted"
    else
        export MISE_TRUSTED_CONFIG_PATHS="$dir"
    fi
}

toml_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '%s' "$value"
}

mise_supports_dot() {
    local mise=$1 output version major rest minor patch
    output=$("$mise" --version 2>/dev/null) || return 1
    version=${output%% *}
    version=${version#v}
    major=${version%%.*}
    rest=${version#*.}
    [[ "$rest" != "$version" ]] || return 1
    minor=${rest%%.*}
    patch=${rest#*.}
    [[ "$patch" != "$rest" ]] || return 1
    patch=${patch%%.*}
    case "$major$minor$patch" in
    '' | *[!0-9]*) return 1 ;;
    esac
    if ((major > 2026)) ||
        ((major == 2026 && minor > 11)) ||
        ((major == 2026 && minor == 11 && patch >= 9)); then
        return 0
    fi
    return 1
}
