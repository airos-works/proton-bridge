#!/usr/bin/env bash
# Cross-build the desktop interface's dependency set for an air/OS
# architecture that HaikuPorts does not provide it for (arm64): Qt 6.10.3
# (qtbase, qtdeclarative, qtsvg with HaikuPorts' patches, and the Haiku
# platform plugin; qtshadertools for the host only), and protobuf 3.20.1, abseil 20230125.3, re2
# 2022-06-01, c-ares 1.34.8 and gRPC 1.53.0, the versions HaikuPorts builds for
# x86_64, with the same patches.
#
# Qt is shared and relocatable: the package carries it privately beside the
# interface (lib/, plugins/, qml/). gRPC and what it needs are static
# libraries linked into the interface, with OpenSSL from HAIKU_EXTRA_DEPS.
#
# Environment:
#   HAIKU_SDK_ENV         the air/OS SDK env.sh of the target architecture
#   HAIKU_GUI_DEPS        the prefix to create (Qt's and the libraries' install
#                         prefix; what build-gui.sh then links)
#   HAIKU_EXTRA_DEPS      a boot/system tree with FreeType, libpng, OpenSSL
#                         (static) and the GL stack (libglvnd, GLU) for ARCH
#   HAIKU_QT_PLUGINS_SRC  a qt6-haikuplugins checkout (the platform plugin)
#   BRIDGE_HOST_BUILD     host tools (a full host Qt of the same version)
#   BRIDGE_DOWNLOAD_CACHE source tarballs
#   JOBS                  parallel jobs
# A stage is rebuilt only when its stamp changes (the patches, the stamp's
# revision, the platform plugin's commit); OpenSSL is refreshed on every run.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${HAIKU_SDK_ENV:?Set HAIKU_SDK_ENV to the air/OS SDK env.sh}"
: "${HAIKU_GUI_DEPS:?Set HAIKU_GUI_DEPS to the prefix to build}"
: "${HAIKU_EXTRA_DEPS:?Set HAIKU_EXTRA_DEPS to the boot/system tree with FreeType, OpenSSL and GL}"
: "${HAIKU_QT_PLUGINS_SRC:?Set HAIKU_QT_PLUGINS_SRC to a qt6-haikuplugins checkout}"
. "$HAIKU_SDK_ENV"
HOST=${BRIDGE_HOST_BUILD:-$ROOT/build-haiku/host-tools}
CACHE=${BRIDGE_DOWNLOAD_CACHE:-$ROOT/build-haiku/downloads}
JOBS=${JOBS:-8}
PREFIX=$HAIKU_GUI_DEPS
EXTRA=$HAIKU_EXTRA_DEPS
QT_VERSION=6.10.3
case $AIROS_ARCH in
    arm64) PROCESSOR=aarch64 ;;
    x86_64) PROCESSOR=x86_64 ;;
    *) echo "unknown architecture $AIROS_ARCH" >&2; exit 1 ;;
esac
WORK=${HAIKU_GUI_DEPS_WORK:-$PREFIX.work}
HOSTQT=$HOST/qt-$QT_VERSION
PATCHES=$ROOT/tools/haiku/patches
mkdir -p "$CACHE" "$WORK" "$HOST"

step() { printf '\n== %s\n' "$*"; }
fetch() { # fetch FILE URL SHA256
    if [[ ! -f $CACHE/$1 ]]; then
        curl -fL --retry 3 "$2" -o "$CACHE/$1.tmp"
        mv "$CACHE/$1.tmp" "$CACHE/$1"
    fi
    printf '%s  %s\n' "$3" "$CACHE/$1" | sha256sum -c --quiet -
}
unpack() { # unpack FILE DIR [PATCH...]: DIR becomes a fresh patched tree
    rm -rf "$2"
    mkdir -p "$2"
    tar -xf "$CACHE/$1" -C "$2" --strip-components=1
    local patch
    for patch in "${@:3}"; do
        patch -d "$2" -p1 -s < "$patch"
    done
}
is_current() { [[ -f $WORK/$1.stamp && $(cat "$WORK/$1.stamp") == "$2" ]]; }

Q=https://download.qt.io/archive/qt/6.10/$QT_VERSION/submodules
fetch qtbase-$QT_VERSION.tar.xz $Q/qtbase-everywhere-src-$QT_VERSION.tar.xz 383dc907816338f0cba72088a524c07458dfc69ce684ca9132fcc4fe91c24b0b
fetch qtshadertools-$QT_VERSION.tar.xz $Q/qtshadertools-everywhere-src-$QT_VERSION.tar.xz c75837e2ea493ec0b9747b227c455d4a12cafe90068abf607992da9a403616c6
fetch qtdeclarative-$QT_VERSION.tar.xz $Q/qtdeclarative-everywhere-src-$QT_VERSION.tar.xz dadf80d43b8e08ca63aa65d46859a42b920a7777cf7e0ecfcb4c4537f9e65c76
fetch qtsvg-$QT_VERSION.tar.xz $Q/qtsvg-everywhere-src-$QT_VERSION.tar.xz b3223fe005f6a4c7f21f34e4ee6ce0094737cff9503ba15bbb171ac18794f76d
fetch protobuf-3.20.1.tar.gz https://github.com/protocolbuffers/protobuf/archive/refs/tags/v3.20.1.tar.gz 8b28fdd45bab62d15db232ec404248901842e5340299a57765e48abe8a80d930
fetch abseil-cpp-20230125.3.tar.gz https://github.com/abseil/abseil-cpp/archive/20230125.3/abseil-20230125.3.tar.gz 5366d7e7fa7ba0d915014d387b66d0d002c03236448e1ba9ef98122c13b35c36
fetch re2-2022-06-01.tar.gz https://github.com/google/re2/archive/2022-06-01.tar.gz f89c61410a072e5cbcf8c27e3a778da7d6fd2f2b5b1445cd4f4508bee946ab0f
fetch c-ares-1.34.8.tar.gz https://github.com/c-ares/c-ares/releases/download/v1.34.8/c-ares-1.34.8.tar.gz c222b6d681096f9444d2c4863d2c1174019e27cacca0a4a5c114d36dd7d7bf78
fetch grpc-1.53.0.tar.gz https://github.com/grpc/grpc/archive/refs/tags/v1.53.0.tar.gz 9717ffc52120861136e478155c2ff3a9c21740e2244de52fa966f376d7471adf

# --- the host Qt -------------------------------------------------------------
# Cross builds of qtdeclarative and qtsvg run the host's moc, rcc, qsb,
# qmltyperegistrar, qmlcachegen and qmlimportscanner of the same version.
# The host stamp names what the host build is made of (raise its revision when
# the commands below change).
host_stamp="qtbase qtshadertools qtdeclarative $QT_VERSION host-1"
if [[ ! -f $HOSTQT/.stamp || $(cat "$HOSTQT/.stamp") != "$host_stamp" ]]; then
    step "host Qt $QT_VERSION"
    rm -rf "$HOSTQT" "$WORK/host"
    unpack qtbase-$QT_VERSION.tar.xz "$WORK/host/qtbase"
    cmake -S "$WORK/host/qtbase" -B "$WORK/host/qtbase-build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOSTQT" -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
        -DINPUT_opengl=no -DFEATURE_vulkan=OFF -DFEATURE_xcb=OFF -DFEATURE_wayland=OFF \
        -DFEATURE_dbus=OFF -DFEATURE_glib=OFF -DFEATURE_sql=OFF -DFEATURE_printsupport=OFF \
        -DFEATURE_icu=OFF -DFEATURE_zstd=OFF -DFEATURE_openssl=OFF -DFEATURE_fontconfig=OFF \
        -DFEATURE_libudev=OFF > "$WORK/host-qtbase.log"
    cmake --build "$WORK/host/qtbase-build" -j"$JOBS" >> "$WORK/host-qtbase.log"
    cmake --install "$WORK/host/qtbase-build" >> "$WORK/host-qtbase.log"
    for module in qtshadertools qtdeclarative; do
        unpack $module-$QT_VERSION.tar.xz "$WORK/host/$module"
        "$HOSTQT/bin/qt-cmake" -S "$WORK/host/$module" -B "$WORK/host/$module-build" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
            > "$WORK/host-$module.log"
        cmake --build "$WORK/host/$module-build" -j"$JOBS" >> "$WORK/host-$module.log"
        cmake --install "$WORK/host/$module-build" >> "$WORK/host-$module.log"
    done
    rm -rf "$WORK/host"
    echo "$host_stamp" > "$HOSTQT/.stamp"
fi

# --- the cross toolchain -----------------------------------------------------
# Search order: this prefix, the extra tree (FreeType 2.14, libpng, OpenSSL,
# GL: what the images have), then the SDK's sysroot.
EXTRA_ROOT=${EXTRA%/boot/system}
TOOLCHAIN=$WORK/toolchain.cmake
cat > "$TOOLCHAIN" <<EOF
set(CMAKE_SYSTEM_NAME Haiku)
set(CMAKE_SYSTEM_PROCESSOR $PROCESSOR)
set(CMAKE_SYSROOT $SYSROOT)
set(CMAKE_C_COMPILER ${CROSS}gcc)
set(CMAKE_CXX_COMPILER ${CROSS}g++)
set(CMAKE_AR ${CROSS}ar CACHE FILEPATH "")
set(CMAKE_RANLIB ${CROSS}ranlib CACHE FILEPATH "")
set(CMAKE_STRIP ${CROSS}strip CACHE FILEPATH "")
set(CMAKE_C_FLAGS_INIT "-fPIC -D_DEFAULT_SOURCE -D_GNU_SOURCE")
set(CMAKE_CXX_FLAGS_INIT "-fPIC -D_DEFAULT_SOURCE -D_GNU_SOURCE")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-specs=$UNWIND_SPECS -L$EXTRA/develop/lib -Wl,-rpath-link,$EXTRA/lib -Wl,-rpath-link,$PREFIX/lib")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-specs=$UNWIND_SPECS -L$EXTRA/develop/lib -Wl,-rpath-link,$EXTRA/lib -Wl,-rpath-link,$PREFIX/lib")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-specs=$UNWIND_SPECS -L$EXTRA/develop/lib -Wl,-rpath-link,$EXTRA/lib -Wl,-rpath-link,$PREFIX/lib")
set(CMAKE_FIND_ROOT_PATH $PREFIX $EXTRA_ROOT $SYSROOT)
set(CMAKE_PREFIX_PATH $PREFIX)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(ENV{PKG_CONFIG_LIBDIR} "$PREFIX/lib/pkgconfig:$EXTRA/develop/lib/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "$EXTRA_ROOT")
EOF
# cm NAME SOURCE [ARGS...]: configure, build and install a CMake project
cm() {
    local name=$1 src=$2
    shift 2
    cmake --fresh -S "$src" -B "$WORK/$name-build" -G Ninja -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib \
        "$@" > "$WORK/$name.log"
    cmake --build "$WORK/$name-build" -j"$JOBS" >> "$WORK/$name.log"
    cmake --install "$WORK/$name-build" >> "$WORK/$name.log"
}
# built NAME: record that NAME is current (a rebuild of one rebuilds what
# follows). The stamp is the patches and this revision: raise it when the build
# commands change.
CHAIN="deps-1 $(cat "$PATCHES"/*.patchset | sha256sum | cut -c1-16) $AIROS_ARCH"
built() { echo "$CHAIN" > "$WORK/$1.stamp"; }
current() { is_current "$1" "$CHAIN"; }
mkdir -p "$PREFIX/lib" "$PREFIX/include"

# --- gRPC and what it needs: static ------------------------------------------
# (CMAKE_POSITION_INDEPENDENT_CODE off: its -fPIE would follow the toolchain's
# -fPIC, and Haiku links executables as shared objects)
STATIC=(-DBUILD_SHARED_LIBS=OFF -DCMAKE_CXX_STANDARD=17)
# OpenSSL from the extra tree, refreshed on every run: the interface links it
# (gRPC's static libraries only refer to it)
rm -rf "$PREFIX/include/openssl"
cp -R "$EXTRA/develop/headers/openssl" "$PREFIX/include/"
cp "$EXTRA/develop/lib/libssl.a" "$EXTRA/develop/lib/libcrypto.a" "$PREFIX/lib/"
if ! current grpc; then
    step "abseil 20230125.3"
    unpack abseil-cpp-20230125.3.tar.gz "$WORK/abseil" "$PATCHES/abseil_cpp-20230125.3.patchset"
    cm abseil "$WORK/abseil" "${STATIC[@]}" -DABSL_PROPAGATE_CXX_STD=ON -DABSL_BUILD_TESTING=OFF
    step "c-ares 1.34.8"
    unpack c-ares-1.34.8.tar.gz "$WORK/c-ares"
    cm c-ares "$WORK/c-ares" -DCARES_STATIC=ON -DCARES_SHARED=OFF -DCARES_STATIC_PIC=ON \
        -DCARES_BUILD_TESTS=OFF -DCARES_BUILD_TOOLS=OFF
    step "re2 2022-06-01"
    unpack re2-2022-06-01.tar.gz "$WORK/re2"
    cm re2 "$WORK/re2" "${STATIC[@]}" -DRE2_BUILD_TESTING=OFF
    step "protobuf 3.20.1"
    unpack protobuf-3.20.1.tar.gz "$WORK/protobuf"
    cm protobuf "$WORK/protobuf/cmake" "${STATIC[@]}" -Dprotobuf_BUILD_TESTS=OFF \
        -Dprotobuf_WITH_ZLIB=ON
    step "gRPC 1.53.0"
    unpack grpc-1.53.0.tar.gz "$WORK/grpc" "$PATCHES/grpc-1.53.0.patchset"
    # gRPC's plugin targets exist with or without code generation: like
    # HaikuPorts, build the C++ one (the interface's build uses the host's)
    cm grpc "$WORK/grpc" "${STATIC[@]}" -DCMAKE_POSITION_INDEPENDENT_CODE=OFF -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF \
        -DgRPC_BUILD_CODEGEN=ON -DgRPC_BUILD_GRPC_CPP_PLUGIN=ON -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF -DgRPC_ABSL_PROVIDER=package -DgRPC_CARES_PROVIDER=package \
        -DgRPC_PROTOBUF_PROVIDER=package -DgRPC_PROTOBUF_PACKAGE_TYPE=MODULE \
        -DProtobuf_PROTOC_EXECUTABLE="$HOST/protobuf-host/protoc" \
        -D_gRPC_PROTOBUF_PROTOC_EXECUTABLE="$HOST/protobuf-host/protoc" -D_gRPC_CPP_PLUGIN="$HOST/grpc_cpp_plugin" \
        -DgRPC_RE2_PROVIDER=package -DgRPC_SSL_PROVIDER=package -DgRPC_ZLIB_PROVIDER=package \
        -DOPENSSL_ROOT_DIR="$PREFIX" -DOPENSSL_USE_STATIC_LIBS=TRUE -DgRPC_USE_PROTO_LITE=OFF
    rm -rf "$WORK"/{abseil,c-ares,re2,protobuf,grpc}{,-build}
    built grpc
fi

# --- Qt ----------------------------------------------------------------------
QT=(-DQT_HOST_PATH="$HOSTQT" -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DBUILD_WITH_PCH=OFF)
if ! current qtbase || [[ ! -f $PREFIX/lib/libQt6Core.so ]]; then
    step "qtbase $QT_VERSION"
    unpack qtbase-$QT_VERSION.tar.xz "$WORK/qtbase" "$PATCHES/qt6_base-$QT_VERSION.patchset"
    # Desktop GL from the extra tree's libglvnd (the platform plugin draws
    # with BGLView); TLS loads the image's OpenSSL at run time; the
    # images' FreeType, libpng and the base ICU and zlib; the rest bundled.
    cm qtbase "$WORK/qtbase" "${QT[@]}" -DQT_QMAKE_TARGET_MKSPEC=haiku-g++ \
        -DCMAKE_SHARED_LINKER_FLAGS=-lbsd -DFEATURE_rpath=OFF \
        -DINPUT_opengl=desktop -DOpenGL_GL_PREFERENCE=LEGACY \
        -DOPENGL_INCLUDE_DIR="$EXTRA/develop/headers/os/opengl" \
        -DOPENGL_gl_LIBRARY="$EXTRA/lib/libGL.so" \
        -DFEATURE_egl=OFF -DFEATURE_vulkan=OFF -DFEATURE_glib=OFF -DFEATURE_dbus=OFF \
        -DFEATURE_fontconfig=OFF -DFEATURE_sql=OFF -DFEATURE_printsupport=OFF \
        -DFEATURE_testlib=OFF -DFEATURE_zstd=OFF -DFEATURE_brotli=OFF \
        -DFEATURE_openssl=ON -DFEATURE_openssl_linked=OFF -DFEATURE_icu=ON \
        -DFEATURE_system_zlib=ON -DFEATURE_system_png=ON -DFEATURE_system_freetype=ON \
        -DFEATURE_system_jpeg=OFF -DFEATURE_system_harfbuzz=OFF -DFEATURE_system_pcre2=OFF \
        -DFEATURE_system_doubleconversion=OFF -DFEATURE_system_libb2=OFF
    rm -rf "$WORK/qtbase" "$WORK/qtbase-build"
    built qtbase
    rm -f "$WORK/qtdeclarative.stamp" "$WORK/platform.stamp"
fi
if ! current qtdeclarative; then
    step "qtdeclarative $QT_VERSION"
    unpack qtdeclarative-$QT_VERSION.tar.xz "$WORK/qtdeclarative" "$PATCHES/qt6_declarative-$QT_VERSION.patchset"
    # The QML interpreter only: the JIT's Haiku support is x86_64's.
    cm qtdeclarative "$WORK/qtdeclarative" "${QT[@]}" -DFEATURE_qml_jit=OFF
    rm -rf "$WORK/qtdeclarative" "$WORK/qtdeclarative-build"
    built qtdeclarative
    rm -f "$WORK/qtsvg.stamp"
fi
if ! current qtsvg; then
    step "qtsvg $QT_VERSION"
    unpack qtsvg-$QT_VERSION.tar.xz "$WORK/qtsvg"
    cm qtsvg "$WORK/qtsvg" "${QT[@]}"
    rm -rf "$WORK/qtsvg" "$WORK/qtsvg-build"
    built qtsvg
fi

# --- the Haiku platform plugin -----------------------------------------------
# As airos-ci's deps/build-qt-airos.sh builds it for x86_64 (the plugin uses
# Qt's private API: it is built against this Qt).
plugin_stamp="$CHAIN $(git -C "$HAIKU_QT_PLUGINS_SRC" rev-parse HEAD)"
if ! is_current platform "$plugin_stamp" || [[ ! -f $PREFIX/plugins/platforms/libqhaiku.so ]]; then
    step "the Haiku platform plugin ($(git -C "$HAIKU_QT_PLUGINS_SRC" rev-parse --short HEAD))"
    src=$HAIKU_QT_PLUGINS_SRC/src/platform
    build=$WORK/platform
    rm -rf "$build"
    mkdir -p "$build"
    headers=$PREFIX/include
    defines="-DQT_PLUGIN -DQT_NO_DEBUG -DQT_WIDGETS_LIB -DQT_GUI_LIB -DQT_CORE_LIB"
    includes="-I$src -I$HAIKU_QT_PLUGINS_SRC/3rdparty/simplecrypt -I$build -I$headers"
    for module in QtCore QtGui QtWidgets; do
        includes+=" -I$headers/$module -I$headers/$module/$QT_VERSION -I$headers/$module/$QT_VERSION/$module"
    done
    includes+=" -I$PREFIX/mkspecs/haiku-g++ -I$EXTRA/develop/headers/freetype2"
    includes+=" -I$EXTRA/develop/headers/os/opengl"
    for header in "$src"/*.h; do
        grep -q Q_OBJECT "$header" || continue
        # shellcheck disable=SC2086
        "$HOSTQT/libexec/moc" $defines $includes "$header" -o "$build/moc_$(basename "$header" .h).cpp"
    done
    # shellcheck disable=SC2086
    (cd "$src" && "$HOSTQT/libexec/moc" $defines $includes main.cpp -o "$build/main.moc")
    objects=()
    for file in "$src"/*.cpp "$HAIKU_QT_PLUGINS_SRC/3rdparty/simplecrypt/simplecrypt.cpp" "$build"/moc_*.cpp; do
        object=$build/$(basename "$file" .cpp).o
        # shellcheck disable=SC2086
        "${CROSS}g++" --sysroot="$SYSROOT" -std=gnu++17 -O2 -fPIC -fvisibility=hidden -w \
            $defines $includes -c "$file" -o "$object"
        objects+=("$object")
    done
    mkdir -p "$PREFIX/plugins/platforms"
    "${CROSS}g++" --sysroot="$SYSROOT" -specs="$UNWIND_SPECS" -shared -o "$PREFIX/plugins/platforms/libqhaiku.so" \
        "${objects[@]}" -L"$PREFIX/lib" -L"$EXTRA/develop/lib" -L"$EXTRA/lib" -Wl,-rpath-link,"$EXTRA/lib" \
        -lQt6Widgets -lQt6Gui -lQt6Core -lbe -lroot -ltracker -lgame -lGL -lGLU -lfreetype
    rm -rf "$build"
    echo "$plugin_stamp" > "$WORK/platform.stamp"
fi
# what went in, for the package's documentation
{
    echo "Built by tools/haiku/build-gui-deps.sh for $AIROS_ARCH ($CHAIN)"
    echo "Qt $QT_VERSION: qtbase, qtshadertools (host), qtdeclarative, qtsvg (HaikuPorts' patches)"
    echo "qt6-haikuplugins $(git -C "$HAIKU_QT_PLUGINS_SRC" rev-parse HEAD)"
    echo "protobuf 3.20.1, abseil 20230125.3, re2 2022-06-01, c-ares 1.34.8, gRPC 1.53.0 (static)"
    echo "OpenSSL (static): $(sed -n 's/^Version: //p' "$EXTRA/develop/lib/pkgconfig/openssl.pc")"
} > "$PREFIX/sources.txt"
step "dependency prefix: $PREFIX"
