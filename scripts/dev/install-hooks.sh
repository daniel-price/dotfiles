#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

case "${1:-}" in
-h | --help)
    printf '%s\n' 'Usage: bash scripts/dev/install-hooks.sh' \
        'Enable the pre-commit hook in this checkout after confirmation.' \
        'Requires trusted mise.toml and the installed development tools.'
    exit 0
    ;;
'') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
*) die 'Unknown argument. Use --help.' ;;
esac

cd "$ROOT"
[[ "$(git rev-parse --show-toplevel)" == "$ROOT" ]] || die 'Run from a Git checkout of this repository.'
if git config --get core.hooksPath >/dev/null; then
    die 'core.hooksPath is configured; resolve it explicitly before installing checkout hooks.'
fi

hook=$(git rev-parse --git-path hooks/pre-commit)
if [[ -e "$hook" || -L "$hook" ]]; then
    [[ -f "$hook" && ! -L "$hook" ]] || die "Refusing to replace a non-regular hook: $hook"
    grep -Fqx 'call_lefthook run "pre-commit" "$@"' "$hook" ||
        die "An existing pre-commit hook is not managed by Lefthook: $hook"
fi

command -v mise >/dev/null 2>&1 || die 'Install mise, then follow docs/guides/development.md.'
for tool in lefthook shfmt shellcheck; do
    mise which "$tool" >/dev/null || die 'Install the pinned tools first; see docs/guides/development.md.'
done
if [[ -x "$hook" ]] && mise exec -- lefthook check-install >/dev/null 2>&1; then
    log 'Lefthook is already installed for this checkout; no changes made.'
    exit 0
fi
if ! confirm "Install or update this checkout's pre-commit hook at $hook?"; then
    log 'Hook installation declined; no changes made.'
    exit 0
fi
mise exec -- lefthook install pre-commit
log 'Enabled automatic shell formatting and ShellCheck for this checkout.'
