#!/usr/bin/env bash
# Inspect the same getoptions parser_definition DSL for documentation and completion.
poc_arg() { :; }
poc_emit() {
  local kind=$1 name=$2 long='-' short='-' pattern='-' default='-' desc='-'
  shift 2
  if [[ $kind == arg ]]; then
    desc=${1--}
  else
    while (($#)); do
      case $1 in
        --) shift; desc=${1--}; break ;;
        --*) long=$1 ;;
        -?) short=$1 ;;
        pattern:*) pattern=${1#pattern:} ;;
        init:=*) default=${1#init:=} ;;
      esac
      shift
    done
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$name" "$long" "$short" "$pattern" "$default" "$desc"
}
poc_metadata() (
  setup() { :; }
  msg() { :; }
  disp() { :; }
  flag() { poc_emit flag "$@"; }
  param() { poc_emit param "$@"; }
  option() { poc_emit option "$@"; }
  poc_arg() { poc_emit arg "$@"; }
  parser_definition
)
poc_help() {
  printf 'Usage: %s\n\nOptions:\n' "${POC_SYNOPSIS:-,case-text [OPTIONS] <text>}"
  local kind name long short pattern default desc
  while IFS=$'\t' read -r kind name long short pattern default desc; do
    if [[ $kind == arg ]]; then
      printf '  <%s>: %s\n' "$name" "$desc"
    else
      printf '  %s %s' "$short" "$long"
      [[ $pattern == - ]] || printf ' (%s)' "$pattern"
      [[ $default == - ]] || printf ' [default: %s]' "$default"
      printf '  %s\n' "$desc"
    fi
  done < <(poc_metadata)
  printf '  -h --help  Show help\n'
}
poc_markdown() {
  printf '# %s\n\nUsage: %s\n\n' "${POC_TITLE:-,case-text}" "${POC_SYNOPSIS:-,case-text [OPTIONS] <text>}"
  printf '| Kind | Name | Flags | Choices | Default | Description |\n'
  printf '| --- | --- | --- | --- | --- | --- |\n'
  local kind name long short pattern default desc
  while IFS=$'\t' read -r kind name long short pattern default desc; do
    printf '| %s | %s | %s %s | %s | %s | %s |\n' "$kind" "$name" "$short" "$long" "$pattern" "$default" "$desc"
  done < <(poc_metadata)
}
poc_complete() {
  local prev=${1-} prefix=${2-} kind name long short pattern default desc choice
  while IFS=$'\t' read -r kind name long short pattern default desc; do
    [[ $kind == param && $pattern != - ]] || continue
    if [[ $prev == "$long" || $prev == "$short" || $prefix == "$long="* ]]; then
      local value_prefix=$prefix eq_prefix=''
      if [[ $prefix == "$long="* ]]; then eq_prefix="$long="; value_prefix=${prefix#*=}; fi
      local -a choices=()
      IFS='|' read -r -a choices <<< "$pattern"
      for choice in "${choices[@]}"; do
        [[ $choice == "$value_prefix"* ]] && printf '%s%s\t%s\n' "$eq_prefix" "$choice" "$desc"
      done
      return
    fi
  done < <(poc_metadata)
  while IFS=$'\t' read -r kind name long short pattern default desc; do
    [[ $kind == flag || $kind == param || $kind == option ]] || continue
    [[ $long != - && $long == "$prefix"* ]] && printf '%s\t%s\n' "$long" "$desc"
    [[ $short != - && $short == "$prefix"* ]] && printf '%s\t%s\n' "$short" "$desc"
  done < <(poc_metadata)
  [[ --help == "$prefix"* ]] && printf '%s\t%s\n' --help 'Show help'
}
