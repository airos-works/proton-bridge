// Copyright (c) 2026 Proton AG
// SPDX-License-Identifier: GPL-3.0-or-later

//go:build !haiku

package app

import (
	"github.com/ProtonMail/go-autostart"
	"github.com/ProtonMail/proton-bridge/v3/internal/constants"
	"github.com/sirupsen/logrus"
)

func newAutostarter(exe string) *autostart.App {
	logrus.Debug("Creating autostarter")

	return &autostart.App{
		Name:        constants.FullAppName,
		DisplayName: constants.FullAppName,
		Exec:        []string{exe, "--" + flagNoWindow},
	}
}
