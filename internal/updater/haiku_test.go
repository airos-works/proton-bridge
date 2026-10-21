// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package updater

import (
	"context"
	"github.com/ProtonMail/proton-bridge/v3/internal/platform"
	"github.com/stretchr/testify/require"
	"testing"
)

func TestHaikuUpdatesStayWithPackageManager(t *testing.T) {
	u := &Updater{platform: platform.HAIKU}
	// Nil downloader/installer deliberately fail if the OS-managed path tries
	// to fetch a feed, download a binary, or modify an installed package.
	info, err := u.GetVersionInfo(context.Background(), nil)
	require.NoError(t, err)
	require.Empty(t, info.Releases)
	require.ErrorContains(t, u.InstallUpdate(context.Background(), nil, Release{}, false), "SoftwareUpdater")
}
