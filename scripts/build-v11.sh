#!/usr/bin/env bash
set -euo pipefail
MODE=${1:?all or variant}; ROOT=${2:?root}; SRC=${3:?source}; REF=${4:?ref}; GOV=${5:?go}; GOARMV=${6:?goarm}
export GOOS=linux GOARCH=arm GOARM="$GOARMV" CGO_ENABLED=0 GOTOOLCHAIN=local
DIST="$ROOT/dist"; mkdir -p "$DIST" "$ROOT/diagnostics"
cd "$SRC"
# Build standard pair for variants that require them.
if [ "$MODE" = all ] || [ "$MODE" = usb-hs3 ] || [ "$MODE" = legacy-runtime ]; then
 go build -trimpath -buildvcs=true -ldflags='-s -w' -o "$DIST/tailscale" ./cmd/tailscale
 go build -trimpath -buildvcs=true -ldflags='-s -w' -o "$DIST/tailscaled" ./cmd/tailscaled
fi
# Build combined CLI+daemon for combo variant.
if [ "$MODE" = all ] || [ "$MODE" = combo-core ]; then
 go build -tags=ts_include_cli -trimpath -buildvcs=true -ldflags='-s -w' -o "$DIST/tailscale_combo" ./cmd/tailscale
fi
variants="$MODE"; [ "$MODE" = all ] && variants='usb-hs3 legacy-runtime combo-core'
cd "$ROOT"
for v in $variants; do
 bash "$ROOT/scripts/package-softcenter-v11.sh" "$DIST" "$v" "$GOARMV" "$ROOT" "$REF" "$GOV"
done
