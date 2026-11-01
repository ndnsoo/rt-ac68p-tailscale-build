#!/bin/sh
# Linux 2.6.36 manual netfilter rules for Tailscale TUN/subnet routing.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
TSIF=tailscale0
LANIF=br0
rule_exists(){
    TABLE=$1; shift
    CHAIN=$1; shift
    if [ "$TABLE" = filter ]; then
        iptables-save 2>/dev/null | grep -F -- "-A $CHAIN $*" >/dev/null 2>&1
    else
        iptables-save -t "$TABLE" 2>/dev/null | grep -F -- "-A $CHAIN $*" >/dev/null 2>&1
    fi
}
add_filter(){ CHAIN=$1; shift; rule_exists filter "$CHAIN" "$@" || iptables -I "$CHAIN" 1 "$@"; }
add_nat(){ CHAIN=$1; shift; rule_exists nat "$CHAIN" "$@" || iptables -t nat -A "$CHAIN" "$@"; }
case "$1" in
  start|"")
    [ -w /proc/sys/net/ipv4/ip_forward ] && echo 1 > /proc/sys/net/ipv4/ip_forward
    add_filter INPUT -i "$TSIF" -j ACCEPT
    add_filter FORWARD -i "$TSIF" -j ACCEPT
    add_filter FORWARD -o "$TSIF" -j ACCEPT
    add_nat POSTROUTING -s 100.64.0.0/10 -o "$LANIF" -j MASQUERADE
    ;;
  stop)
    iptables -D INPUT -i "$TSIF" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$TSIF" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -o "$TSIF" -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 100.64.0.0/10 -o "$LANIF" -j MASQUERADE 2>/dev/null || true
    ;;
esac
exit 0
