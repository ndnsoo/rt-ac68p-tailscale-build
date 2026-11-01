#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin

LOCK_DIR=/tmp/tailscale_watchdog.lock
STATUS_DIR=/tmp/tailscale-status
STATUS_LOG=$STATUS_DIR/status.log
STORAGE_SCRIPT=/jffs/softcenter/scripts/tailscale_storage.sh
CONFIG_SCRIPT=/jffs/softcenter/scripts/tailscale_config.sh
LOGROTATE_SCRIPT=/jffs/softcenter/scripts/tailscale_logrotate.sh
LEGACY_FIREWALL=/jffs/softcenter/scripts/tailscale_legacy_firewall.sh

mkdir -p "$STATUS_DIR"
[ -x "$LOGROTATE_SCRIPT" ] && "$LOGROTATE_SCRIPT" >/dev/null 2>&1

[ -d "$LOCK_DIR" ] && exit 0
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null' 0 1 2 3 15

write_log() {
    LOG_LINE="[$(date '+%F %T')] $*"
    echo "$LOG_LINE" >> "$STATUS_LOG"

    if "$STORAGE_SCRIPT" usb-ready; then
        mkdir -p /tmp/mnt/ROUTERUSB/tailscale/logs
        echo "$LOG_LINE" >> /tmp/mnt/ROUTERUSB/tailscale/logs/watchdog.log
    fi
}

if [ "$(dbus get tailscale_enable 2>/dev/null)" != "1" ]; then
    write_log "status=disabled"
    exit 0
fi

if [ -f /jffs/softcenter/configs/tailscale_usb_only ] && \
   ! "$STORAGE_SCRIPT" usb-ready; then
    write_log "status=usb-missing"
    exit 0
fi

OLD_MODE=$($STORAGE_SCRIPT mode 2>/dev/null)
$STORAGE_SCRIPT select >/dev/null 2>&1
CURRENT_MODE=$($STORAGE_SCRIPT mode 2>/dev/null)
$STORAGE_SCRIPT sync-state >/dev/null 2>&1

[ "$OLD_MODE" = "$CURRENT_MODE" ] || \
    write_log "storage=$OLD_MODE->$CURRENT_MODE"

if pidof tailscaled >/dev/null 2>&1; then
    [ -x "$LEGACY_FIREWALL" ] && "$LEGACY_FIREWALL" start >/dev/null 2>&1
    write_log "status=running mode=$CURRENT_MODE pid=$(pidof tailscaled)"
    exit 0
fi

if "$STORAGE_SCRIPT" usb-ready; then
    SNAPSHOT=/tmp/mnt/ROUTERUSB/tailscale/logs/failure-$(date +%Y%m%d-%H%M%S).log
    {
        date
        uname -a
        free
        cat /proc/swaps
        mount
        ps
        dmesg | tail -n 200
    } > "$SNAPSHOT" 2>&1
    write_log "status=stopped snapshot=$SNAPSHOT"
else
    write_log "status=stopped"
fi

$CONFIG_SCRIPT start >/dev/null 2>&1
sleep 15

if pidof tailscaled >/dev/null 2>&1; then
    write_log "restart=success"
else
    write_log "restart=failed"
fi
