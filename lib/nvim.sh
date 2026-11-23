#!/usr/bin/env bash
# Shared LazyVim checkout and plugin verification operations. No side effects on source.

NVIM_CONFIG_REMOTE='https://github.com/daniel-price/lazyvim.git'

# Bootstrap may have installed gh through mise without updating this shell's PATH.
nvim_ensure_gh() {
    local mise=$1 executable

    if command -v gh >/dev/null 2>&1; then
        return 0
    fi
    executable=$("$mise" -C / which gh 2>/dev/null) || {
        log 'GitHub CLI is unavailable; install the pinned gh tool and authenticate with gh auth login.'
        return 1
    }
    [[ -x "$executable" ]] || {
        log "GitHub CLI is not executable: $executable"
        return 1
    }
    export PATH="${executable%/*}:$PATH"
}

# Use the existing gh login only for these Git operations. Never change the
# global Git credential helper or print/store a token.
nvim_gh_git() {
    git -c credential.helper= \
        -c 'credential.https://github.com.helper=!gh auth git-credential' "$@"
}

nvim_clone_checkout() {
    local config=$1

    command -v gh >/dev/null 2>&1 || {
        log 'GitHub CLI is unavailable; cannot clone Neovim configuration.'
        return 1
    }
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        log 'GitHub CLI is not authenticated to github.com; run gh auth login.'
        return 1
    fi

    # gh repo clone preserves a Git checkout for later fast-forward and push.
    # Force HTTPS so gh's credential helper works regardless of git_protocol.
    # Git's environment-scoped settings affect only this clone, not ~/.gitconfig.
    GIT_CONFIG_COUNT=2 \
        GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0='' \
        GIT_CONFIG_KEY_1=credential.https://github.com.helper \
        GIT_CONFIG_VALUE_1='!gh auth git-credential' \
        gh repo clone "$NVIM_CONFIG_REMOTE" "$config" -- --branch main --single-branch
}

nvim_validate_checkout() {
    local config=$1 origin

    if [[ -L "$config" || ! -d "$config" ]] ||
        [[ "$(git -C "$config" rev-parse --show-toplevel 2>/dev/null || :)" != "$(cd "$config" && pwd -P)" ]]; then
        log "Neovim config is not the expected Git checkout: $config"
        return 1
    fi

    origin=$(git -C "$config" remote get-url origin 2>/dev/null) || {
        log 'Neovim config has no origin remote.'
        return 1
    }
    case "$origin" in
    "$NVIM_CONFIG_REMOTE" | 'https://github.com/daniel-price/lazyvim') ;;
    *)
        log "Unexpected LazyVim origin: $origin"
        return 1
        ;;
    esac

    [[ "$(git -C "$config" symbolic-ref --quiet --short HEAD 2>/dev/null || :)" == main ]] ||
        {
            log 'Neovim config must be on main.'
            return 1
        }
    [[ -z "$(git -C "$config" status --porcelain --untracked-files=all)" ]] ||
        {
            log 'Neovim config has uncommitted changes.'
            return 1
        }
    [[ -f "$config/lazy-lock.json" ]] ||
        {
            log 'Neovim lazy-lock.json is missing.'
            return 1
        }
}

# Caller validates the checkout first. Fetch failure is tolerable during
# bootstrap only; a divergent history is never safe to update.
nvim_sync_checkout() {
    local config=$1 allow_offline=${2:-}

    if ! nvim_gh_git -C "$config" fetch origin main; then
        if [[ "$allow_offline" == --allow-offline ]]; then
            log 'Neovim fetch failed (possibly offline); using existing clean checkout.'
            return 0
        fi
        log 'Could not fetch the latest LazyVim main.'
        return 1
    fi

    git -C "$config" merge --ff-only FETCH_HEAD || {
        log 'Neovim main has diverged from origin/main; resolve it manually.'
        return 1
    }
}

# Additional Neovim -c options (restore, clean, etc.) run before verification.
nvim_verify_plugins() {
    local mise=$1 verify
    shift

    verify='lua local ok,err=pcall(function() local cfg=require("lazy.core.config"); local lock=vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config").."/lazy-lock.json"),"\n")); for name,p in pairs(cfg.plugins) do if not (p._ and p._.is_local) then local want=lock[name]; assert(want and want.commit, "Plugin missing from lazy-lock.json: "..name); assert(vim.fn.isdirectory(p.dir)==1, "Plugin not installed: "..name); local got=vim.fn.systemlist({"git","-C",p.dir,"rev-parse","HEAD"})[1]; assert(vim.v.shell_error==0 and got==want.commit, "Plugin does not match lockfile: "..name) end end end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end'
    "$mise" -C / exec -- nvim --headless "$@" -c "$verify" -c 'qa!'
}
