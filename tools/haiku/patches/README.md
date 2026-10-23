HaikuPorts' patches for the arm64 interface dependencies that
`tools/haiku/build-gui-deps.sh` builds, unchanged from haikuports/haikuports
(master at 7e72cdfdd17bf5683b281a1380f2f0cd144acdc3):

- qt6_base-6.10.3.patchset: dev-qt/qt6-base/patches
- qt6_declarative-6.10.3.patchset: dev-qt/qt6-declarative/patches
- grpc-1.53.0.patchset: net-libs/grpc/patches
- abseil_cpp-20230125.3.patchset: dev-cpp/abseil-cpp/patches

HaikuPorts' re2 patch changes only its Makefile (the build uses CMake);
protobuf 3.20.1, c-ares 1.34.8, qtsvg and qtshadertools have none.
