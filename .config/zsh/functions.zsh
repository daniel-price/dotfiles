# Small, portable interactive helpers retained from .cfg.
# Do not source this file from Bash; these are Zsh functions.

# doc: function vv | Open Neovim's init.lua, if Neovim is installed.
vv() {
  if (( ! $+commands[nvim] )); then
    print -u2 'vv: nvim is not installed'
    return 127
  fi
  nvim "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua"
}

# doc: function nvimPlugins | Navigate to installed lazy.nvim plugins.
nvimPlugins() {
  builtin cd -- "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
}

# doc: function masonPlugins | Navigate to installed Mason packages.
masonPlugins() {
  builtin cd -- "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages"
}

# doc: function wt | Create a Git worktree next to the current checkout for a new branch.
wt() {
  if (( $# != 1 )); then
    print -u2 'Usage: wt <new-branch>'
    return 2
  fi
  local root branch target
  branch=$1
  root=$(command git rev-parse --show-toplevel 2>/dev/null) || {
    print -u2 'wt: not inside a Git repository'
    return 1
  }
  # Only allow a valid new branch; do not silently switch or overwrite.
  command git check-ref-format --branch "$branch" >/dev/null || return 2
  target="${root:h}/${root:t}-wt-${branch//\//-}"
  if [[ -e "$target" ]]; then
    print -u2 "wt: destination already exists: $target"
    return 1
  fi
  command git -C "$root" worktree add -b "$branch" "$target" || return
  builtin cd -- "$target"
}

# doc: function uuid | Generate a UUID, optionally lowercase and/or without hyphens.
uuid() {
  local value lower=0 compact=0
  while (( $# )); do
    case "$1" in
      -l|--lowercase) lower=1 ;;
      -n|--no-hyphens) compact=1 ;;
      -h|--help)
        print 'Usage: uuid [-l|--lowercase] [-n|--no-hyphens]'
        return 0
        ;;
      *) print -u2 "uuid: unknown option: $1"; return 2 ;;
    esac
    shift
  done
  if (( $+commands[uuidgen] )); then
    value=$(command uuidgen) || return
  elif (( $+commands[python3] )); then
    value=$(command python3 -c 'import uuid; print(uuid.uuid4())') || return
  else
    print -u2 'uuid: requires uuidgen or python3'
    return 127
  fi
  (( lower )) && value=${value:l}
  (( compact )) && value=${value//-/}
  print -r -- "$value"
}
