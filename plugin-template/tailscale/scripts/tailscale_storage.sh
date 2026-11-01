#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin
JCORE=/jffs/softcenter/tailscale-core
JSTATE=/jffs/softcenter/etc/tailscale
USBROOT=/tmp/mnt/ROUTERUSB
USBTS=$USBROOT/tailscale
MODE_FILE=/tmp/tailscale_storage_mode
usb_ready(){ mount | grep -q " $USBROOT type ext4 "; }
select_storage(){
    mkdir -p "$JCORE" "$JSTATE" /tmp/tailscale-status
    if usb_ready; then
        mkdir -p "$USBTS/bin" "$USBTS/state" "$USBTS/logs" "$USBTS/backups"
        [ -x "$USBTS/bin/tailscale" ] || cp -pf "$JCORE/tailscale" "$USBTS/bin/tailscale" 2>/dev/null
        [ -x "$USBTS/bin/tailscaled" ] || cp -pf "$JCORE/tailscaled" "$USBTS/bin/tailscaled" 2>/dev/null
        chmod 755 "$USBTS/bin/tailscale" "$USBTS/bin/tailscaled" 2>/dev/null
        # Migrate an existing USB identity only when the canonical JFFS identity is absent.
        [ -f "$JSTATE/tailscaled.state" ] || [ ! -f "$USBTS/state/tailscaled.state" ] || cp -pf "$USBTS/state/tailscaled.state" "$JSTATE/tailscaled.state"
        [ -f "$JSTATE/tailscaled.state" ] && cp -pf "$JSTATE/tailscaled.state" "$USBTS/state/tailscaled.state.backup" 2>/dev/null
        ln -sf "$USBTS/bin/tailscale" /jffs/softcenter/bin/tailscale
        ln -sf "$USBTS/bin/tailscaled" /jffs/softcenter/bin/tailscaled
        echo usb > "$MODE_FILE"
        echo "$USBTS/logs/tailscaled.log"
    else
        ln -sf "$JCORE/tailscale" /jffs/softcenter/bin/tailscale
        ln -sf "$JCORE/tailscaled" /jffs/softcenter/bin/tailscaled
        echo jffs > "$MODE_FILE"
        echo /tmp/tailscale-status/tailscaled.log
    fi
}
case "$1" in
    select|"") select_storage ;;
    mode) [ -f "$MODE_FILE" ] && cat "$MODE_FILE" || echo unknown ;;
    usb-ready) usb_ready ;;
    sync-state)
        usb_ready && [ -f "$JSTATE/tailscaled.state" ] && {
            mkdir -p "$USBTS/state"
            cp -pf "$JSTATE/tailscaled.state" "$USBTS/state/tailscaled.state.backup" 2>/dev/null
        }
        ;;
esac
