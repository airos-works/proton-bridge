# air/OS resolves Qt/gRPC libraries and QML modules through package dependencies.
# Do not bundle Linux XCB/Wayland plugins or private copies of the Qt runtime.
set_target_properties(bridge-gui PROPERTIES INSTALL_RPATH "")
