#!/usr/bin/env bash
set -euo pipefail
DIST=${1:?dist directory required}
FLAVOR=${2:?flavor required}
GOARM=${3:?GOARM required}
ROOT=${4:?repository root required}
TAILSCALE_REF=${5:?Tailscale ref required}
GO_VERSION=${6:?Go version required}
VERSION_NO_V=${TAILSCALE_REF#v}
SRC="$ROOT/plugin-template/tailscale"
WORK="$ROOT/package-work/tailscale"
OUT="$ROOT/out-softcenter"
rm -rf "$ROOT/package-work"
mkdir -p "$WORK/bin" "$OUT"
cp -a "$SRC/." "$WORK/"
if [ "$FLAVOR" = "legacy-runtime" ]; then
  cp -a "$ROOT/plugin-overlays/legacy-runtime/." "$WORK/"
  python3 - "$WORK" <<'PYFIX'
from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'scripts/tailscale_config.sh'
s=p.read_text()
s=s.replace('args=" --login-server=', 'args=" --netfilter-mode=off --login-server=', 1)
needle='\t\t/jffs/softcenter/bin/tailscale up --accept-dns=false ${args} &\n'
if needle not in s: raise SystemExit('tailscale up insertion point missing')
s=s.replace(needle, needle+'\t\tsleep 3\n\t\t/jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1\n', 1)
needle2='\t\tkillall tailscale >/dev/null 2>&1 \n'
s=s.replace(needle2, '\t\t/jffs/softcenter/scripts/tailscale_legacy_firewall.sh stop >/dev/null 2>&1\n'+needle2, 1)
p.write_text(s)
w=root/'scripts/tailscale_watchdog.sh'
t=w.read_text()
mark='if pidof tailscaled >/dev/null 2>&1; then\n'
if mark not in t: raise SystemExit('watchdog insertion point missing')
t=t.replace(mark, mark+'    /jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1\n', 1)
w.write_text(t)
PYFIX
fi
cp "$DIST/tailscale-$FLAVOR" "$WORK/bin/tailscale"
cp "$DIST/tailscaled-$FLAVOR" "$WORK/bin/tailscaled"
chmod 755 "$WORK/bin/tailscale" "$WORK/bin/tailscaled" "$WORK/install.sh" "$WORK/uninstall.sh" "$WORK/scripts"/*.sh
printf '%s\n' "0.2.1-${TAILSCALE_REF}-go${GO_VERSION}-armv${GOARM}-${FLAVOR}-dual-v9" > "$WORK/version"
(
  cd "$WORK"
  sha256sum bin/tailscale bin/tailscaled > CORE-SHA256SUMS
)
cat > "$WORK/安装说明.txt" <<EOF
Tailscale ${TAILSCALE_REF} / Go ${GO_VERSION} / ARMv${GOARM} / ${FLAVOR}
梅林Softcenter双存储离线安装包。

有ROUTERUSB时：核心和详细日志使用U盘，状态文件以JFFS为主并同步保险副本到U盘。
无ROUTERUSB时：核心直接使用JFFS，状态保存在JFFS，运行状态记入/tmp轻量日志。
每5分钟自动检测存储变化、修复链接、同步状态并在进程退出时恢复。
EOF
cat > "$WORK/工作流.txt" <<EOF
版本：v6 dual storage
构建时间：$(date -u '+%Y-%m-%d %H:%M:%S UTC')
Tailscale：${TAILSCALE_REF}
Go：${GO_VERSION}
GOARM：${GOARM}
构建类型：${FLAVOR}
实现：GitHub Actions完成核心构建后直接注入完整Softcenter模板并生成可后台上传的tar.gz。
存储策略：JFFS保底运行；ROUTERUSB存在时优先使用USB核心和详细日志；U盘拔出时切回JFFS核心和/tmp轻量状态日志。
EOF
PKG="Headscale_${VERSION_NO_V}-go${GO_VERSION}-armv${GOARM}-${FLAVOR}-dual-v9.tar.gz"
tar -C "$ROOT/package-work" -czf "$OUT/$PKG" tailscale
sha256sum "$OUT/$PKG" > "$OUT/$PKG.sha256"
