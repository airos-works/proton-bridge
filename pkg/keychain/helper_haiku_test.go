// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//go:build haiku && cgo

package keychain

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/docker/docker-credential-helpers/credentials"
	"github.com/stretchr/testify/require"
)

// This integration test creates only disposable entries under a unique service.
// Run on air/OS with PROTON_BRIDGE_KEYCHAIN_TEST=1; the OS may ask for access.
func TestHaikuSystemKeyStore(t *testing.T) {
	if os.Getenv("PROTON_BRIDGE_KEYCHAIN_TEST") != "1" {
		t.Skip("set PROTON_BRIDGE_KEYCHAIN_TEST=1 to exercise BKeyStore")
	}
	service := fmt.Sprintf("protonmail/bridge-test-%d-%d/users", os.Getpid(), time.Now().UnixNano())
	helper, err := newHaikuKeyStore(service)
	require.NoError(t, err)
	other, err := newHaikuKeyStore(service + "-other")
	require.NoError(t, err)
	url := service + "/test-user"
	cred := &credentials.Credentials{ServerURL: url, Username: "test-user", Secret: "disposable\x00secret\n✓"}
	_, _, err = helper.Get(url)
	require.True(t, credentials.IsErrCredentialsNotFound(err))
	require.NoError(t, helper.Add(cred))
	t.Cleanup(func() { _ = helper.Delete(url) })
	user, secret, err := helper.Get(url)
	require.NoError(t, err)
	require.Equal(t, cred.Username, user)
	require.Equal(t, cred.Secret, secret)
	entries, err := helper.List()
	require.NoError(t, err)
	require.Equal(t, map[string]string{url: cred.Username}, entries)
	entries, err = other.List()
	require.NoError(t, err)
	require.Empty(t, entries)
	_, _, err = other.Get(url)
	require.True(t, credentials.IsErrCredentialsNotFound(err))
	require.Error(t, other.Add(cred))
	cred.Secret = "replacement secret"
	require.NoError(t, helper.Add(cred))
	// Constructing another helper must read the persisted key, not process state.
	reopened, err := newHaikuKeyStore(service)
	require.NoError(t, err)
	_, secret, err = reopened.Get(url)
	require.NoError(t, err)
	require.Equal(t, cred.Secret, secret)
	require.NoError(t, reopened.Delete(url))
	_, _, err = helper.Get(url)
	require.True(t, credentials.IsErrCredentialsNotFound(err))
	entries, err = helper.List()
	require.NoError(t, err)
	require.Empty(t, entries)
}
