# Native mise environments are selected via miserc.local.toml.
# Keep legacy profile startup working until its explicit deactivation.
# The anonymous function scopes temporary variables; shell setup persists.
() {
  local zsh_dir=${${(%):-%x}:A:h}
  local root=${zsh_dir:h:h}
  local registry="$HOME/.config/dotfiles/active-profiles"
  local manifest="$HOME/.config/mise/dotfiles-profiles.toml"
  local name profile bin candidate directory file
  local -a profiles=()

  if [[ -f "$registry" && ! -L "$registry" ]]; then
    while IFS= read -r name || [[ -n "$name" ]]; do
      [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || continue
      profile="$HOME/.dotfiles-profiles/$name"
      [[ -d "$profile" && ! -L "$profile" ]] || continue
      profiles+=("$profile")
      bin="$profile/bin"
      if [[ -d "$bin" && ":$PATH:" != *":$bin:"* ]]; then
        export PATH="$bin:$PATH"
      fi
    done < "$registry"
  fi

  # Legacy profiles remain functional until explicitly deactivated.
  # Otherwise, let mise discover its native global config and selected environments.
  if (( ${#profiles} )); then
    if [[ -z "${MISE_GLOBAL_CONFIG_FILE:-}" ]]; then
      candidate="$root/scripts/setup/mise.toml"
      [[ -f "$manifest" && ! -L "$manifest" ]] && candidate="$manifest"
      [[ -f "$candidate" ]] && export MISE_GLOBAL_CONFIG_FILE="$candidate"
    fi
  else
    case "${MISE_GLOBAL_CONFIG_FILE:-}" in
      "$manifest" | "$root/scripts/setup/mise.toml")
        unset MISE_GLOBAL_CONFIG_FILE ;;
    esac
  fi

  if (( $+commands[mise] )); then
    eval "$(mise activate zsh)"
  elif [[ -x "$HOME/.local/bin/mise" ]]; then
    eval "$("$HOME/.local/bin/mise" activate zsh)"
  fi

  # Zoxide must initialise before its bookmark wrapper is sourced.
  if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
    [[ -r "$zsh_dir/zoxide-bookmarks.zsh" ]] && source "$zsh_dir/zoxide-bookmarks.zsh"
  fi

  if [[ -o interactive ]]; then
    # Base autoload functions first, then the selected Profiles.
    directory="$zsh_dir/functions"
    if [[ -d "$directory" ]]; then
      fpath=("$directory" $fpath)
      for file in "$directory"/*(N-.); do
        autoload -Uz "${file:t}"
      done
    fi
    for profile in "${profiles[@]}"; do
      directory="$profile/zsh/functions"
      [[ -d "$directory" ]] || continue
      fpath=("$directory" $fpath)
      for file in "$directory"/*(N-.); do
        autoload -Uz "${file:t}"
      done
    done

    # Completion runs after all autoload directories have been registered.
    autoload -Uz compinit
    compinit
    [[ -r "$zsh_dir/completions.zsh" ]] && source "$zsh_dir/completions.zsh"
  fi

  # Selected Profile aliases take precedence over Base aliases.
  [[ -r "$zsh_dir/aliases.zsh" ]] && source "$zsh_dir/aliases.zsh"
  for profile in "${profiles[@]}"; do
    file="$profile/zsh/aliases.zsh"
    if [[ -f "$file" && ! -L "$file" ]]; then
      source "$file"
    fi
  done
}
