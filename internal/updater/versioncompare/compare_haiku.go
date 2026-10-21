// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package versioncompare

import (
	"github.com/elastic/go-sysinfo/types"
	"github.com/sirupsen/logrus"
)

func (sysVer SystemVersion) IsHostVersionEligible(log *logrus.Entry, _ types.Host, _ func(types.Host) string) (bool, error) {
	log.Info("air/OS updates Bridge through the system package manager")
	return false, nil
}
