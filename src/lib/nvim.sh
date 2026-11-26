#!/usr/bin/env bash
# Shared LazyVim checkout and plugin verification operations. No side effects on source.

NVIM_CONFIG_REMOTE='https://github.com/daniel-price/lazyvim.git'

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

    if ! run_concise git -C "$config" fetch origin main; then
        if [[ "$allow_offline" == --allow-offline ]]; then
            log 'Neovim fetch failed (possibly offline); using existing clean checkout.'
            return 0
        fi
        log 'Could not fetch the latest LazyVim main.'
        return 1
    fi

    run_concise git -C "$config" merge --ff-only FETCH_HEAD || {
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

# Work with a private copy of the reviewed lockfile and a clean parser download
# cache. No startup or plugin operation may replace the canonical lockfile.
nvim_bootstrap_plugins() (
    local mise=$1 config=$2 lib_dir=$3 scratch status=0
    scratch=$(make_temp_dir_physical dotfiles-nvim) || return 1
    trap 'rm -rf -- "$scratch"' EXIT
    cp "$config/lazy-lock.json" "$scratch/original.json" || return 1
    cp "$scratch/original.json" "$scratch/lock.json" || return 1

    local -a nvim_command=(
        env DOTFILES_NVIM_CONFIG="$config"
        DOTFILES_NVIM_LOCK="$scratch/lock.json"
        DOTFILES_NVIM_ORIGINAL="$scratch/original.json"
        DOTFILES_NVIM_SUCCESS="$scratch/success"
        DOTFILES_NVIM_MASON_SCRIPT="$lib_dir/nvim-mason.lua"
        DOTFILES_NVIM_BOOTSTRAP_SCRIPT="$lib_dir/nvim-bootstrap.lua"
        XDG_CACHE_HOME="$scratch/cache"
        "$mise" -C / exec -- nvim --headless
        --cmd 'lua dofile(vim.env.DOTFILES_NVIM_BOOTSTRAP_SCRIPT)'
        -c 'lua DotfilesNvimFinish()' -c 'qa!'
    )
    if declare -F run_step >/dev/null 2>&1; then
        run_step 'Restoring Neovim plugins and language tools' "${nvim_command[@]}" || status=$?
    else
        log 'Restoring locked Neovim plugins and installing language tools (progress follows).'
        "${nvim_command[@]}" || status=$?
    fi

    if ! cmp -s "$scratch/original.json" "$config/lazy-lock.json"; then
        # The checkout was clean before this operation. Do not leave an
        # accidental lockfile rewrite behind, even when Neovim fails.
        cp "$scratch/original.json" "$config/lazy-lock.json" || return 1
        log 'Neovim unexpectedly modified its lockfile; restored the original.'
        return 1
    fi
    if ((status != 0)) || [[ ! -f "$scratch/success" ]]; then
        log 'Neovim setup failed or did not reach verification.'
        return 1
    fi
)
