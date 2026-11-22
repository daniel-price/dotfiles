# Portable completions for comma commands; sourced after compinit.
_dotfiles_repeat() {
  _arguments '1:positive count:' '*::command and arguments:_normal'
}
_dotfiles_until_failure() {
  _arguments '*::command and arguments:_normal'
}
_dotfiles_wt() {
  _arguments '1:new branch name:'
}
compdef _dotfiles_repeat ,repeat
compdef _dotfiles_until_failure ,until-failure
compdef _dotfiles_wt ,wt

# Generate completions from the same argc annotations used by the command.
# On a fresh machine argc is optional during shell startup; bootstrap never needs it.
if (( $+commands[argc] )); then
  source <(argc --argc-completions zsh ,uuid)
fi

# Offer exact bookmark names while retaining Zoxide's native completion.
_dotfiles_z() {
  if (( CURRENT == 2 && ${+functions[__zoxide_z_complete]} )); then
    local -a bookmarks
    bookmarks=("${(@k)DOTFILES_Z_BOOKMARKS}")
    compadd -Q -a bookmarks
  fi
  __zoxide_z_complete "$@"
}
if (( ${+functions[__zoxide_z_complete]} )); then
  compdef _dotfiles_z z
fi
