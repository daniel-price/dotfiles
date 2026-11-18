# POC: named Zoxide bookmark suggestions, using optional zsh-autosuggestions.
# Strategy functions must set 'suggestion' to a complete command line.
_zsh_autosuggest_strategy_dotfiles_bookmarks() {
  local buffer=$1 prefix name
  [[ "$buffer" == 'z '* ]] || return 1
  prefix=${buffer#z }
  [[ -n "$prefix" && "$prefix" != *' '* ]] || return 1
  (( ${+DOTFILES_Z_BOOKMARKS} )) || return 1

  # Sort names so ambiguous prefixes give deterministic results.
  for name in ${(ok)DOTFILES_Z_BOOKMARKS}; do
    if [[ "$name" == "$prefix"* && -d "${DOTFILES_Z_BOOKMARKS[$name]}" ]]; then
      suggestion="z $name"
      return 0
    fi
  done
  return 1
}

# Allow a custom path for an explicitly installed plugin (e.g. a POC clone).
# Otherwise check common Debian/Ubuntu and Homebrew package layouts.
if [[ -n "${DOTFILES_ZSH_AUTOSUGGESTIONS_FILE:-}" ]]; then
  _dotfiles_autosuggest_candidates=("$DOTFILES_ZSH_AUTOSUGGESTIONS_FILE")
else
  _dotfiles_autosuggest_candidates=(
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
  # A preloaded plugin also supports the custom strategy.
  ZSH_AUTOSUGGEST_STRATEGY=(dotfiles_bookmarks history)
fi
unset _dotfiles_autosuggest_candidate _dotfiles_autosuggest_candidates
