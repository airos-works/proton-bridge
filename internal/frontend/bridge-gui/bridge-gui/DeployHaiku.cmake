# air/OS resolves Qt/gRPC libraries and QML modules through package dependencies.
# Do not bundle Linux XCB/Wayland plugins or private copies of the Qt runtime.
# Deskbar displays the executable name, independently of Qt's application name.
set_target_properties(bridge-gui PROPERTIES
    OUTPUT_NAME "Proton Mail Bridge"
    INSTALL_RPATH "")
