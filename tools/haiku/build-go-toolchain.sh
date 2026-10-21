#!/usr/bin/env bash
# Bootstrap the pinned Haiku-capable Go compiler on Linux x86_64.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOST=${BRIDGE_HOST_BUILD:-$ROOT/build-haiku/host-tools}
CACHE=${BRIDGE_DOWNLOAD_CACHE:-$ROOT/build-haiku/downloads}
TARGET=${BRIDGE_GO_ROOT:-$HOST/go-haiku}
PIN=3f5f9a2ae5292a2522e4a99ae0b837fc3eae6a13
BOOTSTRAP=go1.27.3.linux-amd64.tar.gz
[[ $(uname -sm) == 'Linux x86_64' ]] || { echo 'Bootstrap currently supports Linux x86_64' >&2; exit 1; }
mkdir -p "$HOST" "$CACHE"
exec 9>"$HOST/go-toolchain.lock"
flock 9
if [[ ! -d $TARGET/.git ]]; then
    git init "$TARGET"
    git -C "$TARGET" remote add origin https://github.com/gen2brain/go.git
fi
if [[ -f $TARGET/.bridge-pin && $(cat "$TARGET/.bridge-pin") == "$PIN" && -x $TARGET/bin/go ]]; then
    exit 0
fi
[[ -z $(git -C "$TARGET" status --porcelain --untracked-files=no) ]] || { echo 'Go source checkout has modifications' >&2; exit 1; }
git -C "$TARGET" cat-file -e "$PIN^{commit}" 2>/dev/null || git -C "$TARGET" fetch --depth 1 origin "$PIN"
git -C "$TARGET" checkout --detach "$PIN"
if [[ ! -f $CACHE/$BOOTSTRAP ]]; then
    curl -fL --retry 3 "https://go.dev/dl/$BOOTSTRAP" -o "$CACHE/$BOOTSTRAP.tmp"
    mv "$CACHE/$BOOTSTRAP.tmp" "$CACHE/$BOOTSTRAP"
fi
printf '65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40  %s\n' "$CACHE/$BOOTSTRAP" | sha256sum -c -
mkdir -p "$HOST/go-bootstrap"
tar -xf "$CACHE/$BOOTSTRAP" -C "$HOST/go-bootstrap"
(
    cd "$TARGET/src"
    unset GOROOT GOFLAGS CC CXX
    GOROOT_BOOTSTRAP="$HOST/go-bootstrap/go" GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
        GOTOOLCHAIN=local GOMAXPROCS="${JOBS:-8}" ./make.bash
)
"$TARGET/bin/go" tool dist list | grep -qx haiku/amd64
printf '%s\n' "$PIN" > "$TARGET/.bridge-pin"
