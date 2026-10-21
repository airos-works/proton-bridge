// Copyright (c) 2026 Proton AG
// SPDX-License-Identifier: GPL-3.0-or-later

//go:build !haiku

package locations

import "os"

func defaultUserDirs() (config, data, cache string, err error) {
	if config, err = os.UserConfigDir(); err != nil {
		return
	}
	if data, err = userDataDir(); err != nil {
		return
	}
	cache, err = os.UserCacheDir()
	return
}
