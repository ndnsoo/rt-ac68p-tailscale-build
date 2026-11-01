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
    if [ -f /jffs/softcenter/configs/tailscale_usb_only ]; then
        if usb_ready && [ -x "$USBTS/bin/tailscale" ] && [ -x "$USBTS/bin/tailscaled" ]; then
            ln -sf "$USBTS/bin/tailscale" /jffs/softcenter/bin/tailscale
            ln -sf "$USBTS/bin/tailscaled" /jffs/softcenter/bin/tailscaled
            echo usb-only > "$MODE_FILE"
            echo "$USBTS/logs/tailscaled.log"
            return 0
        fi
        echo usb-missing > "$MODE_FILE"
        echo /tmp/tailscale-status/tailscaled.log
        return 1
    fi
    if usb_ready; then
        mkdir -p "$USBTS/bin" "$USBTS/state" "$USBTS/logs" "$USBTS/backups"
        if [ -x "$JCORE/tailscale_combo" ]; then
            [ -x "$USBTS/bin/tailscale_combo" ] || cp -pf "$JCORE/tailscale_combo" "$USBTS/bin/tailscale_combo"
            chmod 755 "$USBTS/bin/tailscale_combo"
            ln -sf "$USBTS/bin/tailscale_combo" /jffs/softcenter/bin/tailscale
            ln -sf "$USBTS/bin/tailscale_combo" /jffs/softcenter/bin/tailscaled
        else
            [ -x "$USBTS/bin/tailscale" ] || cp -pf "$JCORE/tailscale" "$USBTS/bin/tailscale"
            [ -x "$USBTS/bin/tailscaled" ] || cp -pf "$JCORE/tailscaled" "$USBTS/bin/tailscaled"
            chmod 755 "$USBTS/bin/tailscale" "$USBTS/bin/tailscaled"
            ln -sf "$USBTS/bin/tailscale" /jffs/softcenter/bin/tailscale
            ln -sf "$USBTS/bin/tailscaled" /jffs/softcenter/bin/tailscaled
        fi
        [ -f "$JSTATE/tailscaled.state" ] || [ ! -f "$USBTS/state/tailscaled.state" ] || cp -pf "$USBTS/state/tailscaled.state" "$JSTATE/tailscaled.state"
        [ -f "$JSTATE/tailscaled.state" ] && cp -pf "$JSTATE/tailscaled.state" "$USBTS/state/tailscaled.state.backup" 2>/dev/null
        echo usb > "$MODE_FILE"
        echo "$USBTS/logs/tailscaled.log"
    else
        if [ -x "$JCORE/tailscale_combo" ]; then
            ln -sf "$JCORE/tailscale_combo" /jffs/softcenter/bin/tailscale
            ln -sf "$JCORE/tailscale_combo" /jffs/softcenter/bin/tailscaled
        else
            ln -sf "$JCORE/tailscale" /jffs/softcenter/bin/tailscale
            ln -sf "$JCORE/tailscaled" /jffs/softcenter/bin/tailscaled
        fi
        echo jffs > "$MODE_FILE"
        echo /tmp/tailscale-status/tailscaled.log
    fi
}
case "$1" in
    select|"") select_storage ;;
    mode) [ -f "$MODE_FILE" ] && cat "$MODE_FILE" || echo unknown ;;
    usb-ready) usb_ready ;;
    sync-state) usb_ready && [ -f "$JSTATE/tailscaled.state" ] && cp -pf "$JSTATE/tailscaled.state" "$USBTS/state/tailscaled.state.backup" 2>/dev/null ;;
esac
