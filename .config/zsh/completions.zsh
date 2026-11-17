# Portable completions; deliberately exclude old private/work commands.
# These are sourced only after compinit in an interactive Zsh.
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
compdef _dotfiles_until_failure ,untilFailure
compdef _dotfiles_wt wt
