#!/bin/sh
F=/jffs/scripts/services-start; B=/tmp/tsv10-block.$$; C=/tmp/tsv10-clean.$$; O=/tmp/tsv10-new.$$
mkdir -p /jffs/scripts; [ -f "$F" ] || echo '#!/bin/sh' > "$F"
sed '/# TAILSCALE-V10-START/,/# TAILSCALE-V10-END/d; /# TAILSCALE-V6-START/,/# TAILSCALE-V6-END/d' "$F" > "$C"
cat > "$B" <<'EOF'
# TAILSCALE-V10-START
[ -f /tmp/mnt/ROUTERUSB/tailscale-swapfile ] && { grep -q /tmp/mnt/ROUTERUSB/tailscale-swapfile /proc/swaps || swapon /tmp/mnt/ROUTERUSB/tailscale-swapfile >/dev/null 2>&1; }
[ -w /proc/sys/vm/swappiness ] && echo 10 > /proc/sys/vm/swappiness
( sleep 30; [ "$(dbus get tailscale_enable 2>/dev/null)" = 1 ] && { pidof tailscaled >/dev/null 2>&1 || /jffs/softcenter/scripts/tailscale_config.sh start; } ) &
cru d TailscaleWatchdog >/dev/null 2>&1
cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
# TAILSCALE-V10-END
EOF
awk -v b="$B" 'BEGIN{i=0} /^exit 0[[:space:]]*$/&&!i{while((getline l<b)>0)print l;close(b);i=1}{print} END{if(!i){while((getline l<b)>0)print l;close(b)}}' "$C" > "$O" || exit 1
mv "$O" "$F"; chmod 755 "$F"; sh -n "$F" || exit 1; rm -f "$B" "$C"
cru d TailscaleWatchdog >/dev/null 2>&1; cru a TailscaleWatchdog "*/5 * * * * /jffs/softcenter/scripts/tailscale_watchdog.sh"
