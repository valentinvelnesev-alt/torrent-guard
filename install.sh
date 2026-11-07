#!/bin/sh
set -eu

install_guard() {
    if [ "$(id -u)" -ne 0 ]; then
        printf '%s\n' 'Run the installer as root.' >&2
        exit 1
    fi

    installer=$(mktemp)
    trap 'rm -f -- "$installer"' EXIT
    trap 'exit 1' HUP INT TERM

    curl -fsSL --proto '=https' --proto-redir '=https' \
        -o "$installer" \
        https://raw.githubusercontent.com/valentinvelnesev-alt/torrent-guard/main/guard.sh
    bash "$installer" install
}

install_guard
