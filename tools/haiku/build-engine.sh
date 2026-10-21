#!/usr/bin/env bash
# Source env.sh first, or provide native Haiku Go/CC/CXX in the environment.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
[[ $(go env GOOS) == haiku ]] || { echo 'Use a Haiku-capable Go toolchain and GOOS=haiku' >&2; exit 1; }
OUT=${BRIDGE_BUILD_DIR:-$ROOT/build-haiku}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
go mod vendor
python3 tools/haiku/prepare-vendor.py
make gofiles
version=${BRIDGE_APP_VERSION:-$(utils/bridge_app_version.sh)}
revision=$(git describe --always --dirty --match "")
prefix=github.com/ProtonMail/proton-bridge/v3/internal/constants
ldflags="-X $prefix.Version=$version -X $prefix.Revision=$revision -X $prefix.BuildEnv=dev -X '$prefix.FullAppName=Proton Mail Bridge'"
go build -trimpath -ldflags "$ldflags" -o "$OUT/bridge" ./cmd/Desktop-Bridge
"${CXX:-g++}" -std=c++17 -Wall -Wextra -Werror dist/haiku/autostart.cpp -lbe -o "$OUT/bridge-autostart"
printf 'Built %s and %s\n' "$OUT/bridge" "$OUT/bridge-autostart"
