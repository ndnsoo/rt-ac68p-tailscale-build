#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
SERVICES_START=/jffs/scripts/services-start
BLOCK=/tmp/tailscale-v6-block.$$
CLEAN=/tmp/services-start-clean.$$
OUT=/tmp/services-start-new.$$
mkdir -p /jffs/scripts
[ -f "$SERVICES_START" ] || printf '%s\n' '#!/bin/sh' > "$SERVICES_START"
sed '/# TAILSCALE-V6-START/,/# TAILSCALE-V6-END/d; /# TAILSCALE-HS5-START/,/# TAILSCALE-HS5-END/d' "$SERVICES_START" > "$CLEAN" || exit 1
cat > "$BLOCK" <<'EOF'
# TAILSCALE-V6-START
[ -f /tmp/mnt/ROUTERUSB/tailscale-swapfile ] && { grep -q /tmp/mnt/ROUTERUSB/tailscale-swapfile /proc/swaps || /sbin/swapon /tmp/mnt/ROUTERUSB/tailscale-swapfile >/dev/null 2>&1; }
[ -w /proc/sys/vm/swappiness ] && echo 10 > /proc/sys/vm/swappiness
(
  sleep 30
  [ "$(dbus get tailscale_enable 2>/dev/null)" = "1" ] || exit 0
  /jffs/softcenter/scripts/tailscale_storage.sh select >/dev/null 2>&1
  pidof tailscaled >/dev/null 2>&1 || /jffs/softcenter/scripts/tailscale_config.sh start
) &
cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
# TAILSCALE-V6-END
EOF
awk -v block="$BLOCK" 'BEGIN{i=0} /^exit 0[[:space:]]*$/&&!i{while((getline l<block)>0)print l;close(block);i=1}{print} END{if(!i){while((getline l<block)>0)print l;close(block)}}' "$CLEAN" > "$OUT" || exit 1
mv -f "$OUT" "$SERVICES_START" || exit 1
chmod 755 "$SERVICES_START"
sh -n "$SERVICES_START" || exit 1
rm -f "$BLOCK" "$CLEAN"
[ -w /proc/sys/vm/swappiness ] && echo 10 > /proc/sys/vm/swappiness
cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
exit 0
