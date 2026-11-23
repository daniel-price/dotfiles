#!/usr/bin/env zsh
# Isolated strategy/loader tests: no real plugin or user home required.
emulate -L zsh
setopt errexit nounset
root=${0:A:h:h:h}
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/nvim" "$tmp_dir/mason"
typeset -A DOTFILES_Z_BOOKMARKS
DOTFILES_Z_BOOKMARKS=(nvim-plugins "$tmp_dir/nvim" mason-plugins "$tmp_dir/mason" missing "$tmp_dir/absent")
DOTFILES_ZSH_AUTOSUGGESTIONS_FILE="$tmp_dir/not-installed"
source "$root/.config/zsh/autosuggestions.zsh"
check() {
  local input=$1 expected=$2
  local suggestion=''
  _zsh_autosuggest_strategy_dotfiles_bookmarks "$input" || { print -u2 "no suggestion: $input"; return 1; }
  [[ "$suggestion" == "$expected" ]] || { print -u2 "wrong suggestion: $input => $suggestion"; return 1; }
}
check 'z n' 'z nvim-plugins'
check 'z m' 'z mason-plugins'
check 'z nvim-plugins' 'z nvim-plugins'
for input in 'z ' 'z missing' 'z nvim-plugins other' 'echo n' 'zi n' 'z n m'; do
  suggestion=''
  if _zsh_autosuggest_strategy_dotfiles_bookmarks "$input"; then
    print -u2 "unexpected suggestion: $input => $suggestion"
    exit 1
  fi
done
unset DOTFILES_Z_BOOKMARKS
if _zsh_autosuggest_strategy_dotfiles_bookmarks 'z n'; then
  print -u2 'unexpected bookmark without a zoxide map'
  exit 1
fi
cat >"$tmp_dir/fake-plugin.zsh" <<'PLUGIN'
typeset -g _DOTFILES_AUTOSUGGESTIONS_LOADED=yes
_zsh_autosuggest_start() { :; }
PLUGIN
DOTFILES_ZSH_AUTOSUGGESTIONS_FILE="$tmp_dir/fake-plugin.zsh"
source "$root/.config/zsh/autosuggestions.zsh"
[[ "${_DOTFILES_AUTOSUGGESTIONS_LOADED:-}" == yes ]] || exit 1
[[ "${(j:,:)ZSH_AUTOSUGGEST_STRATEGY}" == dotfiles_bookmarks,history ]] || exit 1
_DOTFILES_AUTOSUGGESTIONS_LOADED=no
source "$root/.config/zsh/autosuggestions.zsh"
[[ "$_DOTFILES_AUTOSUGGESTIONS_LOADED" == no ]] || exit 1
print 'PASS: Bookmark autosuggestion strategy, override and preloaded plugin'
