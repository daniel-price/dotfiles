#!/usr/bin/env zsh
# Zsh bridge smoke test. This invokes the completion function, not an actual Tab key.
emulate zsh
setopt errexit nounset pipefail
typeset here=$PWD/poc/cli-alternatives
export CLI_POC_GETOPTIONS_CASE="$here/getoptions/case-text"
export CLI_POC_GETOPTIONS_JUMP="$here/getoptions/jump-resolve"
typeset tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bookmark"
export CLI_POC_DEMO_ROOT="$tmp/bookmark"
source "$here/completion/_poc_getoptions"
compadd() { print -rl -- "$@"; }
_files() { :; }

typeset -a words
typeset -i CURRENT
words=(',case-text' '')
CURRENT=2
typeset output=$(_poc_getoptions)
[[ $output == *--case* && $output == *--no-newline* ]] || { print -u2 'bare-word candidate assertion failed'; return 1; }

words=(',case-text' '--')
CURRENT=2
output=$(_poc_getoptions)
[[ $output == *--case* && $output == *--no-newline* ]] || { print -u2 'long flags assertion failed'; return 1; }

words=(',case-text' '--case' '')
CURRENT=3
output=$(_poc_getoptions)
[[ $output == *lower* && $output == *upper* ]] || { print -u2 'enum choice assertion failed'; return 1; }

words=(',case-text' '--case=')
CURRENT=2
output=$(_poc_getoptions)
[[ $output == *--case=upper* ]] || { print -u2 'equals-form choice assertion failed'; return 1; }

words=(',jump-demo' '')
CURRENT=2
output=$(_poc_getoptions)
[[ $output == *demo* ]] || { print -u2 'bookmark candidate assertion failed'; return 1; }

source "$here/getoptions/zsh-jump-demo.zsh"
,jump-demo demo
[[ "$PWD" == "$CLI_POC_DEMO_ROOT" ]] || { print -u2 'current-shell cd failed'; return 1; }
print 'PASS: Zsh completion function candidate dispatch, and current-process cd (not interactive Tab)'
