#!/usr/bin/env bash
# Deploy mise-managed dotfiles without allowing one conflict to block others.

apply_reviewed_dotfiles() {
    local mise=$1 status_json rows state target backup timestamp suffix
    local failed=0 missing_count=0 conflict_count=0
    local -a missing=() conflicts=()

    # Mise is the source of truth for declarations and pending changes.
    status_json=$("$mise" -C / dot status --json) || {
        log 'Could not inspect mise-managed dotfiles.'
        return 1
    }
    rows=$(printf '%s\n' "$status_json" |
        "$mise" -C / exec -- jq -r '.files[] | select(.state == "missing" or .state == "differs" or .state == "source_missing") | [.state, .target] | @tsv') || {
        log 'Could not read mise dotfile status (jq is required).'
        return 1
    }

    # Preview every pending target before making any changes.
    while IFS=$'\t' read -r state target; do
        [[ -n "$state" ]] || continue
        case "$target" in
        \~/*) target="$HOME/${target:2}" ;;
        esac

        if [[ "$state" == source_missing ]]; then
            printf '[error] Dotfile source missing: %s\n' "$target" >&2
            failed=1
        elif [[ ! -e "$target" && ! -L "$target" ]]; then
            if "$mise" -C / dot apply --dry-run "$target"; then
                missing+=("$target")
                missing_count=$((missing_count + 1))
            else
                printf '[error] Dotfile preview failed: %s\n' "$target" >&2
                failed=1
            fi
        elif [[ -f "$target" || -L "$target" ]]; then
            # Even a foreign symlink is a conflict: mise may repoint it without --force.
            if "$mise" -C / dot apply --dry-run --force "$target"; then
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
                if ! "$mise" -C / dot apply --yes "$target"; then
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
            if ! "$mise" -C / dot apply --yes "$target"; then
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

    if ! "$mise" -C / dot status --missing; then
        log 'Some mise-managed dotfiles remain unapplied or conflicting.'
        failed=1
    fi
    return "$failed"
}
