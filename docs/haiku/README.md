# Proton Mail Bridge for air/OS

This fork targets a native air/OS application, included in the core image, using
BKeyStore for the Bridge vault key. The upstream Go mail engine and IMAP/SMTP
implementation remain the basis of the port.

## Installed validation build

The x86_64 package `proton_bridge-3.27.1~airos1792553560-1-x86_64.hpkg` is installed
on the Framework laptop through MCP. It was built from `32c34ae6`, with core-image
integration committed in `jmgasper/airos-ci` at `bb0f144`. Its SHA-256 is
`77d23aa1f6c95a6ab0676ab775026c9bd012319958f069d5c806bd6803986b4c`.

The native key store requires first-use authorization for the installed engine
at `/boot/system/apps/ProtonMailBridge/bridge`. Authorization granted to the
previous development path does not carry over. If startup waits at the key-store
dialog, allow the installed Bridge to read its vault key. No insecure fallback
is used. Authorization has been granted on the validation laptop, and the
installed GUI successfully connected to the engine after the package update.

Implemented so far:

- Native BKeyStore credential helper with service isolation, retrieval, listing,
  replacement and deletion. The key store controls application authorization.
- Fail closed on key store errors on air/OS; do not create an insecure vault or
  replace a missing key when an encrypted vault already exists.
- Native settings/data/cache directories through `find_directory`.
- Cross-build environment and dependency adaptations for Haiku.
- Native system/memory information and boot-launch autostart links.
- Package-manager-owned updates, with no Proton binary update feed.
- Working CLI and local IMAP/SMTP services.

The desktop interface runs on the laptop, and the pinned core-image package
build and package installation both passed. Actual Proton account login/mail
validation requires the user's account; do not put credentials in scripts or evidence.

## Toolchain

The cross compiler uses [gen2brain/go](https://github.com/gen2brain/go), Haiku
branch commit `3f5f9a2ae5292a2522e4a99ae0b837fc3eae6a13` (Go 1.27.1).
A Linux host toolchain was bootstrapped with official Go 1.27.3. Stock Go does
not recognize GOOS=haiku. C/C++ use the air/OS x86_64 cross GCC and sysroot.

```
. tools/haiku/env.sh
tools/haiku/build-engine.sh
go test -c -o "$TMPDIR/keychain.test" ./pkg/keychain
go test -c -o "$TMPDIR/locations.test" ./internal/locations
```

Dependency adaptations live in `tools/haiku/overlay` and the preparation script;
`vendor` is generated from the pinned go.mod/go.sum, never committed. The module
cache is never patched. Run the preparation script after regenerating vendor.

On air/OS, run `locations.test -test.v`, then
`PROTON_BRIDGE_KEYCHAIN_TEST=1 keychain.test -test.v`. The native integration
test creates a uniquely named service with disposable test secrets and cleans
it up. The system may ask to authorize the test executable. Without the env
flag, keychain tests run against upstream's in-memory helper.

BKeyStore does not offer atomic replacement. The helper avoids rewriting an
unchanged value and restores the old key if adding a replacement fails. A
process/system failure between removal and insertion remains an OS API
limitation; Bridge normally creates its vault key once. A missing key for an
existing vault is reported, not silently regenerated.

## Verification (2026-10-21)

Cross-compiled with the pinned Go fork and GCC 13.3.0. On the Framework laptop
(air/OS x86_64, hrev60207+1716), via MCP:

- `keychain.test -test.v`: upstream keychain unit tests passed.
- `PROTON_BRIDGE_KEYCHAIN_TEST=1 keychain.test -test.v -test.run '^TestHaikuSystemKeyStore$'`:
  native key store add/read/replace/list/delete and namespace isolation passed.
- `locations.test -test.v`: all four tests passed, including native directory
  lookup and 0700 directory permissions. Mutable data uses B_USER_VAR_DIRECTORY
  (`~/config/var`); B_USER_DATA_DIRECTORY belongs to the read-only package tree.

These are component tests, not a validated mail application. A Linux-host test
attempt needs libsecret development files; it did not provide a passing result.

### Engine milestone

`tools/haiku/build-engine.sh` builds the real Bridge engine and an ELF autostart
launcher. The autostart helper starts the adjacent `launcher` with `--no-window`; its
boot-launch link is managed through `B_USER_BOOT_DIRECTORY`. The GUI, engine and launcher must be installed together.

Additional laptop checks passed:

- CLI startup, `version`, empty account list and normal exit (3.27.1+git).
- A second process reopened the previously created encrypted vault successfully.
- Headless engine served IMAP CAPABILITY/LOGOUT on 127.0.0.1:1143 and SMTP
  EHLO/QUIT on 127.0.0.1:1025; both advertised STARTTLS. TLS 1.3 STARTTLS handshakes subsequently passed for both protocols. The
  certificate is self-signed, as expected; a mail client must trust the local
  certificate. Authenticated mail transfer still needs account validation.
- `app.test -test.run '^TestHaiku'`: access-denied, unavailable-service, and
  missing-key cases preserve the existing vault and do not create an insecure
  vault; autostart enable/disable preserves unrelated startup files.
- `updater.test -test.v`: the complete updater unit-test package passed,
  including the air/OS test that forbids downloads and self-installation.

Hardware security-key (FIDO) authentication still needs a Haiku USB/libfido2
backend. The current port explicitly returns an unsupported error for that
method; it does not bypass two-factor authentication. Password/authenticator-code
login is retained but needs account validation. Do not call the port complete
based only on these component and unauthenticated service checks.

Development tests were run from `/boot/home/proton-bridge-port-tests`. The
installed application is in `/boot/system/apps/ProtonMailBridge` and the command
is `/boot/system/bin/proton-bridge`.

### Core-build integration

The core image pipeline is `jmgasper/airos-ci`. Its `proton_bridge` app target
builds a native hpkg with Qt/gRPC package requirements, a `proton-bridge` command
and a “Proton Mail Bridge” Applications menu entry. The x86_64 image builder
builds a reviewed commit from `apps/bridge.lock.json` through `build-pinned.sh`.
The pin must be reachable from this fork's `master`; its provenance is saved
in the image manifest. ARM64 image builds do not include Bridge yet.

### Desktop milestone

The real Qt/QML welcome screen was displayed on the Framework laptop. The GUI
launched the engine, validated its local gRPC token and loaded its settings and
empty account list. Normal GUI shutdown terminated the engine and launcher.
A fresh launch without rendering flags also worked without QML platform errors.
The default renderer on air/OS is Qt Quick software rendering.

The packaged GUI executable is named `Proton Mail Bridge`, which supplies its
Deskbar label. The engine and launcher carry native `B_BACKGROUND_APP` resources
so only the GUI appears in the running application list. The engine retains its
existing key-store signature and installed path.

- System packages: Qt 6.10.3, protobuf 3.20.1 and gRPC 1.53.0.
- `tools/haiku/build-host-tools.sh` downloads checksum-pinned sources and builds
  Linux moc/rcc/protoc/grpc_cpp_plugin. It and `build-gui.sh` were exercised from
  a fresh GUI build directory. No target executable runs on the Linux host.
- `tools/haiku/build-go-toolchain.sh` bootstraps the pinned Haiku Go branch for CI;
  a clean bootstrap completed successfully on the Linux host.
- The native process provider enumerates teams and resolves executable paths.
  All launcher tests passed on the laptop, including self/parent PID, executable
  identity, CPU/user queries, invalid PID, and ignoring self-update directories.
- Native Sentry crash reporting is disabled because no Haiku Sentry backend is
  available. Exceptions still go to local logs; no report ID is fabricated.
- Update/beta toggles are hidden on air/OS. Help directs users to SoftwareUpdater.
- `dist/haiku/Bridge.hvif` is generated from the upstream SVG silhouette with
  `tools/haiku/make-icon.py`; Haiku's BIconUtils rendered it successfully.

Example desktop cross build (paths supplied by the caller):

```sh
export BRIDGE_HOST_BUILD=/path/to/host-tools
export BRIDGE_DOWNLOAD_CACHE=/path/to/download-cache
tools/haiku/build-host-tools.sh
export HAIKU_SDK_ENV=/path/to/airos-sdk/x86_64/env.sh
export HAIKU_GUI_DEPS=/path/to/extracted-haikuports-dependencies
tools/haiku/build-gui.sh
```

The dependency prefix must contain the runtime and development packages for
`qt6_base`, `qt6_declarative`, `qt6_svg`, `grpc`, `protobuf`, and their dependencies.
The build supports x86_64 currently; equivalent desktop dependencies are not
available in the air/OS ARM64 package set yet.

Further desktop checks passed: killing the GUI caused the engine to shut down,
the native autostart helper launched the GUI/engine with `--no-window`, and a
second launcher invocation raised the existing window. A successful focus now
returns success instead of being logged as a launch failure.

The updated installed package was checked against the live application roster:
one foreground application named `Proton Mail Bridge`, with the engine marked
as a background application. The launcher and engine both have native app flags
`0x5` (`B_MULTIPLE_LAUNCH | B_BACKGROUND_APP`), and the GUI has flags `0x1`.
A Deskbar screenshot confirmed the single entry. Launching again from the
Applications menu returned success and kept the same GUI and engine teams.

### Validation steps

1. Approve the installed Bridge's native key-store dialog, then open **Applications
   → Proton Mail Bridge** in Deskbar (or run `proton-bridge`).
2. Sign in using a Proton account with Bridge access. Password and authenticator
   codes are supported; hardware FIDO security keys are not supported by this port.
3. Configure a mail client using the **Bridge-generated** username/password and
   the local IMAP/SMTP settings shown by Bridge. The defaults are localhost ports
   1143 and 1025 with STARTTLS. Trust Bridge's local self-signed certificate in
   that client; system-wide certificate installation is not implemented on air/OS.
4. Check message sync, reading, sending, restarting Bridge and reopening the
   account. These account-dependent checks have not been performed by the agent.

The native Go TLS stack successfully verified `mail-api.proton.me` using the
system CA bundle and TLS 1.3. Local IMAP/SMTP STARTTLS handshakes also passed.
