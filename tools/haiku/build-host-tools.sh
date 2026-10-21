#!/usr/bin/env bash
# Linux code generators matched to the HaikuPorts Qt/protobuf/gRPC packages.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOST=${BRIDGE_HOST_BUILD:-$ROOT/build-haiku/host-tools}
CACHE=${BRIDGE_DOWNLOAD_CACHE:-$ROOT/build-haiku/downloads}
JOBS=${JOBS:-8}
mkdir -p "$HOST/host-src" "$CACHE"
fetch() {
    local name=$1 url=$2 sum=$3
    if [[ ! -f $CACHE/$name ]]; then
        curl -fL --retry 3 "$url" -o "$CACHE/$name.tmp"
        mv "$CACHE/$name.tmp" "$CACHE/$name"
    fi
    printf '%s  %s\n' "$sum" "$CACHE/$name" | sha256sum -c -
}
fetch qtbase-6.10.3.tar.xz https://download.qt.io/archive/qt/6.10/6.10.3/submodules/qtbase-everywhere-src-6.10.3.tar.xz 383dc907816338f0cba72088a524c07458dfc69ce684ca9132fcc4fe91c24b0b
fetch protobuf-3.20.1.tar.gz https://github.com/protocolbuffers/protobuf/archive/refs/tags/v3.20.1.tar.gz 8b28fdd45bab62d15db232ec404248901842e5340299a57765e48abe8a80d930
fetch grpc-1.53.0.tar.gz https://github.com/grpc/grpc/archive/refs/tags/v1.53.0.tar.gz 9717ffc52120861136e478155c2ff3a9c21740e2244de52fa966f376d7471adf
for archive in qtbase-6.10.3.tar.xz protobuf-3.20.1.tar.gz grpc-1.53.0.tar.gz; do
    if [[ ! -f $HOST/host-src/.$archive.extracted ]]; then
        tar -xf "$CACHE/$archive" -C "$HOST/host-src"
        touch "$HOST/host-src/.$archive.extracted"
    fi
done
# Qt's host package exports all Core tools. Build them to keep its imports valid.
cmake -S "$HOST/host-src/qtbase-everywhere-src-6.10.3" -B "$HOST/qt-host" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DQT_BUILD_TESTS=OFF -DQT_BUILD_EXAMPLES=OFF \
    -DFEATURE_gui=OFF -DFEATURE_network=OFF -DFEATURE_sql=OFF -DFEATURE_dbus=OFF -DFEATURE_testlib=OFF
cmake --build "$HOST/qt-host" -j"$JOBS"
cmake -S "$HOST/host-src/protobuf-3.20.1/cmake" -B "$HOST/protobuf-host" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -Dprotobuf_BUILD_TESTS=OFF
cmake --build "$HOST/protobuf-host" --target protoc -j"$JOBS"
# The C++ plugin needs only the generator and protobuf compiler libraries.
grpc="$HOST/host-src/grpc-1.53.0"
"${HOST_CXX:-g++}" -std=c++14 -O2 -I"$grpc" -I"$grpc/include" \
    -I"$HOST/host-src/protobuf-3.20.1/src" \
    "$grpc/src/compiler/cpp_plugin.cc" "$grpc/src/compiler/cpp_generator.cc" \
    "$grpc/src/compiler/proto_parser_helper.cc" "$HOST/protobuf-host/libprotoc.a" \
    "$HOST/protobuf-host/libprotobuf.a" -pthread -lz -o "$HOST/grpc_cpp_plugin"
