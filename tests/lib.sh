#!/usr/bin/env bash
# Shared test helpers.

# Return a physical temporary-directory path. On macOS, mktemp may return a
# /var path that Git resolves via /private/var; TMPDIR may also end in /.
make_temp_dir() {
    local dir
    dir=$(mktemp -d "${TMPDIR:-/tmp}/$1.XXXXXX") || return
    (cd "$dir" && pwd -P)
}
