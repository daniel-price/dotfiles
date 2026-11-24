#!/usr/bin/env bash
# Inspect the public checkout, or (with explicit consent) fetch/switch and
# fast-forward main. Never reset, force, stash, merge divergent history, or
# alter an unclean checkout. Safe to run independently of machine bootstrap.
set -euo pipefail

# In apply mode Git may replace this file mid-execution. Run the complete
# updater from an in-memory Bash program first, rather than reading a script
# file while its own Git checkout is being fast-forwarded. Status mode does
# not need a snapshot and remains entirely read-only.
if [[ "${DOTFILES_UPDATE_SNAPSHOT:-}" == 1 ]]; then
    ROOT=${DOTFILES_UPDATE_ROOT:?Internal snapshot missing checkout root}
else
    ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
    if [[ "${1:-}" == --apply ]]; then
        snapshot=$(<"$ROOT/setup/update.sh") ||
            {
                printf '[error] Could not snapshot the updater.\n' >&2
                exit 1
            }
        DOTFILES_UPDATE_SNAPSHOT=1 DOTFILES_UPDATE_ROOT="$ROOT" \
            bash -c "$snapshot" dotfiles-update "$@"
        exit $?
    fi
fi
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

main() {
    REMOTE='https://github.com/daniel-price/dotfiles.git'
    mode=status
    require_current=false

    # Composed commands must stop on declined/skipped updates; ordinary --apply
    # remains an exit-zero no-op in those cases.
    skip_update() {
        log "$1"
        if [[ "$require_current" == true ]]; then
            die 'Could not verify an approved update; bootstrap will not run.'
        fi
        exit 0
    }

    usage() {
        printf '%s\n' \
            'Usage: bash setup/update.sh [--apply [--require-current]|--help]' \
            'Default: inspect the checkout locally without fetching or changing anything.' \
            '--apply: offer to fetch origin/main, then independently approve a safe' \
            'switch to main and/or fast-forward update. No force or automatic stash.' \
            '--require-current: fail when an update is skipped or declined.'
    }

    case "${1:-}" in
    -h | --help)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        usage
        exit 0
        ;;
    '') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
    --apply)
        if [[ $# -eq 2 && "$2" == --require-current ]]; then
            require_current=true
        else
            [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        fi
        mode=apply
        ;;
    *) die 'Unknown argument. Use --help for usage.' ;;
    esac

    command -v git >/dev/null 2>&1 || die 'Git is unavailable.'
    top=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null) ||
        die 'The updater must be run from its own Git checkout.'
    [[ "$top" == "$ROOT" ]] || die 'Updater source is not at its own Git checkout root.'
    [[ "$(git -C "$ROOT" rev-parse --is-bare-repository)" == false ]] ||
        die 'Cannot update a bare repository.'

    origin=$(git -C "$ROOT" remote get-url origin 2>/dev/null || :)
    case "$origin" in
    "$REMOTE" | 'https://github.com/daniel-price/dotfiles' | 'git@github.com:daniel-price/dotfiles.git') ;;
    *) die 'Unexpected origin URL; refusing fetch or checkout changes.' ;;
    esac

    branch=$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || :)
    if [[ -z "$branch" ]]; then
        skip_update 'Detached HEAD: update skipped; choose a branch manually.'
    fi
    if [[ "${DOTFILES_VERBOSE:-true}" == true || "$mode" == status || "$branch" != main ]]; then
        log "Current branch: $branch."
    fi

    changes=$(git -C "$ROOT" status --porcelain --untracked-files=all) ||
        die 'Could not inspect Git worktree and index.'
    if [[ -n "$changes" ]]; then
        log 'Working tree or index has changes (including untracked files).'
    elif [[ "${DOTFILES_VERBOSE:-true}" == true || "$mode" == status ]]; then
        log 'Working tree: clean.'
    fi

    if git -C "$ROOT" show-ref --verify --quiet refs/heads/main; then
        if git -C "$ROOT" show-ref --verify --quiet refs/remotes/origin/main; then
            counts=$(git -C "$ROOT" rev-list --left-right --count refs/heads/main...refs/remotes/origin/main) ||
                die 'Could not compare main with the cached origin/main.'
            read -r local_ahead local_behind <<<"$counts"
            if [[ "${DOTFILES_VERBOSE:-true}" == true || "$mode" == status || "$local_ahead" != 0 || "$local_behind" != 0 ]]; then
                log "Cached main vs origin/main: ahead $local_ahead, behind $local_behind (may be stale)."
            fi
        else
            log 'No cached origin/main; cannot determine freshness without fetching.'
        fi
    else
        log 'Local main is missing.'
    fi

    if [[ "$mode" == status ]]; then
        log 'Read-only status complete; use --apply to offer an update.'
        exit 0
    fi

    # Do not even fetch a dirty checkout. Untracked files are considered conflicts,
    # rather than relying on Git switch to discover problems half-way through.
    if [[ -n "$changes" ]]; then
        skip_update 'Update skipped: commit, stash manually or remove local changes first.'
    fi

    if ! confirm "Fetch the latest origin/main from $origin? (updates remote-tracking metadata only)"; then
        skip_update 'Fetch declined; checkout unchanged.'
    fi

    if ! run_concise git -C "$ROOT" fetch --no-tags origin refs/heads/main:refs/remotes/origin/main; then
        skip_update 'Could not fetch origin/main; leaving the checkout unchanged (offline bootstrap is still possible).'
    fi

    # Check for concurrent changes or branch switches between the fetch and action.
    [[ "$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || :)" == "$branch" ]] ||
        die 'Current branch changed during update; refusing to proceed.'
    [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] ||
        die 'Working tree changed during update; refusing to proceed.'
    git -C "$ROOT" show-ref --verify --quiet refs/remotes/origin/main ||
        die 'Fetched origin/main is unavailable.'

    if git -C "$ROOT" show-ref --verify --quiet refs/heads/main; then
        counts=$(git -C "$ROOT" rev-list --left-right --count refs/heads/main...refs/remotes/origin/main) ||
            die 'Could not compare local main with fetched origin/main.'
        read -r local_ahead local_behind <<<"$counts"
        if [[ "$local_ahead" -ne 0 ]]; then
            skip_update "Local main has $local_ahead commit(s) not on origin/main. No automatic switch, reset or merge."
        fi

        if [[ "$branch" == main ]]; then
            if [[ "$local_behind" -eq 0 ]]; then
                log 'main is already current with fetched origin/main.'
                exit 0
            fi
            if ! confirm "Fast-forward local main by $local_behind commit(s)?"; then
                skip_update 'Fast-forward declined; checkout unchanged.'
            fi
        else
            if ! confirm "Switch from $branch to main and fast-forward by $local_behind commit(s)?"; then
                skip_update "Branch switch declined; remaining on $branch."
            fi
            if ! run_concise git -C "$ROOT" switch main; then
                die 'Could not switch to main; no branch was reset or force-checked out.'
            fi
        fi

        if [[ "$local_behind" -gt 0 ]]; then
            # Verify the expected ancestry immediately before moving local main.
            git -C "$ROOT" merge-base --is-ancestor HEAD refs/remotes/origin/main ||
                die 'Main is no longer an ancestor of origin/main; refusing update.'
            run_concise git -C "$ROOT" merge --ff-only refs/remotes/origin/main ||
                die 'Fast-forward failed; no reset or force merge was attempted.'
            log "Fast-forwarded main by $local_behind commit(s)."
        else
            log 'Switched to up-to-date main.'
        fi
    else
        # A checkout created on a feature branch may not yet have a local main.
        if ! confirm "Create local main tracking origin/main and switch from $branch?"; then
            skip_update "Branch switch declined; remaining on $branch."
        fi
        run_concise git -C "$ROOT" switch --track -c main origin/main ||
            die 'Could not create local main; existing branch was preserved.'
        log 'Created local main from the fetched origin/main.'
    fi

    if [[ "$require_current" == false ]]; then
        log 'Checkout update complete. Run bootstrap separately to apply this version.'
    fi
}

main "$@"
