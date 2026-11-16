#!/usr/bin/env bash

# Shared by format.sh and lint.sh; populate files with repository-relative paths.
select_shell_files() {
    local root file
    root=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P) || return
    cd "$root" || return

    files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        git rev-parse --is-inside-work-tree >/dev/null
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(git ls-files -z -- '*.sh')
    fi
}
