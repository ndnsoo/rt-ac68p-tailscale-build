#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
LOCK=/tmp/tailscale_watchdog.lock
TMPDIR=/tmp/tailscale-status
TMPLOG=$TMPDIR/status.log
USBLOG=/tmp/mnt/ROUTERUSB/tailscale/logs/watchdog.log
CFG=/jffs/softcenter/scripts/tailscale_config.sh
STORAGE=/jffs/softcenter/scripts/tailscale_storage.sh
mkdir -p "$TMPDIR"
[ -d "$LOCK" ] && exit 0
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' 0 1 2 3 15
stamp(){ TZ=UTC-8 date '+%Y-%m-%d %H:%M:%S'; }
trim(){ [ -f "$1" ] || return; S=$(wc -c < "$1" 2>/dev/null); [ "${S:-0}" -gt 262144 ] && { tail -c 131072 "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }; }
log(){ echo "[$(stamp)] $*" >> "$TMPLOG"; trim "$TMPLOG"; if "$STORAGE" usb-ready; then mkdir -p "$(dirname "$USBLOG")"; echo "[$(stamp)] $*" >> "$USBLOG"; trim "$USBLOG"; fi; }

[ "$(dbus get tailscale_enable 2>/dev/null)" = "1" ] || { log "status=disabled"; exit 0; }
OLD_MODE=$($STORAGE mode 2>/dev/null)
RUN_LOG=$($STORAGE select 2>/dev/null)
NEW_MODE=$($STORAGE mode 2>/dev/null)
$STORAGE sync-state >/dev/null 2>&1
[ "$OLD_MODE" = "$NEW_MODE" ] || log "storage=$OLD_MODE->$NEW_MODE log=$RUN_LOG"

if pidof tailscaled >/dev/null 2>&1; then
    IP=$(/jffs/softcenter/bin/tailscale ip -4 2>/dev/null | head -n1)
    STATE=$(/jffs/softcenter/bin/tailscale status --json 2>/dev/null | /jffs/softcenter/bin/jq -r '.BackendState // "unknown"' 2>/dev/null)
    log "status=running mode=$NEW_MODE pid=$(pidof tailscaled) ip=${IP:-none} backend=${STATE:-unknown}"
    exit 0
fi

# Detailed failure evidence is written to USB only when USB is available.
if "$STORAGE" usb-ready; then
    SNAP="/tmp/mnt/ROUTERUSB/tailscale/logs/failure-$(TZ=UTC-8 date '+%Y%m%d-%H%M%S').log"
    {
      date -R; uname -a; free; cat /proc/swaps; mount; ps; route -n 2>/dev/null
      dmesg 2>/dev/null | tail -n 200
      tail -n 250 /tmp/syslog.log 2>/dev/null
      tail -n 250 /tmp/mnt/ROUTERUSB/tailscale/logs/tailscaled.log 2>/dev/null
    } > "$SNAP" 2>&1
    log "status=stopped snapshot=$SNAP restarting=yes"
else
    log "status=stopped mode=jffs restarting=yes"
fi
"$CFG" start >/dev/null 2>&1
sleep 15
pidof tailscaled >/dev/null 2>&1 && log "restart=success pid=$(pidof tailscaled)" || log "restart=failed"
