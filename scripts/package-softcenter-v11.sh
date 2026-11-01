#!/usr/bin/env bash
set -euo pipefail
DIST=$1 VARIANT=$2 GOARM=$3 ROOT=$4 TAILSCALE_REF=$5 GO_VERSION=$6
VER=${TAILSCALE_REF#v}; WORK="$ROOT/work-$VARIANT/tailscale"; OUT="$ROOT/out-softcenter"
rm -rf "$ROOT/work-$VARIANT"; mkdir -p "$WORK/bin" "$OUT"; cp -a "$ROOT/plugin-template/tailscale/." "$WORK/"
legacy(){
 cp -a "$ROOT/plugin-overlays/legacy-runtime/." "$WORK/"
 python3 - "$WORK" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); p=r/'scripts/tailscale_config.sh'; s=p.read_text()
s=s.replace('args=" --login-server=','args=" --netfilter-mode=off --login-server=',1)
n='\t\t/jffs/softcenter/bin/tailscale up --accept-dns=false ${args} &\n'
if n not in s: raise SystemExit('up point missing')
s=s.replace(n,n+'\t\tsleep 3\n\t\t/jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1\n',1); p.write_text(s)
w=r/'scripts/tailscale_watchdog.sh'; t=w.read_text(); m='if pidof tailscaled >/dev/null 2>&1; then '
if m in t: t=t.replace(m,m+'/jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1; ',1)
w.write_text(t)
PY
}
case "$VARIANT" in
 usb-hs3) cp "$DIST/tailscale" "$WORK/bin/"; cp "$DIST/tailscaled" "$WORK/bin/"; : > "$WORK/bin/.usb_only" ;;
 legacy-runtime) legacy; cp "$DIST/tailscale" "$WORK/bin/"; cp "$DIST/tailscaled" "$WORK/bin/" ;;
 combo-core) cp "$DIST/tailscale_combo" "$WORK/bin/"; : > "$WORK/bin/.combo" ;;
 *) exit 2 ;;
esac
chmod 755 "$WORK/install.sh" "$WORK/uninstall.sh" "$WORK/scripts"/*.sh "$WORK/bin"/*
printf '%s\n' "0.4.0-${TAILSCALE_REF}-go${GO_VERSION}-armv${GOARM}-${VARIANT}-v11" > "$WORK/version"
(cd "$WORK"; if [ "$VARIANT" = combo-core ]; then sha256sum bin/tailscale_combo; else sha256sum bin/tailscale bin/tailscaled; fi > CORE-SHA256SUMS)
cat > "$WORK/工作流.txt" <<EOF
v11; Tailscale=${TAILSCALE_REF}; Go=${GO_VERSION}; GOARM=${GOARM}; variant=${VARIANT}; JFFS minimum=31000KB.
EOF
if [ "$VARIANT" = "usb-hs3" ]; then
  PKG="Headscale_${VER}-go${GO_VERSION}-armv${GOARM}-usb-hs3-v11.tar.gz"
else
  PKG="Headscale_${VER}-go${GO_VERSION}-armv${GOARM}-${VARIANT}-dual-v11.tar.gz"
fi
tar -C "$ROOT/work-$VARIANT" -czf "$OUT/$PKG" tailscale
sha256sum "$OUT/$PKG" > "$OUT/$PKG.sha256"
