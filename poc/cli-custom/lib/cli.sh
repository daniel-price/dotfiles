#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034 # Dynamic parser registry and generated Markdown literals
# Experimental Bash 3.2-compatible registry: no generated code.
CLI_KIND=() CLI_NAME=() CLI_SHORT=() CLI_CHOICES=() CLI_DEFAULT=() CLI_DESC=()
cli_option() {
    CLI_KIND+=(option)
    CLI_NAME+=("$1")
    CLI_SHORT+=("$2")
    CLI_CHOICES+=("$3")
    CLI_DEFAULT+=("$4")
    CLI_DESC+=("$5")
}
cli_flag() {
    CLI_KIND+=(flag)
    CLI_NAME+=("$1")
    CLI_SHORT+=("$2")
    CLI_CHOICES+=("")
    CLI_DEFAULT+=(false)
    CLI_DESC+=("$3")
}
cli_arg() {
    CLI_KIND+=(arg)
    CLI_NAME+=("$1")
    CLI_SHORT+=("")
    CLI_CHOICES+=("")
    CLI_DEFAULT+=("")
    CLI_DESC+=("$2")
}
cli_error() {
    printf 'Error: %s\n' "$*" >&2
    return 2
}
cli_help() {
    printf 'Usage: %s [OPTIONS] <%s>\n\nOptions:\n' "$CLI_TITLE" "${CLI_ARG_NAME:-text}"
    local i
    for ((i = 0; i < ${#CLI_KIND[@]}; i++)); do
        [[ ${CLI_KIND[i]} == arg ]] && continue
        printf '  %s %s  %s' "${CLI_SHORT[i]}" "${CLI_NAME[i]}" "${CLI_DESC[i]}"
        [[ -n ${CLI_CHOICES[i]} ]] && printf ' (choices: %s; default: %s)' "${CLI_CHOICES[i]}" "${CLI_DEFAULT[i]}"
        printf '\n'
    done
    printf '  -h --help  Show help\n'
}
cli_markdown() {
    printf '# %s\n\n`%s [OPTIONS] <%s>`\n\n| Argument | Type | Default | Description |\n| --- | --- | --- | --- |\n' "$CLI_TITLE" "$CLI_TITLE" "${CLI_ARG_NAME:-text}"
    local i
    for ((i = 0; i < ${#CLI_KIND[@]}; i++)); do
        printf '| `%s` | %s' "${CLI_NAME[i]}" "${CLI_KIND[i]}"
        if [[ -n ${CLI_CHOICES[i]} ]]; then printf ' (%s)' "${CLI_CHOICES[i]}"; fi
        printf ' | %s | %s |\n' "${CLI_DEFAULT[i]:--}" "${CLI_DESC[i]}"
    done
}
cli_complete() {
    local prev=${1-} prefix=${2-} i name
    for ((i = 0; i < ${#CLI_KIND[@]}; i++)); do
        if [[ ${CLI_KIND[i]} == option && -n $prev && ($prev == "${CLI_NAME[i]}" || (-n ${CLI_SHORT[i]} && $prev == "${CLI_SHORT[i]}")) ]]; then
            local oldifs=$IFS val
            IFS='|'
            for val in ${CLI_CHOICES[i]}; do [[ $val == "$prefix"* ]] && printf '%s\t%s\n' "$val" "${CLI_DESC[i]}"; done
            IFS=$oldifs
            return
        fi
    done
    for ((i = 0; i < ${#CLI_KIND[@]}; i++)); do
        [[ ${CLI_KIND[i]} == arg ]] && continue
        name=${CLI_NAME[i]}
        [[ $name == "$prefix"* ]] && printf '%s\t%s\n' "$name" "${CLI_DESC[i]}"
        name=${CLI_SHORT[i]}
        [[ -n $name && $name == "$prefix"* ]] && printf '%s\t%s\n' "$name" "${CLI_DESC[i]}"
    done
    [[ --help == "$prefix"* ]] && printf '%s\t%s\n' --help 'Show help'
}
cli_parse() {
    CLI_VALUE=() CLI_POSITIONAL=()
    local i key value found
    for ((i = 0; i < ${#CLI_KIND[@]}; i++)); do CLI_VALUE[i]=${CLI_DEFAULT[i]}; done
    while (($#)); do
        case $1 in
        -h | --help)
            cli_help
            return 10
            ;;
        --)
            shift
            while (($#)); do
                CLI_POSITIONAL+=("$1")
                shift
            done
            break
            ;;
        -*)
            key=${1%%=*}
            value=''
            found=-1
            for ((i = 0; i < ${#CLI_KIND[@]}; i++)); do
                if [[ ${CLI_KIND[i]} != arg && ($key == "${CLI_NAME[i]}" || $key == "${CLI_SHORT[i]}") ]]; then
                    found=$i
                    break
                fi
            done
            ((found >= 0)) || {
                cli_error "unknown option: $key"
                return 2
            }
            if [[ ${CLI_KIND[found]} == flag ]]; then
                [[ $1 != *=* ]] || {
                    cli_error "flag $key takes no value"
                    return 2
                }
                CLI_VALUE[found]=true
            else
                if [[ $1 == *=* ]]; then value=${1#*=}; else
                    (($# > 1)) || {
                        cli_error "missing value for $key"
                        return 2
                    }
                    shift
                    value=$1
                fi
                if [[ -n ${CLI_CHOICES[found]} ]]; then
                    case "|${CLI_CHOICES[found]}|" in *"|$value|"*) ;; *)
                        cli_error "invalid $key value '$value' (expected ${CLI_CHOICES[found]})"
                        return 2
                        ;;
                    esac
                fi
                CLI_VALUE[found]=$value
            fi
            ;;
        *) CLI_POSITIONAL+=("$1") ;;
        esac
        shift
    done
    (("${#CLI_POSITIONAL[@]}" == 1)) || {
        cli_error "expected exactly one <${CLI_ARG_NAME:-text}>"
        return 2
    }
}
