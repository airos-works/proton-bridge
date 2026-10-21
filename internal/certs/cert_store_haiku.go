// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package certs

import "errors"

// Bridge's local certificate can be exported and trusted in the mail client.
// System trust anchors are managed by air/OS packages.
func osSupportCertInstall() bool { return false }
func installCert([]byte) error {
	return errors.New("import the Bridge certificate in your mail client")
}
func uninstallCert([]byte) error {
	return errors.New("remove the Bridge certificate in your mail client")
}
func isCertInstalled([]byte) bool { return false }
