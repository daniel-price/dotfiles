# Named directories for zoxide: exact names win; all other input is delegated.
typeset -gA DOTFILES_Z_BOOKMARKS=(
  nvim-plugins "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
  mason-plugins "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages"
)

function z() {
  local target="${DOTFILES_Z_BOOKMARKS[$1]-}"

  if (( $# == 1 )) && [[ -n "$target" ]]; then
    builtin cd -- "$target"
    return
  fi

  __zoxide_z "$@"
}
