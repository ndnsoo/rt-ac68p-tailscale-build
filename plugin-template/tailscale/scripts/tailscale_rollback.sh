#!/bin/sh
PATH=/jffs/softcenter/bin:/jffs/softcenter/scripts:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
USBTS=/tmp/mnt/ROUTERUSB/tailscale
CFG=/jffs/softcenter/scripts/tailscale_config.sh
BACKUP_ROOT=${USBTS}/backups
BACKUP=$(ls -1dt ${BACKUP_ROOT}/pre-hs5-* 2>/dev/null | head -n 1)
[ -n "$BACKUP" ] || { echo "[错误] 没有找到pre-hs5备份。"; exit 1; }
[ -f "$BACKUP/tailscale" ] && [ -f "$BACKUP/tailscaled" ] || { echo "[错误] 备份不完整：$BACKUP"; exit 1; }
"$CFG" stop >/dev/null 2>&1 || true
killall tailscaled >/dev/null 2>&1 || true
sleep 3
cp -pf "$BACKUP/tailscale" "$USBTS/bin/tailscale" || exit 1
cp -pf "$BACKUP/tailscaled" "$USBTS/bin/tailscaled" || exit 1
chmod 755 "$USBTS/bin/tailscale" "$USBTS/bin/tailscaled"
sync
"$CFG" start
sleep 15
pidof tailscaled >/dev/null 2>&1 || { echo "[错误] 原核心恢复后未启动。"; exit 1; }
/jffs/softcenter/bin/tailscale version
echo "[完成] 已恢复：$BACKUP"
