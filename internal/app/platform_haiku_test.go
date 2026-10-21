// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package app

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/ProtonMail/proton-bridge/v3/internal/locations"
	"github.com/ProtonMail/proton-bridge/v3/pkg/keychain"
	"github.com/docker/docker-credential-helpers/credentials"
	"github.com/stretchr/testify/require"
)

type haikuTestDirs struct{ root string }

func (p haikuTestDirs) UserConfig() string { return filepath.Join(p.root, "settings") }
func (p haikuTestDirs) UserData() string   { return filepath.Join(p.root, "data") }
func (p haikuTestDirs) UserCache() string  { return filepath.Join(p.root, "cache") }

type unavailableHaikuKey struct {
	keychain.TestHelper
	err error
}

func (h unavailableHaikuKey) Get(string) (string, string, error) { return "", "", h.err }

func TestHaikuVaultFailurePreservesData(t *testing.T) {
	for name, failure := range map[string]error{
		"access denied":        errors.New("keyring access denied"),
		"service unavailable":  errors.New("key store service unavailable"),
		"missing existing key": credentials.NewErrCredentialsNotFound(),
	} {
		t.Run(name, func(t *testing.T) {
			loc := locations.New(haikuTestDirs{t.TempDir()}, "bridge-v3")
			settings, err := loc.ProvideSettingsPath()
			require.NoError(t, err)
			path := filepath.Join(settings, "vault.enc")
			before := []byte("existing encrypted vault must not be replaced")
			require.NoError(t, os.WriteFile(path, before, 0600))
			helper := unavailableHaikuKey{keychain.NewTestHelper(), failure}
			keys := keychain.NewTestKeychainsList()
			keys.GetHelpers()["mock"] = func(string) (credentials.Helper, error) { return helper, nil }
			_, insecure, _, err := newVault(nil, loc, keys, nil, map[string]bool{}, nil)
			require.Error(t, err)
			require.False(t, insecure)
			after, err := os.ReadFile(path)
			require.NoError(t, err)
			require.Equal(t, before, after)
			require.Empty(t, helper.TestHelper, "must not generate a replacement key")
			require.NoDirExists(t, filepath.Join(settings, "insecure"))
		})
	}
}

func TestHaikuAutostart(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "bridge-autostart")
	require.NoError(t, os.WriteFile(target, []byte("test executable"), 0700))
	a := &haikuAutostarter{directory: filepath.Join(root, "launch"), target: target}
	require.False(t, a.IsEnabled())
	require.NoError(t, a.Enable())
	require.True(t, a.IsEnabled())
	require.NoError(t, a.Enable())
	link, err := os.Readlink(a.path())
	require.NoError(t, err)
	require.Equal(t, target, link)
	require.NoError(t, a.Disable())
	require.False(t, a.IsEnabled())
	require.NoError(t, a.Disable())
	// User-owned files in the startup directory must survive both actions.
	require.NoError(t, os.WriteFile(a.path(), []byte("user file"), 0600))
	require.Error(t, a.Enable())
	require.NoError(t, a.Disable())
	content, err := os.ReadFile(a.path())
	require.NoError(t, err)
	require.Equal(t, "user file", string(content))
}
