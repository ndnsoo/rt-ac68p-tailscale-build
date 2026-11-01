#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
TSIF=tailscale0
LANIF=br0
case "$1" in
  start|"")
    [ -w /proc/sys/net/ipv4/ip_forward ] && echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables-save | grep -F -- '-A INPUT -i tailscale0 -j ACCEPT' >/dev/null 2>&1 || iptables -I INPUT 1 -i "$TSIF" -j ACCEPT
    iptables-save | grep -F -- '-A FORWARD -i tailscale0 -j ACCEPT' >/dev/null 2>&1 || iptables -I FORWARD 1 -i "$TSIF" -j ACCEPT
    iptables-save | grep -F -- '-A FORWARD -o tailscale0 -j ACCEPT' >/dev/null 2>&1 || iptables -I FORWARD 1 -o "$TSIF" -j ACCEPT
    iptables-save -t nat | grep -F -- '-A POSTROUTING -s 100.64.0.0/10 -o br0 -j MASQUERADE' >/dev/null 2>&1 || iptables -t nat -A POSTROUTING -s 100.64.0.0/10 -o "$LANIF" -j MASQUERADE
    ;;
  stop)
    iptables -D INPUT -i "$TSIF" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$TSIF" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -o "$TSIF" -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 100.64.0.0/10 -o "$LANIF" -j MASQUERADE 2>/dev/null || true
    ;;
esac
