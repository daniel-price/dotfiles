# Reviewed portable aliases migrated from daniel-price/.cfg.
# Leave employer-specific functions, old machine paths and destructive commands
# behind; they belong in explicitly selected local/private overlays.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias g='git'
alias zj='zellij'
alias za='zellij action'
alias zar='zellij action rename-tab'
alias hl='rg --passthru'

# doc: alias m | Only when mise is installed.
if (( $+commands[mise] )); then
  alias m='mise'
fi
# doc: alias p | Only when pnpm is installed.
if (( $+commands[pnpm] )); then
  alias p='pnpm'
fi
# doc: alias ls | When eza is installed, list one entry per line, directories first, with icons.
# Preserve .cfg's ls behaviour while keeping stock ls if eza is unavailable.
if (( $+commands[eza] )); then
  alias ls='eza -1 --group-directories-first --icons=always'
fi
