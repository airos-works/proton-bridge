#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${HAIKU_SDK_ENV:?Set HAIKU_SDK_ENV to the air/OS SDK env.sh}"
: "${HAIKU_GUI_DEPS:?Set HAIKU_GUI_DEPS to the dependency prefix (x86_64: extracted HaikuPorts packages; arm64: build-gui-deps.sh)}"
. "$HAIKU_SDK_ENV"
case $AIROS_ARCH in
    x86_64) HAIKU_PROCESSOR=x86_64 ;;
    # build-gui-deps.sh's prefix; HAIKU_GUI_EXTRA: its FreeType and GL tree
    arm64) HAIKU_PROCESSOR=aarch64; : "${HAIKU_GUI_EXTRA:?Set HAIKU_GUI_EXTRA as for build-gui-deps.sh}" ;;
    *) echo "No desktop dependency set for $AIROS_ARCH" >&2; exit 1 ;;
esac
export CROSS SYSROOT UNWIND_SPECS HAIKU_GUI_DEPS HAIKU_PROCESSOR ${HAIKU_GUI_EXTRA:+HAIKU_GUI_EXTRA}
HOST=${BRIDGE_HOST_BUILD:-$ROOT/build-haiku/host-tools}
BUILD=${BRIDGE_GUI_BUILD:-$ROOT/build-haiku/gui}
OUT=${BRIDGE_BUILD_DIR:-$ROOT/build-haiku}
revision=${BRIDGE_REVISION:-$(git -C "$ROOT" describe --always --dirty --match "")}
for tool in "$HOST/qt-host/libexec/moc" "$HOST/qt-host/libexec/rcc" "$HOST/protobuf-host/protoc" "$HOST/grpc_cpp_plugin"; do
    [[ -x $tool ]] || { echo "Missing $tool; run build-host-tools.sh" >&2; exit 1; }
done
# HaikuPorts .pc files contain /packages/.../.self prefixes. Override that
# variable and isolate pkg-config from Linux libraries without editing packages.
export PKG_CONFIG_LIBDIR="$HAIKU_GUI_DEPS/develop/lib/pkgconfig:$HAIKU_GUI_DEPS/lib/pkgconfig"
export PKG_CONFIG_PATH=
cmake -S "$ROOT/internal/frontend/bridge-gui" -B "$BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ROOT/tools/haiku/gui-toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
    -DBRIDGE_USE_SYSTEM_LIBS=ON -DBRIDGE_WITH_SENTRY=OFF \
    -DBRIDGE_BUILD_CPP_TESTS=OFF -DBRIDGE_BUILD_GUI_TESTER=OFF \
    -DBRIDGE_APP_FULL_NAME='Proton Mail Bridge' -DBRIDGE_VENDOR='Proton AG' \
    -DBRIDGE_REVISION="$revision" -DBRIDGE_BUILD_ENV=dev \
    -DQT_HOST_PATH="$HOST/qt-host" -DPROTOC_EXE="$HOST/protobuf-host/protoc" \
    -DProtobuf_PROTOC_EXECUTABLE="$HOST/protobuf-host/protoc" \
    -DGRPC_CPP_PLUGIN="$HOST/grpc_cpp_plugin" \
    -DPKG_CONFIG_ARGN="--define-variable=prefix=$HAIKU_GUI_DEPS" \
    -DQT_ALLOW_MISSING_TOOLS_PACKAGES=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_Qt6QmlTools=TRUE \
    -DCMAKE_DISABLE_FIND_PACKAGE_Qt6QuickTools=TRUE \
    -DCMAKE_DISABLE_FIND_PACKAGE_Qt6ShaderToolsTools=TRUE \
    -DCMAKE_DISABLE_FIND_PACKAGE_Qt6GuiTools=TRUE \
    -DCMAKE_DISABLE_FIND_PACKAGE_Qt6WidgetsTools=TRUE \
    "$@"
# Bridge embeds interpreted QML in Resources.qrc, so only moc and rcc are used.
# Do not import Haiku's optional QML/UI/shader code generators on the Linux host.
cmake --build "$BUILD" --target bridge-gui -j"${JOBS:-8}"
mkdir -p "$OUT"
cp "$BUILD/bridge-gui/Proton Mail Bridge" "$OUT/Proton Mail Bridge"
