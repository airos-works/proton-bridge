# Proton Mail Bridge for air/OS

This fork targets a native air/OS application, included in the core image, using
BKeyStore for the Bridge vault key. The upstream Go mail engine and IMAP/SMTP
implementation remain the basis of the port.

## Work in progress

The full application is not yet built or installed. Implemented so far:

- Native BKeyStore credential helper with service isolation, retrieval, listing,
  replacement and deletion. The key store controls application authorization.
- Fail closed on key store errors on air/OS; do not create an insecure vault or
  replace a missing key when an encrypted vault already exists.
- Native settings/data/cache directories through `find_directory`.
- Cross-build environment and initial dependency adaptations for Haiku.

Still required: finish the engine dependency/platform port, build the desktop
interface, package it, integrate the package into the air/OS core image build,
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
go mod vendor
python3 tools/haiku/prepare-vendor.py
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
