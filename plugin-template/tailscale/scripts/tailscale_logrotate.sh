#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
USBLOG=/tmp/mnt/ROUTERUSB/tailscale/logs
MAIN=$USBLOG/tailscaled.log
WATCHDOG=$USBLOG/watchdog.log
STATUS=/tmp/tailscale-status/status.log
MAIN_LIMIT=8388608
SMALL_LIMIT=262144
SMALL_KEEP=131072
FAIL_KEEP=10

trim_small_log(){
    FILE=$1
    [ -f "$FILE" ] || return 0
    SIZE=$(wc -c < "$FILE" 2>/dev/null)
    [ "${SIZE:-0}" -le "$SMALL_LIMIT" ] && return 0
    tail -c "$SMALL_KEEP" "$FILE" > "$FILE.tmp" 2>/dev/null && mv -f "$FILE.tmp" "$FILE"
}

rotate_main_log(){
    [ -f "$MAIN" ] || return 0
    SIZE=$(wc -c < "$MAIN" 2>/dev/null)
    [ "${SIZE:-0}" -le "$MAIN_LIMIT" ] && return 0
    rm -f "$MAIN.2"
    [ -f "$MAIN.1" ] && mv -f "$MAIN.1" "$MAIN.2"
    cp -f "$MAIN" "$MAIN.1" || return 1
    : > "$MAIN"
}

prune_failure_logs(){
    [ -d "$USBLOG" ] || return 0
    COUNT=0
    for FILE in $(ls -1t "$USBLOG"/failure-*.log 2>/dev/null); do
        COUNT=$((COUNT + 1))
        [ "$COUNT" -le "$FAIL_KEEP" ] || rm -f "$FILE"
    done
}

trim_small_log "$STATUS"
if mount | grep -q ' /tmp/mnt/ROUTERUSB type ext4 '; then
    mkdir -p "$USBLOG"
    rotate_main_log
    trim_small_log "$WATCHDOG"
    prune_failure_logs
fi
exit 0
