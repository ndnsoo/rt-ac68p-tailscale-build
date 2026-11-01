#!/usr/bin/env bash
set -euo pipefail

MODE=${1:?build mode required}
ROOT=${2:?repository root required}
SOURCE_DIR=${3:?Tailscale source directory required}
TAILSCALE_REF=${4:?Tailscale ref required}
GO_VERSION=${5:?Go version required}
GOARM_VALUE=${6:?GOARM value required}

export GOOS=linux
export GOARCH=arm
export GOARM="$GOARM_VALUE"
export CGO_ENABLED=0
export GOTOOLCHAIN=local

DIST_DIR="$ROOT/dist"
mkdir -p "$DIST_DIR"

BUILD_PAIR=0
BUILD_COMBO=0

case "$MODE" in
    all)
        BUILD_PAIR=1
        BUILD_COMBO=1
        ;;
    usb-upstream|usb-legacy|dual-upstream|dual-legacy)
        BUILD_PAIR=1
        ;;
    usb-combo|dual-combo)
        BUILD_COMBO=1
        ;;
    *)
        echo "ERROR: unknown build mode: $MODE" >&2
        exit 2
        ;;
esac

cd "$SOURCE_DIR"

if [ "$BUILD_PAIR" -eq 1 ]; then
    go build \
        -trimpath \
        -buildvcs=true \
        -ldflags='-s -w' \
        -o "$DIST_DIR/tailscale" \
        ./cmd/tailscale

    go build \
        -trimpath \
        -buildvcs=true \
        -ldflags='-s -w' \
        -o "$DIST_DIR/tailscaled" \
        ./cmd/tailscaled
fi

if [ "$BUILD_COMBO" -eq 1 ]; then
    go build \
        -tags=ts_include_cli \
        -trimpath \
        -buildvcs=true \
        -ldflags='-s -w' \
        -o "$DIST_DIR/tailscale_combo" \
        ./cmd/tailscale
fi

VARIANTS="$MODE"
if [ "$MODE" = "all" ]; then
    VARIANTS="usb-upstream usb-legacy usb-combo dual-upstream dual-legacy dual-combo"
fi

for VARIANT in $VARIANTS; do
    bash "$ROOT/scripts/package-softcenter-v12.sh" \
        "$DIST_DIR" \
        "$VARIANT" \
        "$GOARM_VALUE" \
        "$ROOT" \
        "$TAILSCALE_REF" \
        "$GO_VERSION"
done
