#!/usr/bin/env bash
# Native macOS hidutil mapping, re-applied on login by a user LaunchAgent.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

main() {
    [[ "${1:-}" == --apply && $# -eq 1 ]] ||
        die 'Usage: bash setup/platforms/keyboard/macos.sh --apply'
    [[ "$(uname -s)" == Darwin ]] || die 'macOS only.'
    command -v hidutil >/dev/null 2>&1 || die 'macOS hidutil is unavailable.'

    agent_dir="$HOME/Library/LaunchAgents"
    agent="$agent_dir/com.daniel-price.dotfiles.caps-control.plist"
    mapping='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771129,"HIDKeyboardModifierMappingDst":30064771296}]}'

    # Do not replace another app's keyboard mapping: hidutil --set replaces the
    # entire UserKeyMapping array. Apple modifier settings are separate; users
    # should review them in System Settings if they have custom overrides.
    current=$(hidutil property --get UserKeyMapping 2>/dev/null) ||
        die 'Cannot inspect existing hidutil mappings; leaving them unchanged.'
    case "$current" in
    '' | '(null)' | null | '[]' | '()' | 'UserKeyMapping = (\n)' | 'UserKeyMapping = (\n\n)') ;;
    *)
        if [[ ! -f "$agent" ]]; then
            log 'Existing hidutil keyboard mapping detected; refusing to overwrite it.'
            exit 0
        fi
        ;;
    esac

    # No shell or external downloaded script is executed on login.
    plist=$(
        cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.daniel-price.dotfiles.caps-control</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771129,"HIDKeyboardModifierMappingDst":30064771296}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST
    )
    if [[ -e "$agent" || -L "$agent" ]]; then
        [[ -f "$agent" && ! -L "$agent" ]] ||
            die "Existing LaunchAgent is not a regular file: $agent"
        if [[ "$(cat "$agent")" == "$plist" ]]; then
            log 'macOS Caps Lock LaunchAgent is already installed.'
            exit 0
        fi
        log 'LaunchAgent path is already in use; leaving it unchanged.'
        exit 0
    fi

    if ! confirm 'Map Caps Lock to Control on macOS and install a per-user login LaunchAgent?'; then
        log 'Mac keyboard mapping declined.'
        exit 0
    fi
    mkdir -p "$agent_dir"
    temp=$(mktemp "$agent_dir/.caps-control.XXXXXX")
    trap 'rm -f -- "$temp"' EXIT
    printf '%s\n' "$plist" >"$temp"
    chmod 600 "$temp"
    plutil -lint "$temp" >/dev/null || die 'Generated LaunchAgent is not valid plist.'
    # Apply immediately, then persist. The agent itself will run at next login.
    hidutil property --set "$mapping" >/dev/null ||
        die 'hidutil rejected the Caps Lock mapping.'
    mv -n "$temp" "$agent" || die 'Could not install LaunchAgent.'
    trap - EXIT
    log 'Mapped Caps Lock to Ctrl now; the LaunchAgent reapplies the mapping on future logins.'
}

main "$@"
