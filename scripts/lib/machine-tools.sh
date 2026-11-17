#!/usr/bin/env bash
# Sourced helper. Query mise's active machine config instead of parsing TOML
# or maintaining duplicate lists of tools in setup/cleanup scripts.
#
# Caller selects MISE_GLOBAL_CONFIG_FILE=<reviewed machine manifest> and uses
# a mise executable compatible with --current and config get --file.
# Prints one validated, exact tool@version per line. No side effects.
machine_tool_specs() {
    local mise=$1 manifest=$2 rows row tool version seen=' '

    [[ -f "$manifest" && ! -L "$manifest" ]] || {
        printf '[error] Machine manifest is missing or is a symlink: %s\n' "$manifest" >&2
        return 1
    }

    # --current includes configured but missing tools. From / we deliberately
    # avoid the checkout's developer manifest and parent project configs.
    rows=$("$mise" -C / ls --current --no-header --no-truncate) || {
        printf '[error] mise could not enumerate machine tools.\n' >&2
        return 1
    }

    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        # mise ls outputs columns: tool, version/status, request source.
        read -r tool _ <<<"$row"
        [[ "$tool" =~ ^[a-zA-Z0-9][a-zA-Z0-9_:.+/@-]*$ ]] || {
            printf '[error] Unsupported mise tool name: %s\n' "$tool" >&2
            return 1
        }
        case "$seen" in
        *" $tool "*) continue ;;
        esac
        seen="$seen$tool "

        # Read the literal request from the exact reviewed file, not a merged
        # environment value. Never allow an externally supplied tool/version
        # to become an installation or removal target.
        version=$("$mise" -C / config get --file "$manifest" "tools.\"$tool\"") || {
            printf '[error] Tool %s was not declared in the reviewed manifest.\n' "$tool" >&2
            return 1
        }
        [[ "$version" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
            printf '[error] Refusing unpinned machine tool %s: %s\n' "$tool" "$version" >&2
            return 1
        }
        printf '%s@%s\n' "$tool" "$version"
    done <<<"$rows"
}
