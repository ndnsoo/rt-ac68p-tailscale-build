#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${1:?dist directory required}"
SOURCE_DIR="${2:?source directory required}"
TAILSCALE_REF="${3:?tailscale ref required}"
GO_VERSION_REQUESTED="${4:?Go version required}"
OUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/out"
mkdir -p "$OUT_DIR"

for name in tailscale tailscaled; do
  test -s "$DIST_DIR/$name"
  chmod 0755 "$DIST_DIR/$name"
  file "$DIST_DIR/$name" | tee "$OUT_DIR/${name}.file.txt"
  file "$DIST_DIR/$name" | grep -qi 'ELF 32-bit'
  file "$DIST_DIR/$name" | grep -qi 'ARM'
  if readelf -l "$DIST_DIR/$name" | grep -q 'Requesting program interpreter'; then
    echo "ERROR: $name is dynamically linked." >&2
    exit 1
  fi
  go version -m "$DIST_DIR/$name" > "$OUT_DIR/${name}.gomod.txt"
done

COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
SOURCE_GO="$(awk '$1=="go" {print $2; exit}' "$SOURCE_DIR/go.mod")"
BUILT_GO="$(go env GOVERSION)"
PACKAGE_BASE="tailscale-${TAILSCALE_REF#v}-go${GO_VERSION_REQUESTED}-linux-armv7-rt-ac68p"
STAGE="$OUT_DIR/$PACKAGE_BASE"
mkdir -p "$STAGE"
cp "$DIST_DIR/tailscale" "$DIST_DIR/tailscaled" "$STAGE/"

cat > "$OUT_DIR/build-info.txt" <<EOF
Build target: ASUS RT-AC68P / Merlin / Linux 2.6.36 / ARMv7
Tailscale ref: $TAILSCALE_REF
Tailscale commit: $COMMIT
Source go.mod: $SOURCE_GO
Requested Go: $GO_VERSION_REQUESTED
Actual Go: $BUILT_GO
GOOS: linux
GOARCH: arm
GOARM: 7
CGO_ENABLED: 0
GOTOOLCHAIN: local
GitHub repository: ${GITHUB_REPOSITORY:-local}
GitHub run ID: ${GITHUB_RUN_ID:-local}
GitHub run number: ${GITHUB_RUN_NUMBER:-local}
Built at UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

Important:
- This is an unofficial custom build.
- It is intended to test compatibility with Linux 2.6.36.
- Back up the existing tailscale and tailscaled binaries before replacing them.
- Do not overwrite the existing tailscaled.state file.
EOF
cp "$OUT_DIR/build-info.txt" "$STAGE/"
cp "$OUT_DIR"/*.file.txt "$OUT_DIR"/*.gomod.txt "$STAGE/"
(
  cd "$STAGE"
  sha256sum tailscale tailscaled > SHA256SUMS
)

tar -C "$OUT_DIR" -czf "$OUT_DIR/$PACKAGE_BASE.tar.gz" "$PACKAGE_BASE"
sha256sum "$OUT_DIR/$PACKAGE_BASE.tar.gz" > "$OUT_DIR/$PACKAGE_BASE.tar.gz.sha256"
rm -rf "$STAGE"

cat "$OUT_DIR/build-info.txt"
cat "$OUT_DIR/$PACKAGE_BASE.tar.gz.sha256"
