# Named directories for zoxide: exact names win; all other input is delegated.
typeset -gA DOTFILES_Z_BOOKMARKS=(
  nvim-plugins "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
  mason-plugins "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages"
)

function z() {
  if (( $# == 1 && ${+DOTFILES_Z_BOOKMARKS[$1]} )); then
    if [[ ! -d "${DOTFILES_Z_BOOKMARKS[$1]}" ]]; then
      print -u2 "z: bookmark '$1' points to a missing directory: ${DOTFILES_Z_BOOKMARKS[$1]}"
      return 1
    fi
    builtin cd -- "${DOTFILES_Z_BOOKMARKS[$1]}"
  else
    __zoxide_z "$@"
  fi
}
