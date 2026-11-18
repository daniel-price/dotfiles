#!/usr/bin/env zsh
# No plugin required: test the strategy's contract with an isolated bookmark map.
emulate -L zsh
setopt errexit nounset
local_dir=${0:A:h:h}
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/nvim" "$tmp_dir/mason"
typeset -A DOTFILES_Z_BOOKMARKS
DOTFILES_Z_BOOKMARKS=(nvim-plugins "$tmp_dir/nvim" mason-plugins "$tmp_dir/mason" missing "$tmp_dir/absent")
DOTFILES_ZSH_AUTOSUGGESTIONS_FILE="$tmp_dir/not-installed"
source "$local_dir/.config/zsh/autosuggestions.zsh"
check() {
  local input=$1 expected=$2
  local suggestion=''
  _zsh_autosuggest_strategy_dotfiles_bookmarks "$input" || { print -u2 "no suggestion: $input"; return 1; }
  [[ "$suggestion" == "$expected" ]] || { print -u2 "wrong suggestion: $input => $suggestion"; return 1; }
}
check 'z n' 'z nvim-plugins'
check 'z m' 'z mason-plugins'
check 'z nvim-plugins' 'z nvim-plugins'
for input in 'z ' 'z missing' 'z nvim-plugins other' 'echo n' 'zi n'; do
  local suggestion=''
  if _zsh_autosuggest_strategy_dotfiles_bookmarks "$input"; then
    print -u2 "unexpected suggestion: $input => $suggestion"
    exit 1
  fi
done
print 'PASS: Zoxide bookmark inline suggestion strategy'
