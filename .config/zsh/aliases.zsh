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
# doc: alias ls | Only when eza is installed.
# Only replace ls if eza is actually installed; never break stock ls.
if (( $+commands[eza] )); then
  alias ls='eza'
fi

# doc: alias cdNvimPlugins | Navigate to installed lazy.nvim plugins.
alias cdNvimPlugins='cd "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"'
# doc: alias cdMasonPlugins | Navigate to installed Mason packages.
alias cdMasonPlugins='cd "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages"'
