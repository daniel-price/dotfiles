# Optional reusable profiles are activated explicitly by ,profile.
# Keep private-path, mise and shell composition out of zshrc.
typeset -a _dotfiles_profiles
_dotfiles_profiles=()

_dotfiles_profiles_init() {
  local root=$1
  local registry="$HOME/.config/dotfiles/active-profiles"
  local manifest="$HOME/.config/mise/dotfiles-profiles.toml"
  local name profile bin candidate

  if [[ -f "$registry" && ! -L "$registry" ]]; then
    while IFS= read -r name || [[ -n "$name" ]]; do
      [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || continue
      profile="$HOME/.dotfiles-profiles/$name"
      [[ -d "$profile" && ! -L "$profile" ]] || continue
      _dotfiles_profiles+=("$profile")
      bin="$profile/bin"
      if [[ -d "$bin" && ":$PATH:" != *":$bin:"* ]]; then
        export PATH="$bin:$PATH"
      fi
    done < "$registry"
  fi

  # A nested shell may inherit the manifest after the last deactivation.
  if [[ "${MISE_GLOBAL_CONFIG_FILE:-}" == "$manifest" && ! -f "$registry" ]]; then
    unset MISE_GLOBAL_CONFIG_FILE
  fi

  # Keep explicit external overrides; otherwise use the active profile's
  # generated manifest or the original public machine manifest.
  if [[ -z "${MISE_GLOBAL_CONFIG_FILE:-}" ]]; then
    candidate="$root/scripts/setup/mise.toml"
    if [[ -f "$registry" && ! -L "$registry" &&
          -f "$manifest" && ! -L "$manifest" ]]; then
      candidate="$manifest"
    fi
    [[ -f "$candidate" ]] && export MISE_GLOBAL_CONFIG_FILE="$candidate"
  fi
}

_dotfiles_profiles_functions() {
  local profile directory file
  for profile in "${_dotfiles_profiles[@]}"; do
    directory="$profile/zsh/functions"
    [[ -d "$directory" ]] || continue
    fpath=("$directory" $fpath)
    for file in "$directory"/*(N-.); do
      autoload -Uz "${file:t}"
    done
  done
}

_dotfiles_profiles_aliases() {
  local profile file
  for profile in "${_dotfiles_profiles[@]}"; do
    file="$profile/zsh/aliases.zsh"
    if [[ -f "$file" && ! -L "$file" ]]; then
      source "$file"
    fi
  done
}
