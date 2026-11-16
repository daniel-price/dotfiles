#!/usr/bin/env bash
# Print macos or debian; return nonzero for unsupported or unidentified systems.
# Optional kernel and os-release path arguments allow fixtures without host changes.
detect_os() {
    local kernel os_release key value distribution like
    if [[ $# -gt 2 ]]; then
        printf '[error] detect_os accepts at most a kernel and metadata path.\n' >&2
        return 1
    fi
    kernel=${1:-$(uname -s)}
    case "$kernel" in
    Darwin)
        printf '%s\n' macos
        return 0
        ;;
    Linux) ;;
    *)
        printf '[error] Unsupported operating system: %s.\n' "$kernel" >&2
        return 1
        ;;
    esac

    os_release=${2:-/etc/os-release}
    # Match the standard fallback only for real host detection, never fixtures.
    if [[ $# -lt 2 && ! -r "$os_release" ]]; then
        os_release=/usr/lib/os-release
    fi
    if [[ ! -r "$os_release" || ! -f "$os_release" ]]; then
        printf '[error] Cannot read Linux os-release metadata.\n' >&2
        return 1
    fi

    distribution=''
    like=''
    # Read only the identity fields as data; never source or eval the file.
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        case "$key" in
        ID | ID_LIKE)
            case "$value" in
            \"*\")
                value=${value#\"}
                value=${value%\"}
                ;;
            \'*\')
                value=${value#\'}
                value=${value%\'}
                ;;
            esac
            case "$key" in
            ID) distribution=$value ;;
            ID_LIKE) like=$value ;;
            esac
            ;;
        esac
    done <"$os_release"

    case " $distribution $like " in
    *' debian '* | *' ubuntu '* | *' pop '*) printf '%s\n' debian ;;
    *)
        printf '[error] Unsupported Linux distribution; expected Debian/Ubuntu family.\n' >&2
        return 1
        ;;
    esac
}
