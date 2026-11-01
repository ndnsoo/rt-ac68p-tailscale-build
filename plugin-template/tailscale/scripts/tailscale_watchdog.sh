#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin
LOCK=/tmp/tailscale_watchdog.lock
TMP=/tmp/tailscale-status
LOG=$TMP/status.log
ST=/jffs/softcenter/scripts/tailscale_storage.sh
CFG=/jffs/softcenter/scripts/tailscale_config.sh
mkdir -p "$TMP"
[ -d "$LOCK" ] && exit 0
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' 0 1 2 3 15
trim_log(){ [ -f "$1" ] || return; SIZE=$(wc -c < "$1" 2>/dev/null); [ "${SIZE:-0}" -gt 262144 ] && { tail -c 131072 "$1" > "$1.tmp"; mv "$1.tmp" "$1"; }; }
log(){ LINE="[$(TZ=UTC-8 date '+%F %T')] $*"; echo "$LINE" >> "$LOG"; trim_log "$LOG"; if "$ST" usb-ready; then mkdir -p /tmp/mnt/ROUTERUSB/tailscale/logs; echo "$LINE" >> /tmp/mnt/ROUTERUSB/tailscale/logs/watchdog.log; trim_log /tmp/mnt/ROUTERUSB/tailscale/logs/watchdog.log; fi; }
[ "$(dbus get tailscale_enable 2>/dev/null)" = 1 ] || { log status=disabled; exit 0; }
if [ -f /jffs/softcenter/configs/tailscale_usb_only ] && ! "$ST" usb-ready; then log "status=usb-missing"; exit 0; fi
OLD=$($ST mode 2>/dev/null); RUNLOG=$($ST select 2>/dev/null); MODE=$($ST mode 2>/dev/null); $ST sync-state >/dev/null 2>&1
[ "$OLD" = "$MODE" ] || log "storage=$OLD->$MODE"
if pidof tailscaled >/dev/null 2>&1; then
    [ -x /jffs/softcenter/scripts/tailscale_legacy_firewall.sh ] && /jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1
    log "status=running mode=$MODE pid=$(pidof tailscaled) ip=$(/jffs/softcenter/bin/tailscale ip -4 2>/dev/null | head -n1)"
    exit 0
fi
if "$ST" usb-ready; then
    SNAP=/tmp/mnt/ROUTERUSB/tailscale/logs/failure-$(date +%Y%m%d-%H%M%S).log
    { date; uname -a; free; cat /proc/swaps; mount; ps; route -n 2>/dev/null; dmesg | tail -n 200; tail -n 250 /tmp/syslog.log 2>/dev/null; } > "$SNAP" 2>&1
    log "status=stopped snapshot=$SNAP"
else
    log "status=stopped mode=jffs"
fi
$CFG start >/dev/null 2>&1
sleep 15
pidof tailscaled >/dev/null 2>&1 && log restart=success || log restart=failed
