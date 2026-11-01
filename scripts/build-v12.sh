#!/usr/bin/env bash
set -euo pipefail
MODE=${1:?mode required}
ROOT=${2:?root required}
SRC=${3:?source required}
REF=${4:?ref required}
GOV=${5:?go required}
GOARMV=${6:?goarm required}
export GOOS=linux GOARCH=arm GOARM="$GOARMV" CGO_ENABLED=0 GOTOOLCHAIN=local
DIST="$ROOT/dist"
mkdir -p "$DIST"
PAIR=0; COMBO=0
case "$MODE" in
 all) PAIR=1; COMBO=1 ;;
 usb-upstream|usb-legacy|dual-upstream|dual-legacy) PAIR=1 ;;
 usb-combo|dual-combo) COMBO=1 ;;
 *) echo "未知模式：$MODE" >&2; exit 2 ;;
esac
cd "$SRC"
if [ "$PAIR" -eq 1 ]; then
 go build -trimpath -buildvcs=true -ldflags='-s -w' -o "$DIST/tailscale" ./cmd/tailscale
 go build -trimpath -buildvcs=true -ldflags='-s -w' -o "$DIST/tailscaled" ./cmd/tailscaled
fi
if [ "$COMBO" -eq 1 ]; then
 go build -tags=ts_include_cli -trimpath -buildvcs=true -ldflags='-s -w' -o "$DIST/tailscale_combo" ./cmd/tailscale
fi
VARIANTS="$MODE"
[ "$MODE" = all ] && VARIANTS='usb-upstream usb-legacy usb-combo dual-upstream dual-legacy dual-combo'
for V in $VARIANTS; do
 bash "$ROOT/scripts/package-softcenter-v12.sh" "$DIST" "$V" "$GOARMV" "$ROOT" "$REF" "$GOV"
done
