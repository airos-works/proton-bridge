# Source from bash before cross-compiling the air/OS port.
BRIDGE_WORK=${BRIDGE_WORK:-/mnt/HaikuWork}
export GOROOT=${GOROOT:-$BRIDGE_WORK/toolchains/go-haiku}
export GOPATH=${GOPATH:-$BRIDGE_WORK/cache/proton-bridge/gopath}
export GOCACHE=${GOCACHE:-$BRIDGE_WORK/cache/proton-bridge/go-build}
export TMPDIR=${TMPDIR:-$BRIDGE_WORK/tmp/proton-bridge}
export GOTOOLCHAIN=local
export GOOS=haiku GOARCH=${GOARCH:-amd64} CGO_ENABLED=1
export HAIKU_SYSROOT=${HAIKU_SYSROOT:-$BRIDGE_WORK/toolchains/haiku-sysroot-x86_64}
export HAIKU_CROSS=${HAIKU_CROSS:-$BRIDGE_WORK/x399/build/x86_64/cross-tools-x86_64/bin/x86_64-unknown-haiku}
BRIDGE_HAIKU_TOOLS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export CC="$BRIDGE_HAIKU_TOOLS/cc" CXX="$BRIDGE_HAIKU_TOOLS/c++"
export PATH="$GOROOT/bin:$PATH"
mkdir -p "$TMPDIR" "$GOCACHE" "$GOPATH"
