#!/usr/bin/env bash
# Deploy mise-managed dotfiles without allowing one conflict to block others.

apply_reviewed_dotfiles() {
    local mise=$1 status_json rows state target backup timestamp suffix
    local failed=0 missing_count=0 conflict_count=0
    local -a missing=() conflicts=() apply_step=(run_concise)
    if declare -F run_provision_step >/dev/null 2>&1 && [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        apply_step=(run_provision_step 'Applying mise-managed dotfile')
        # These are reviewed Base symlinks, not decrypted secret files.
    fi

    # Mise is the source of truth for declarations and pending changes.
    status_json=$("$mise" -C / dot status --json) || {
        log 'Could not inspect mise-managed dotfiles.'
        return 1
    }
    # Inspect every declaration: mise can report an old symlink as applied
    # after normalising ../ segments, even when an intermediate directory was
    # removed and the symlink no longer resolves.
    rows=$(printf '%s\n' "$status_json" |
        "$mise" -C / exec -- jq -r '.files[] | [.state, .mode, .target] | @tsv') || {
        log 'Could not read mise dotfile status (jq is required).'
        return 1
    }

    # Preview every pending target before making any changes.
    while IFS=$'\t' read -r state mode target; do
        [[ -n "$state" ]] || continue
        case "$target" in
        \~/*) target="$HOME/${target:2}" ;;
        esac

        # A broken "applied" symlink is still a conflict; back it up and
        # let mise deploy the current declaration after explicit approval.
        if [[ "$state" == applied ]]; then
            if [[ "$mode" != symlink || ! -L "$target" || -e "$target" ]]; then
                continue
            fi
            log "Broken mise-managed symlink: $target -> $(readlink "$target")"
        elif [[ "$state" != missing && "$state" != differs && "$state" != source_missing ]]; then
            continue
        fi

        if [[ "$state" == source_missing ]]; then
            printf '[error] Dotfile source missing: %s\n' "$target" >&2
            failed=1
        elif [[ ! -e "$target" && ! -L "$target" ]]; then
            if run_concise "$mise" -C / dot apply --dry-run "$target"; then
                missing+=("$target")
                missing_count=$((missing_count + 1))
            else
                printf '[error] Dotfile preview failed: %s\n' "$target" >&2
                failed=1
            fi
        elif [[ -f "$target" || -L "$target" ]]; then
            # Even a foreign symlink is a conflict: mise may repoint it without --force.
            if run_concise "$mise" -C / dot apply --dry-run --force "$target"; then
                conflicts+=("$target")
                conflict_count=$((conflict_count + 1))
            else
                printf '[error] Dotfile conflict could not be previewed: %s\n' "$target" >&2
                failed=1
            fi
        else
            printf '[error] Dotfile is neither a regular file nor a symlink; left untouched: %s\n' "$target" >&2
            failed=1
        fi
    done <<<"$rows"

    if ((missing_count > 0)); then
        if confirm "Apply $missing_count missing mise-managed dotfile(s)?"; then
            for target in "${missing[@]}"; do
                if ! "${apply_step[@]}" "$mise" -C / dot apply --yes "$target"; then
                    printf '[error] Dotfile apply failed: %s\n' "$target" >&2
                    failed=1
                fi
            done
        else
            log 'Declined installation of missing dotfiles.'
            failed=1
        fi
    fi

    if ((conflict_count > 0)); then
        for target in "${conflicts[@]}"; do
            # Existing content is never overwritten automatically. Every conflict
            # gets a separate approval and an on-disk backup before mise applies.
            if ! confirm "Back up and replace conflicting dotfile $target?"; then
                log "Skipped conflicting dotfile: $target"
                failed=1
                continue
            fi
            timestamp=$(date +%Y%m%d-%H%M%S)
            backup="$target.backup-$timestamp"
            suffix=0
            while [[ -e "$backup" || -L "$backup" ]]; do
                suffix=$((suffix + 1))
                backup="$target.backup-$timestamp-$suffix"
            done
            if ! mv -- "$target" "$backup"; then
                printf '[error] Could not back up dotfile: %s\n' "$target" >&2
                failed=1
                continue
            fi
            log "Backed up $target to $backup"
            if ! "${apply_step[@]}" "$mise" -C / dot apply --yes "$target"; then
                printf '[error] Dotfile apply failed: %s\n' "$target" >&2
                failed=1
                if [[ ! -e "$target" && ! -L "$target" ]]; then
                    if mv -- "$backup" "$target"; then
                        log "Restored $target after failed deployment."
                    else
                        printf '[error] Could not restore dotfile backup: %s\n' "$backup" >&2
                    fi
                fi
            fi
        done
    fi

    if ! run_concise "$mise" -C / dot status --missing; then
        log 'Some mise-managed dotfiles remain unapplied or conflicting.'
        failed=1
    fi
    # Do not trust "applied" alone: it does not guarantee a symlink resolves.
    while IFS=$'\t' read -r state mode target; do
        [[ "$mode" == symlink ]] || continue
        case "$target" in
        \~/*) target="$HOME/${target:2}" ;;
        esac
        if [[ -L "$target" && ! -e "$target" ]]; then
            printf '[error] Mise-managed symlink is still broken: %s\n' "$target" >&2
            failed=1
        fi
    done <<<"$rows"
    if ((failed == 0)); then
        log "Mise-managed dotfiles verified."
    fi
    return "$failed"
}
