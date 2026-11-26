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

# Called only after the explicit package-install confirmation. APT invokes sudo
# via PATH (see the mise package preview). Authenticate on the original terminal
# before starting Gum, then disallow later password prompts during the step.
# The wrapper is private, temporary and scoped to this one approved invocation.
install_reviewed_packages() (
    local platform=$1 mise=$2 sudo_path scratch
    if [[ "$platform" != debian ]]; then
        # Homebrew may invoke its own authentication UI; do not hide it.
        run_step --terminal-input 'Installing OS packages' "$mise" -C / bootstrap packages apply --yes
        return $?
    fi

    sudo_path=$(type -P sudo) || {
        error 'sudo is required to install the reviewed OS packages.'
        return 1
    }
    if ! "$sudo_path" -n -v >/dev/null 2>&1; then
        "$sudo_path" -v || {
            error 'Could not authenticate for OS package installation.'
            return 1
        }
    fi

    scratch=$(make_temp_dir_physical dotfiles-package-sudo) || {
        error 'Could not create the temporary noninteractive sudo wrapper.'
        return 1
    }
    trap 'rm -rf -- "$scratch"' EXIT
    cat >"$scratch/sudo" <<'SUDO' || return 1
#!/usr/bin/env bash
exec "$DOTFILES_PACKAGE_SUDO" -n "$@"
SUDO
    chmod 700 "$scratch/sudo" || return 1

    export DOTFILES_PACKAGE_SUDO="$sudo_path"
    export PATH="$scratch:$PATH"
    run_step 'Installing OS packages' "$mise" -C / bootstrap packages apply --yes
)
