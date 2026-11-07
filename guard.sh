#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

chain=TORRENT_GUARD
binary=/usr/local/sbin/torrent-guard
unit=torrent-guard.service
unit_file=/etc/systemd/system/$unit
hooks=(OUTPUT FORWARD)
families=(iptables ip6tables)

usage() {
    printf 'Usage: %s {install|apply|status|remove|uninstall}\n' "$0"
}

action=${1:-help}
case "$action" in
    -h|--help|help) usage; exit 0 ;;
    install|apply|status|remove|uninstall) ;;
    *) usage >&2; exit 2 ;;
esac
if (( $# != 1 || EUID != 0 )); then
    printf 'Run one action as root.\n' >&2
    exit 2
fi

write_rules() {
    local firewall=$1 operation=$2 rules hook
    rules=$("$firewall" -w -S) || return
    printf '*filter\n'
    if [[ $operation == apply ]]; then
        printf ':%s - [0:0]\n' "$chain"
    fi

    for hook in "${hooks[@]}"; do
        while IFS= read -r rule; do
            if [[ $rule == "-A $hook -j $chain" ]]; then
                printf -- '-D %s -j %s\n' "$hook" "$chain"
            fi
        done <<< "$rules"
        if [[ $operation == apply ]]; then
            printf -- '-I %s 1 -j %s\n' "$hook" "$chain"
        fi
    done

    if [[ $operation == apply ]]; then
        # BEP 3 peer handshake, including its one-byte protocol name length.
        printf -- '-A %s -p tcp -m string --algo kmp --to 256 --hex-string "|13|BitTorrent protocol" -j DROP\n' "$chain"
        # BEP 15 UDP tracker connect request: protocol ID and connect action.
        printf -- '-A %s -p udp -m string --algo kmp --to 128 --hex-string "|000004172710198000000000|" -j DROP\n' "$chain"
        # BEP 5 DHT get_peers and announce_peer queries.
        for query in '1:q9:get_peers' '1:q13:announce_peer'; do
            printf -- '-A %s -p udp -m string --algo kmp --to 256 --string "%s" -m string --algo kmp --to 256 --string "9:info_hash20:" -j DROP\n' "$chain" "$query"
        done
    elif grep -Fxq -- "-N $chain" <<< "$rules"; then
        printf -- '-F %s\n-X %s\n' "$chain" "$chain"
    fi
    printf 'COMMIT\n'
}

update_rules() {
    local operation=$1 firewall work
    exec 9>/run/lock/torrent-guard.lock
    flock -x 9
    work=$(mktemp -d)
    trap 'rm -rf -- "$work"' EXIT
    for firewall in "${families[@]}"; do
        write_rules "$firewall" "$operation" > "$work/$firewall"
        "${firewall}-restore" -w --noflush --test < "$work/$firewall"
    done
    for firewall in "${families[@]}"; do
        "${firewall}-restore" -w --noflush < "$work/$firewall"
    done
    rm -rf -- "$work"
    trap - EXIT
}

show_status() {
    local firewall hook failed=0
    for firewall in "${families[@]}"; do
        printf '\n%s\n' "$firewall"
        "$firewall" -w -n -v -x -L "$chain" || failed=1
        for hook in "${hooks[@]}"; do
            if ! "$firewall" -w -C "$hook" -j "$chain"; then
                printf 'Missing %s hook.\n' "$hook" >&2
                failed=1
            fi
        done
    done
    return "$failed"
}

case "$action" in
    install)
        if [[ ! -d /run/systemd/system ]]; then
            printf 'Installation requires systemd. Use apply for a temporary setup.\n' >&2
            exit 1
        fi
        "$BASH" "$0" apply
        if [[ ! "$0" -ef "$binary" ]]; then
            install -m 0755 -- "$0" "$binary"
        fi
        cat > "$unit_file" <<'UNIT'
[Unit]
Description=Torrent Guard packet filter
After=network-pre.target ufw.service firewalld.service nftables.service netfilter-persistent.service docker.service
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/torrent-guard apply

[Install]
WantedBy=multi-user.target
UNIT
        systemctl daemon-reload
        systemctl enable --now "$unit"
        ;;
    apply|remove) update_rules "$action" ;;
    status) show_status ;;
    uninstall)
        if [[ -f $unit_file ]]; then
            systemctl disable --now "$unit"
        fi
        update_rules remove
        if [[ -f $unit_file ]]; then
            rm -- "$unit_file"
            systemctl daemon-reload
        fi
        rm -f -- "$binary"
        ;;
esac
