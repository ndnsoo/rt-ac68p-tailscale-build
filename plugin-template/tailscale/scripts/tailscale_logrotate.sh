#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

USB_LOG_DIR=/tmp/mnt/ROUTERUSB/tailscale/logs
MAIN_LOG=$USB_LOG_DIR/tailscaled.log
WATCHDOG_LOG=$USB_LOG_DIR/watchdog.log
STATUS_LOG=/tmp/tailscale-status/status.log

MAIN_LIMIT=8388608
SMALL_LIMIT=262144
SMALL_KEEP=131072
FAIL_KEEP=10

trim_small_log() {
    LOG_FILE=$1
    [ -f "$LOG_FILE" ] || return 0

    LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null)
    [ "${LOG_SIZE:-0}" -le "$SMALL_LIMIT" ] && return 0

    tail -c "$SMALL_KEEP" "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && \
        mv -f "$LOG_FILE.tmp" "$LOG_FILE"
}

rotate_main_log() {
    [ -f "$MAIN_LOG" ] || return 0

    LOG_SIZE=$(wc -c < "$MAIN_LOG" 2>/dev/null)
    [ "${LOG_SIZE:-0}" -le "$MAIN_LIMIT" ] && return 0

    rm -f "$MAIN_LOG.2"
    [ -f "$MAIN_LOG.1" ] && mv -f "$MAIN_LOG.1" "$MAIN_LOG.2"
    cp -f "$MAIN_LOG" "$MAIN_LOG.1" || return 1
    : > "$MAIN_LOG"
}

prune_failure_logs() {
    [ -d "$USB_LOG_DIR" ] || return 0

    LOG_COUNT=0
    for LOG_FILE in $(ls -1t "$USB_LOG_DIR"/failure-*.log 2>/dev/null); do
        LOG_COUNT=$((LOG_COUNT + 1))
        [ "$LOG_COUNT" -le "$FAIL_KEEP" ] || rm -f "$LOG_FILE"
    done
}

trim_small_log "$STATUS_LOG"

if mount | grep -q ' /tmp/mnt/ROUTERUSB type ext4 '; then
    mkdir -p "$USB_LOG_DIR"
    rotate_main_log
    trim_small_log "$WATCHDOG_LOG"
    prune_failure_logs
fi

exit 0
