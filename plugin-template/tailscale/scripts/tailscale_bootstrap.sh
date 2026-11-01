#!/bin/sh
F=/jffs/scripts/services-start
B=/tmp/tailscale-v12-block.$$
C=/tmp/tailscale-v12-clean.$$
O=/tmp/tailscale-v12-new.$$
mkdir -p /jffs/scripts
[ -f "$F" ] || printf '%s\n' '#!/bin/sh' > "$F"
sed '/# TAILSCALE-V12-START/,/# TAILSCALE-V12-END/d; /# TAILSCALE-V10-START/,/# TAILSCALE-V10-END/d; /# TAILSCALE-V6-START/,/# TAILSCALE-V6-END/d' "$F" > "$C" || exit 1
cat > "$B" <<'EOF'
# TAILSCALE-V12-START
[ -f /tmp/mnt/ROUTERUSB/tailscale-swapfile ] && { grep -q /tmp/mnt/ROUTERUSB/tailscale-swapfile /proc/swaps || /sbin/swapon /tmp/mnt/ROUTERUSB/tailscale-swapfile >/dev/null 2>&1; }
[ -w /proc/sys/vm/swappiness ] && echo 10 > /proc/sys/vm/swappiness
( sleep 30; [ "$(dbus get tailscale_enable 2>/dev/null)" = 1 ] && { pidof tailscaled >/dev/null 2>&1 || /jffs/softcenter/scripts/tailscale_config.sh start; } ) &
cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
# TAILSCALE-V12-END
EOF
awk -v block="$B" 'BEGIN{i=0} /^exit 0[[:space:]]*$/&&!i{while((getline l<block)>0)print l;close(block);i=1}{print} END{if(!i){while((getline l<block)>0)print l;close(block)}}' "$C" > "$O" || exit 1
mv -f "$O" "$F" || exit 1
chmod 755 "$F"
sh -n "$F" || exit 1
rm -f "$B" "$C"
cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
