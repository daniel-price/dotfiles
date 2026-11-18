# Isolated POC, manually source inside interactive Zsh only.
,jump-demo() {
  local dest
  dest=$("${CLI_POC_JUMP_RESOLVER:?Set CLI_POC_JUMP_RESOLVER}" "$@") || return
  builtin cd -- "$dest"
}
