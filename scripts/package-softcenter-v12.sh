#!/usr/bin/env bash
set -euo pipefail

DIST_DIR=${1:?distribution directory required}
VARIANT=${2:?variant required}
GOARM_VALUE=${3:?GOARM value required}
ROOT=${4:?repository root required}
TAILSCALE_REF=${5:?Tailscale ref required}
GO_VERSION=${6:?Go version required}

VERSION_NO_V=${TAILSCALE_REF#v}
WORK_DIR="$ROOT/work-$VARIANT/tailscale"
OUTPUT_DIR="$ROOT/out-softcenter"

rm -rf "$ROOT/work-$VARIANT"
mkdir -p "$WORK_DIR/bin" "$OUTPUT_DIR"
cp -a "$ROOT/plugin-template/tailscale/." "$WORK_DIR/"

case "$VARIANT" in
    usb-upstream|usb-legacy|usb-combo)
        : > "$WORK_DIR/bin/.usb_only"
        ;;
    dual-upstream|dual-legacy|dual-combo)
        ;;
    *)
        echo "ERROR: unknown package variant: $VARIANT" >&2
        exit 2
        ;;
esac

case "$VARIANT" in
    usb-combo|dual-combo)
        cp "$DIST_DIR/tailscale_combo" "$WORK_DIR/bin/tailscale_combo"
        : > "$WORK_DIR/bin/.combo"
        ;;
    *)
        cp "$DIST_DIR/tailscale" "$WORK_DIR/bin/tailscale"
        cp "$DIST_DIR/tailscaled" "$WORK_DIR/bin/tailscaled"
        ;;
esac

case "$VARIANT" in
    usb-legacy|dual-legacy)
        cp -a "$ROOT/plugin-overlays/legacy/." "$WORK_DIR/"
        python3 - "$WORK_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
config = root / "scripts" / "tailscale_config.sh"
text = config.read_text()
text = text.replace(
    'args=" --login-server=',
    'args=" --netfilter-mode=off --login-server=',
    1,
)
needle = '\t\t/jffs/softcenter/bin/tailscale up --accept-dns=false ${args} &\n'
if needle not in text:
    raise SystemExit("tailscale up insertion point missing")
text = text.replace(
    needle,
    needle
    + '\t\tsleep 3\n'
    + '\t\t/jffs/softcenter/scripts/tailscale_legacy_firewall.sh start >/dev/null 2>&1\n',
    1,
)
config.write_text(text)
PY
        ;;
esac

chmod 755 "$WORK_DIR/install.sh"
chmod 755 "$WORK_DIR/uninstall.sh"
chmod 755 "$WORK_DIR/scripts"/*.sh
chmod 755 "$WORK_DIR/bin"/*

printf '%s\n' \
    "0.5.3-${TAILSCALE_REF}-go${GO_VERSION}-armv${GOARM_VALUE}-${VARIANT}-v12r3" \
    > "$WORK_DIR/version"

(
    cd "$WORK_DIR"
    if [ -f bin/.combo ]; then
        sha256sum bin/tailscale_combo > CORE-SHA256SUMS
    else
        sha256sum bin/tailscale bin/tailscaled > CORE-SHA256SUMS
    fi
)

cat > "$WORK_DIR/工作流.txt" <<EOF
v12r3
Tailscale=${TAILSCALE_REF}
Go=${GO_VERSION}
GOARM=${GOARM_VALUE}
variant=${VARIANT}
EOF

PACKAGE_NAME="Headscale_${VERSION_NO_V}-go${GO_VERSION}-armv${GOARM_VALUE}-${VARIANT}-v12r3.tar.gz"
tar -C "$ROOT/work-$VARIANT" -czf "$OUTPUT_DIR/$PACKAGE_NAME" tailscale
sha256sum "$OUTPUT_DIR/$PACKAGE_NAME" > "$OUTPUT_DIR/$PACKAGE_NAME.sha256"
