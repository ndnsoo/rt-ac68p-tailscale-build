#!/usr/bin/env bash
set -euo pipefail
DIST=${1:?dist required}
VARIANT=${2:?variant required}
GOARM=${3:?goarm required}
ROOT=${4:?root required}
REF=${5:?ref required}
GOV=${6:?go required}
VER=${REF#v}
WORK="$ROOT/work-$VARIANT/tailscale"
OUT="$ROOT/out-softcenter"
rm -rf "$ROOT/work-$VARIANT"
mkdir -p "$WORK/bin" "$OUT"
cp -a "$ROOT/plugin-template/tailscale/." "$WORK/"
case "$VARIANT" in
  usb-upstream|usb-legacy|usb-combo) : > "$WORK/bin/.usb_only" ;;
  dual-upstream|dual-legacy|dual-combo) : ;;
  *) echo "未知方案：$VARIANT" >&2; exit 2 ;;
esac
case "$VARIANT" in
  usb-combo|dual-combo)
    cp "$DIST/tailscale_combo" "$WORK/bin/tailscale_combo"
    : > "$WORK/bin/.combo"
    ;;
  *)
    cp "$DIST/tailscale" "$WORK/bin/tailscale"
    cp "$DIST/tailscaled" "$WORK/bin/tailscaled"
    ;;
esac
case "$VARIANT" in
  usb-legacy|dual-legacy)
    cp -a "$ROOT/plugin-overlays/legacy/." "$WORK/"
    python3 - "$WORK" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1])
p=r/'scripts/tailscale_config.sh'
s=p.read_text()
s=s.replace('args=" --login-server=', 'args=" --netfilter-mode=off --login-server=', 1)
needle='\t\t/jffs/softcenter/bin/tailscale up --accept-dns=false ${args} &\n'
if needle not in s: raise SystemExit('tailscale up insertion point missing')
s=s.replace(needle, needle+'\t\tsleep 3\n\t\t/jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1\n', 1)
p.write_text(s)
PY
    ;;
esac
chmod 755 "$WORK/install.sh" "$WORK/uninstall.sh" "$WORK/scripts"/*.sh "$WORK/bin"/*
printf '%s\n' "0.5.0-${REF}-go${GOV}-armv${GOARM}-${VARIANT}-v12" > "$WORK/version"
(
 cd "$WORK"
 if [ -f bin/.combo ]; then sha256sum bin/tailscale_combo > CORE-SHA256SUMS; else sha256sum bin/tailscale bin/tailscaled > CORE-SHA256SUMS; fi
)
cat > "$WORK/工作流.txt" <<EOF
v12; Tailscale=${REF}; Go=${GOV}; GOARM=${GOARM}; variant=${VARIANT}
EOF
PKG="Headscale_${VER}-go${GOV}-armv${GOARM}-${VARIANT}-v12.tar.gz"
tar -C "$ROOT/work-$VARIANT" -czf "$OUT/$PKG" tailscale
sha256sum "$OUT/$PKG" > "$OUT/$PKG.sha256"
