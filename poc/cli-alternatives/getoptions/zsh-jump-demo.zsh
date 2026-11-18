# Isolated Zsh wrapper: resolver parses and validates; cd is executed in this shell.
,jump-demo() {
  local destination
  destination=$(bash "${CLI_POC_GETOPTIONS_JUMP:?Set resolver path}" "$@") || return
  builtin cd -- "$destination"
}
