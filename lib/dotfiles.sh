#!/usr/bin/env bash
# Apply independent mise-managed dotfiles while preserving conflicting targets.
# Requires the reviewed machine tool set (including jq) to be provisioned first.

apply_reviewed_dotfiles() {
    local mise=$1 status_json targets target
    local zellij_target="$HOME/.config/zellij/config.kdl"
    local failed=0 backup timestamp suffix reviewed_count=0
    local -a reviewed=()

    status_json=$("$mise" -C / dot status --json) || {
        log 'Could not inspect mise-managed dotfiles.'
        return 1
    }
    targets=$(printf '%s\n' "$status_json" |
        "$mise" -C / exec -- jq -r '.files[] | select(.state == "missing" or .state == "differs") | .target') || {
        log 'Could not read mise dotfile status (jq is required).'
        return 1
    }

    # Let mise decide which entries can be safely applied: do not reimplement
    # its symlink, content, or conflict detection in shell.
    while IFS= read -r target; do
        [[ -n "$target" ]] || continue
        case "$target" in
        \~/*) target="$HOME/${target:2}" ;;
        esac

        # Preserve the existing recoverable Zellij regular-file migration.
        if [[ "$target" == "$zellij_target" && -f "$target" && ! -L "$target" ]]; then
            if "$mise" -C / dot apply --dry-run --force "$target"; then
                reviewed+=("$target")
                reviewed_count=$((reviewed_count + 1))
            else
                printf '[error] Dotfile preview failed: %s\n' "$target" >&2
                failed=1
            fi
        elif "$mise" -C / dot apply --dry-run "$target"; then
            reviewed+=("$target")
            reviewed_count=$((reviewed_count + 1))
        else
            printf '[error] Dotfile conflict or preview failure; left untouched: %s\n' "$target" >&2
            failed=1
        fi
    done <<<"$targets"

    if ((reviewed_count > 0)); then
        if confirm "Apply $reviewed_count reviewed dotfile(s), backing up an existing regular Zellij config?"; then
            for target in "${reviewed[@]}"; do
                backup=''
                if [[ "$target" == "$zellij_target" && -f "$target" && ! -L "$target" ]]; then
                    timestamp=$(date +%Y%m%d-%H%M%S)
                    backup="$target.backup-$timestamp"
                    suffix=0
                    while [[ -e "$backup" || -L "$backup" ]]; do
                        suffix=$((suffix + 1))
                        backup="$target.backup-$timestamp-$suffix"
                    done
                    if ! mv -- "$target" "$backup"; then
                        printf '[error] Could not back up Zellij config: %s\n' "$target" >&2
                        failed=1
                        continue
                    fi
                    log "Backed up existing Zellij config to $backup"
                fi
                if ! "$mise" -C / dot apply --yes "$target"; then
                    printf '[error] Could not apply dotfile: %s\n' "$target" >&2
                    failed=1
                    if [[ -n "$backup" && ! -e "$target" && ! -L "$target" ]]; then
                        if mv -- "$backup" "$target"; then
                            log 'Restored original Zellij config after failed deployment.'
                        else
                            printf '[error] Could not restore Zellij backup: %s\n' "$backup" >&2
                        fi
                    fi
                fi
            done
        else
            log 'Dotfile deployment declined; missing targets remain unchanged.'
            failed=1
        fi
    fi

    # Capture missing sources and unresolved conflicts in the final exit status.
    if ! "$mise" -C / dot status --missing; then
        log 'Some managed dotfiles remain unapplied or conflicting.'
        failed=1
    fi
    return "$failed"
}
