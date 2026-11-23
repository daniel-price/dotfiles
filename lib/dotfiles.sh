#!/usr/bin/env bash
# Apply independent mise-managed dotfiles while preserving conflicting targets.
# Requires the reviewed machine tool set (including jq) to be provisioned first.

apply_reviewed_dotfiles() {
    local mise=$1 status_json rows state target
    local zellij_target="$HOME/.config/zellij/config.kdl"
    local failed=0 backup timestamp suffix
    local candidate_count=0 reviewed_count=0
    local -a candidates=() reviewed=()

    status_json=$("$mise" -C / dot status --json) || {
        log 'Could not inspect mise-managed dotfiles.'
        return 1
    }
    rows=$(printf '%s\n' "$status_json" | "$mise" -C / exec -- jq -r '.files[] | [.state, .target] | @tsv') || {
        log 'Could not read mise dotfile status (jq is required).'
        return 1
    }

    while IFS=$'\t' read -r state target; do
        [[ -n "$state" ]] || continue
        case "$target" in
        \~/*) target="$HOME/${target:2}" ;;
        esac
        [[ -n "$target" ]] || {
            failed=1
            continue
        }

        case "$state" in
        applied | tracked) ;;
        missing | differs)
            if [[ ! -e "$target" && ! -L "$target" ]] ||
                [[ "$target" == "$zellij_target" && -f "$target" && ! -L "$target" ]]; then
                candidates+=("$target")
                candidate_count=$((candidate_count + 1))
            else
                printf '[error] Dotfile conflict; left untouched: %s\n' "$target" >&2
                failed=1
            fi
            ;;
        *)
            printf '[error] Dotfile %s has unresolved state: %s\n' "$target" "$state" >&2
            failed=1
            ;;
        esac
    done <<<"$rows"

    # Bash 3.2 (macOS) treats an empty array expansion as unbound under set -u.
    if ((candidate_count > 0)); then
        for target in "${candidates[@]}"; do
            if [[ "$target" == "$zellij_target" && -f "$target" && ! -L "$target" ]]; then
                if "$mise" -C / dot apply --dry-run --force "$target"; then
                    reviewed+=("$target")
                    reviewed_count=$((reviewed_count + 1))
                else
                    printf '[error] Could not preview dotfile: %s\n' "$target" >&2
                    failed=1
                fi
            elif "$mise" -C / dot apply --dry-run "$target"; then
                reviewed+=("$target")
                reviewed_count=$((reviewed_count + 1))
            else
                printf '[error] Could not preview dotfile: %s\n' "$target" >&2
                failed=1
            fi
        done
    fi

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

    # Catch all remaining differences, not just conflicts discovered up front.
    if ! "$mise" -C / dot status --missing; then
        log 'Some managed dotfiles remain unapplied or conflicting.'
        failed=1
    fi
    return "$failed"
}
