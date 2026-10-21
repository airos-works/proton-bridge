// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"os"
	"slices"
	"testing"

	"github.com/elastic/go-sysinfo"
	"github.com/elastic/go-sysinfo/types"
	"github.com/stretchr/testify/require"
)

func TestHaikuProcessProvider(t *testing.T) {
	processes, err := sysinfo.Processes()
	require.NoError(t, err)
	require.True(t, slices.ContainsFunc(processes, func(p types.Process) bool { return p.PID() == os.Getpid() }))
	self, err := sysinfo.Self()
	require.NoError(t, err)
	info, err := self.Info()
	require.NoError(t, err)
	require.Equal(t, os.Getpid(), info.PID)
	require.Equal(t, os.Getppid(), info.PPID)
	exe, err := os.Executable()
	require.NoError(t, err)
	expected, err := os.Stat(exe)
	require.NoError(t, err)
	require.True(t, sameFile(expected, info.Exe), "provider must return the actual executable, not truncated arguments")
	parent, err := self.Parent()
	require.NoError(t, err)
	require.Equal(t, os.Getppid(), parent.PID())
	_, err = self.CPUTime()
	require.NoError(t, err)
	_, err = self.User()
	require.NoError(t, err)
	_, err = sysinfo.Process(-12345)
	require.Error(t, err)
}

func TestHaikuLauncherIgnoresSelfUpdates(t *testing.T) {
	// No version directory or verification key should be touched on air/OS.
	_, err := getPathToUpdatedExecutable("launcher", nil, nil)
	require.ErrorContains(t, err, "package manager")
}
