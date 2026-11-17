#!/usr/bin/env bash
# Sourced by bootstrap; never change a login shell without explicit approval.
# Helpers take a shell registry path so CI can use isolated test fixtures.

registered_zsh() {
    local candidate=$1 shells_file=$2 entry
    [[ -x "$candidate" && -r "$shells_file" ]] || return 1
    while IFS= read -r entry || [[ -n "$entry" ]]; do
        case "$entry" in
        /*/zsh)
            if [[ -x "$entry" && "$entry" -ef "$candidate" ]]; then
                printf '%s\n' "$entry"
                return 0
            fi
            ;;
        esac
    done <"$shells_file"
    return 1
}

# Print the account's home and configured login shell on separate lines.
# Never infer the login shell from $SHELL or the running process.
login_account_record() {
    local platform=$1 username=$2 record name password uid gid gecos home shell
    local raw_home raw_shell
    case "$platform" in
    debian)
        command -v getent >/dev/null 2>&1 || return 1
        record=$(getent passwd "$username") || return 1
        [[ "$record" != *$'\n'* ]] || return 1
        IFS=: read -r name password uid gid gecos home shell <<<"$record"
        [[ "$name" == "$username" && "$home" == /* && "$shell" == /* ]] || return 1
        ;;
    macos)
        command -v dscl >/dev/null 2>&1 || return 1
        raw_home=$(dscl . -read "/Users/$username" NFSHomeDirectory 2>/dev/null) || return 1
        raw_shell=$(dscl . -read "/Users/$username" UserShell 2>/dev/null) || return 1
        case "$raw_home" in 'NFSHomeDirectory: '*) home=${raw_home#'NFSHomeDirectory: '} ;; *) return 1 ;; esac
        case "$raw_shell" in 'UserShell: '*) shell=${raw_shell#'UserShell: '} ;; *) return 1 ;; esac
        [[ "$home" == /* && "$shell" == /* && "$home" != *$'\n'* && "$shell" != *$'\n'* ]] || return 1
        ;;
    *) return 1 ;;
    esac
    printf '%s\n%s\n' "$home" "$shell"
}

offer_default_zsh() {
    local platform=$1 shells_file=$2 candidate target username record
    local account_home current_shell updated_record updated_shell
    if ! command -v zsh >/dev/null 2>&1 || ! zsh --version >/dev/null 2>&1; then
        log 'Default login shell unchanged: Zsh is unavailable.'
        return 0
    fi
    candidate=$(command -v zsh)
    if ! target=$(registered_zsh "$candidate" "$shells_file"); then
        log "Default login shell unchanged: $candidate is not an executable Zsh entry in $shells_file."
        return 0
    fi
    [[ "$(id -u)" != 0 ]] || {
        log 'Default login shell unchanged: bootstrap must not change root login shell.'
        return 0
    }
    username=$(id -un) || die 'Could not identify the current user.'
    record=$(login_account_record "$platform" "$username") || {
        log "Default login shell unchanged: could not read the login shell for $username."
        return 0
    }
    account_home=${record%%$'\n'*}
    current_shell=${record#*$'\n'}
    # An isolated HOME (tests/temporary profile) must never change the
    # actual account. Real user HOME may be a symlink to the account home.
    if [[ ! -d "$HOME" || ! -d "$account_home" || ! "$HOME" -ef "$account_home" ]]; then
        log 'Default login shell unchanged: HOME differs from the login account home.'
        return 0
    fi
    if [[ "$current_shell" == "$target" ]] ||
        [[ -x "$current_shell" && "$current_shell" -ef "$target" ]]; then
        log "Zsh is already the default login shell ($current_shell)."
        return 0
    fi
    command -v chsh >/dev/null 2>&1 ||
        die 'chsh is unavailable; default login shell was not changed.'
    log "Current login shell for $username: $current_shell; proposed: $target."
    if ! confirm "Change the login shell for $username to $target using chsh? (Takes effect after logging out/in.)"; then
        log 'Declined login shell change; current shell preserved.'
        return 0
    fi
    # No username argument: chsh can change only the invoking user's account.
    chsh -s "$target" || die 'chsh failed; login shell may be unchanged.'
    updated_record=$(login_account_record "$platform" "$username") ||
        die 'Could not verify the login shell after chsh.'
    updated_shell=${updated_record#*$'\n'}
    [[ "$updated_shell" == "$target" ]] ||
        die "chsh returned successfully but account login shell is $updated_shell, not $target."
    log "Default login shell changed to $target. Log out and back in to use it."
}
