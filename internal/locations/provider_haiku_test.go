// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package locations

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestHaikuDefaultProvider(t *testing.T) {
	name := "proton-bridge-test-" + filepath.Base(t.TempDir())
	p, err := NewDefaultProvider(name)
	require.NoError(t, err)
	for which, path := range map[string]string{
		"B_USER_SETTINGS_DIRECTORY": p.UserConfig(),
		"B_USER_VAR_DIRECTORY":      p.UserData(),
		"B_USER_CACHE_DIRECTORY":    p.UserCache(),
	} {
		t.Cleanup(func() { _ = os.Remove(path) })
		output, err := exec.Command("/boot/system/bin/finddir", which).Output()
		require.NoError(t, err)
		require.Equal(t, filepath.Join(strings.TrimSpace(string(output)), name), path)
		info, err := os.Stat(path)
		require.NoError(t, err)
		require.Equal(t, os.FileMode(0700), info.Mode().Perm())
	}
}
