#!/usr/bin/env bash
set -euo pipefail
DIST=${1:?dist directory required}
FLAVOR=${2:?flavor required}
GOARM=${3:?GOARM required}
ROOT=${4:?repository root required}
SRC="$ROOT/plugin-template/tailscale"
WORK="$ROOT/package-work/tailscale"
OUT="$ROOT/out-softcenter"
rm -rf "$ROOT/package-work"
mkdir -p "$WORK/bin" "$OUT"
cp -a "$SRC/." "$WORK/"
cp "$DIST/tailscale-$FLAVOR" "$WORK/bin/tailscale"
cp "$DIST/tailscaled-$FLAVOR" "$WORK/bin/tailscaled"
chmod 755 "$WORK/bin/tailscale" "$WORK/bin/tailscaled" "$WORK/install.sh" "$WORK/uninstall.sh" "$WORK/scripts"/*.sh
printf '%s\n' "0.2.0-v1.104.4-go1.27.3-armv${GOARM}-${FLAVOR}-dual" > "$WORK/version"
(
  cd "$WORK"
  sha256sum bin/tailscale bin/tailscaled > CORE-SHA256SUMS
)
cat > "$WORK/安装说明.txt" <<EOF
Tailscale v1.104.4 / Go 1.27.3 / ARMv${GOARM} / ${FLAVOR}
梅林Softcenter双存储离线安装包。

有ROUTERUSB时：核心和详细日志使用U盘，状态文件以JFFS为主并同步保险副本到U盘。
无ROUTERUSB时：核心直接使用JFFS，状态保存在JFFS，运行状态记入/tmp轻量日志。
每5分钟自动检测存储变化、修复链接、同步状态并在进程退出时恢复。
EOF
cat > "$WORK/工作流.txt" <<EOF
版本：v6 dual storage
构建时间：$(date -u '+%Y-%m-%d %H:%M:%S UTC')
Tailscale：v1.104.4
Go：1.27.3
GOARM：${GOARM}
构建类型：${FLAVOR}
实现：GitHub Actions完成核心构建后直接注入完整Softcenter模板并生成可后台上传的tar.gz。
存储策略：JFFS保底运行；ROUTERUSB存在时优先使用USB核心和详细日志；U盘拔出时切回JFFS核心和/tmp轻量状态日志。
EOF
PKG="Headscale_1.104.4-go1.27.3-armv${GOARM}-${FLAVOR}-dual-v6.tar.gz"
tar -C "$ROOT/package-work" -czf "$OUT/$PKG" tailscale
sha256sum "$OUT/$PKG" > "$OUT/$PKG.sha256"
