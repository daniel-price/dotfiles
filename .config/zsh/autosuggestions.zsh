# Suggest named zoxide bookmarks before falling back to normal history.
# Strategies set "suggestion" using Zsh's dynamic variable scoping.
_zsh_autosuggest_strategy_dotfiles_bookmarks() {
  local buffer=${1-} prefix name
  [[ "$buffer" == 'z '* ]] || return 1
  prefix=${buffer#z }
  [[ -n "$prefix" && "$prefix" != *' '* ]] || return 1
  (( ${+DOTFILES_Z_BOOKMARKS} )) || return 1

  # Stable results for ambiguous prefixes; missing directories are excluded.
  for name in ${(ok)DOTFILES_Z_BOOKMARKS}; do
    if [[ "$name" == "$prefix"* && -d "${DOTFILES_Z_BOOKMARKS[$name]}" ]]; then
      suggestion="z $name"
      return 0
    fi
  done
  return 1
}

# Prefer the pinned checkout; also support system packages and an override.
# Shell startup must not clone or install a dependency.
if [[ -n "${DOTFILES_ZSH_AUTOSUGGESTIONS_FILE:-}" ]]; then
  _dotfiles_autosuggest_candidates=("$DOTFILES_ZSH_AUTOSUGGESTIONS_FILE")
else
  _dotfiles_autosuggest_candidates=(
    "$HOME/.local/share/dotfiles/zsh-autosuggestions/zsh-autosuggestions.zsh"
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  )
fi

if (( ! ${+functions[_zsh_autosuggest_start]} )); then
  for _dotfiles_autosuggest_candidate in "${_dotfiles_autosuggest_candidates[@]}"; do
    if [[ -r "$_dotfiles_autosuggest_candidate" ]]; then
      ZSH_AUTOSUGGEST_STRATEGY=(dotfiles_bookmarks history)
      source "$_dotfiles_autosuggest_candidate"
      break
    fi
  done
else
  # Reuse an existing plugin to avoid binding ZLE widgets twice.
  ZSH_AUTOSUGGEST_STRATEGY=(dotfiles_bookmarks history)
fi
unset _dotfiles_autosuggest_candidate _dotfiles_autosuggest_candidates
