#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
TSIF=tailscale0
LANIF=br0
has_filter(){ iptables-save 2>/dev/null | grep -F -- "-A $1 $2" >/dev/null 2>&1; }
has_nat(){ iptables-save -t nat 2>/dev/null | grep -F -- "-A $1 $2" >/dev/null 2>&1; }
add_filter(){ C=$1; shift; SPEC="$*"; has_filter "$C" "$SPEC" || iptables -I "$C" 1 "$@"; }
add_nat(){ C=$1; shift; SPEC="$*"; has_nat "$C" "$SPEC" || iptables -t nat -A "$C" "$@"; }
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
