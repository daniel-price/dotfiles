#!/usr/bin/env bash
# cosmic implementation for persistent Caps Lock -> Ctrl remapping.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

[[ "${1:-}" == --apply && $# -eq 1 ]] ||
    die 'Usage: bash scripts/platforms/keyboard/cosmic.sh --apply'

config="$HOME/.config/cosmic/com.system76.CosmicComp/v1/xkb_config"
if [[ ! -f "$config" || -L "$config" ]]; then
    log 'COSMIC keyboard config not found as a regular file; open COSMIC Settings > Input Devices > Keyboard to configure Caps Lock manually.'
    exit 0
fi
# COSMIC stores all XKB options in one RON field. Never replace the
# whole file or discard the user's layout, variant, or other options.
updated=''
found=0
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^(.*options:[[:space:]]*)Some\(\"([^\"]*)\"\)(.*)$ ]]; then
        prefix=${BASH_REMATCH[1]}
        options=${BASH_REMATCH[2]}
        suffix=${BASH_REMATCH[3]}
        found=$((found + 1))
        case ",$options," in
        *,ctrl:nocaps,*) ;;
        *)
            # Do not silently override an incompatible Caps/Ctrl mapping.
            if [[ ",$options," =~ ,(caps:|ctrl:)[^,]*, ]]; then
                log 'COSMIC already has a Caps/Ctrl XKB option; leaving it unchanged.'
                exit 0
            fi
            options="${options:+$options,}ctrl:nocaps"
            ;;
        esac
        line="${prefix}Some(\"$options\")${suffix}"
    elif [[ "$line" =~ ^(.*options:[[:space:]]*)None(.*)$ ]]; then
        found=$((found + 1))
        line="${BASH_REMATCH[1]}Some(\"ctrl:nocaps\")${BASH_REMATCH[2]}"
    fi
    updated+="$line"$'\n'
done <"$config"
if [[ "$found" -ne 1 ]]; then
    log 'COSMIC keyboard options format was unexpected; no changes made.'
    exit 0
fi
if [[ "$updated" == "$(cat "$config")"$'\n' ]]; then
    log 'COSMIC Caps Lock is already mapped to Ctrl.'
    exit 0
fi
if confirm 'Set Caps Lock to act as an additional Ctrl key in COSMIC keyboard settings?'; then
    temp=$(mktemp "$config.XXXXXX")
    trap 'rm -f -- "$temp"' EXIT
    printf '%s' "$updated" >"$temp"
    chmod --reference="$config" "$temp"
    mv -- "$temp" "$config"
    trap - EXIT
    log 'Saved COSMIC mapping. Log out and back in if the change is not immediate.'
fi
