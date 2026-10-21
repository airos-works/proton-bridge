# Proton Mail Bridge for air/OS

This fork targets a native air/OS application, included in the core image, using
BKeyStore for the Bridge vault key. The upstream Go mail engine and IMAP/SMTP
implementation remain the basis of the port.

## Work in progress

The engine builds and runs on the laptop. The desktop application and installable
package are not yet ready for user validation. Implemented so far:

- Native BKeyStore credential helper with service isolation, retrieval, listing,
  replacement and deletion. The key store controls application authorization.
- Fail closed on key store errors on air/OS; do not create an insecure vault or
  replace a missing key when an encrypted vault already exists.
- Native settings/data/cache directories through `find_directory`.
- Cross-build environment and dependency adaptations for Haiku.
- Native system/memory information and boot-launch autostart links.
- Package-manager-owned updates, with no Proton binary update feed.
- Working CLI and local IMAP/SMTP services.

Still required: build the desktop interface, package it, integrate the package
into the air/OS core image build,
run native application smoke tests and install the validation build on the
Framework laptop through MCP. Actual Proton account login/mail validation will
require the user's account; do not put credentials in scripts or evidence.

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
launcher. The launcher starts the adjacent `bridge` with `--no-window`; its
boot-launch link is managed through `B_USER_BOOT_DIRECTORY`. It will need the
GUI beside the engine before the GUI/autostart path can be exercised end to end.

Additional laptop checks passed:

- CLI startup, `version`, empty account list and normal exit (3.27.1+git).
- A second process reopened the previously created encrypted vault successfully.
- Headless engine served IMAP CAPABILITY/LOGOUT on 127.0.0.1:1143 and SMTP
  EHLO/QUIT on 127.0.0.1:1025; both advertised STARTTLS. TLS handshakes and
  authenticated mail transfer still need testing.
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

The test executables are in `/boot/home/proton-bridge-port-tests` on the laptop.
They are development artifacts, not the requested final packaged installation.
The headless smoke-test process was stopped normally after checking its services.

### Core-build integration work remaining

The current core image pipeline is `jmgasper/airos-ci` (local checkout
`/mnt/HaikuWork/src/airos-ci`): `apps/build-app-packages.sh` builds app packages,
`apps/ci-build-app.sh` adds them to the architecture package pool, and
`images/build-image.sh` selects the core image apps in `IMAGE_APPS`.
Add Bridge there once the desktop package and its dependencies are built. The
GUI's `BridgeUtils.cpp` also needs native settings/cache paths to agree with the
Go engine, and `BridgeSetup.cmake` currently assumes vcpkg.
