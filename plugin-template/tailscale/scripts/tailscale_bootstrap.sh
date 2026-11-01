#!/bin/sh

SERVICES_START=/jffs/scripts/services-start
BLOCK_FILE=/tmp/tailscale-v12-block.$$
CLEAN_FILE=/tmp/tailscale-v12-clean.$$
OUTPUT_FILE=/tmp/tailscale-v12-new.$$

mkdir -p /jffs/scripts

if [ ! -f "$SERVICES_START" ]; then
    echo '#!/bin/sh' > "$SERVICES_START"
fi

sed '/# TAILSCALE-V12-START/,/# TAILSCALE-V12-END/d' \
    "$SERVICES_START" > "$CLEAN_FILE" || exit 1

cat > "$BLOCK_FILE" <<'EOF'
# TAILSCALE-V12-START
[ -f /tmp/mnt/ROUTERUSB/tailscale-swapfile ] && { grep -q /tmp/mnt/ROUTERUSB/tailscale-swapfile /proc/swaps || /sbin/swapon /tmp/mnt/ROUTERUSB/tailscale-swapfile >/dev/null 2>&1; }
[ -w /proc/sys/vm/swappiness ] && echo 10 > /proc/sys/vm/swappiness
( sleep 30; [ "$(dbus get tailscale_enable 2>/dev/null)" = 1 ] && { pidof tailscaled >/dev/null 2>&1 || /jffs/softcenter/scripts/tailscale_config.sh start; } ) &
cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
# TAILSCALE-V12-END
EOF

awk -v block="$BLOCK_FILE" '
BEGIN {
    inserted = 0
}
/^exit 0[[:space:]]*$/ && !inserted {
    while ((getline line < block) > 0) {
        print line
    }
    close(block)
    inserted = 1
}
{
    print
}
END {
    if (!inserted) {
        while ((getline line < block) > 0) {
            print line
        }
        close(block)
    }
}
' "$CLEAN_FILE" > "$OUTPUT_FILE" || exit 1

mv -f "$OUTPUT_FILE" "$SERVICES_START" || exit 1
chmod 755 "$SERVICES_START"
sh -n "$SERVICES_START" || exit 1

rm -f "$BLOCK_FILE" "$CLEAN_FILE"

cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog \
    "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"

exit 0
