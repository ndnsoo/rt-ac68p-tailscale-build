#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin
USBTS=/tmp/mnt/ROUTERUSB/tailscale
CFG=/jffs/softcenter/scripts/tailscale_config.sh
BACKUP=$(ls -1dt "$USBTS"/backups/pre-* 2>/dev/null | head -n 1)
[ -n "$BACKUP" ] || { echo "[错误] 未找到核心备份。"; exit 1; }
"$CFG" stop >/dev/null 2>&1 || true
killall tailscaled >/dev/null 2>&1 || true
sleep 3
if [ -f "$BACKUP/tailscale_combo" ]; then
  mkdir -p /jffs/softcenter/tailscale-core
  cp -pf "$BACKUP/tailscale_combo" /jffs/softcenter/tailscale-core/tailscale_combo || exit 1
  chmod 755 /jffs/softcenter/tailscale-core/tailscale_combo
  ln -sf /jffs/softcenter/tailscale-core/tailscale_combo /jffs/softcenter/tailscale-core/tailscale
  ln -sf /jffs/softcenter/tailscale-core/tailscale_combo /jffs/softcenter/tailscale-core/tailscaled
elif [ -f "$BACKUP/tailscale" ] && [ -f "$BACKUP/tailscaled" ]; then
  mkdir -p /jffs/softcenter/tailscale-core
  cp -pf "$BACKUP/tailscale" /jffs/softcenter/tailscale-core/tailscale || exit 1
  cp -pf "$BACKUP/tailscaled" /jffs/softcenter/tailscale-core/tailscaled || exit 1
  chmod 755 /jffs/softcenter/tailscale-core/tailscale /jffs/softcenter/tailscale-core/tailscaled
else
  echo "[错误] 备份内容不完整：$BACKUP"; exit 1
fi
/jffs/softcenter/scripts/tailscale_storage.sh select >/dev/null 2>&1
"$CFG" start
sleep 15
pidof tailscaled >/dev/null 2>&1 || { echo "[错误] 回退后未启动。"; exit 1; }
echo "[完成] 已恢复：$BACKUP"
