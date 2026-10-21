// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package fido

import (
	"errors"
	"github.com/ProtonMail/go-proton-api"
)

// The Haiku port of libfido2/USB HID is still required for hardware-key login.
// Never treat unavailable hardware authentication as successful authentication.
var ErrHardwareKeyUnavailable = errors.New("hardware security key login is not yet available on air/OS; use an authenticator code if enabled for your Proton account")

func AuthWithHardwareKeyCLI(CLIProvider, *proton.Client, proton.Auth) error {
	return ErrHardwareKeyUnavailable
}
