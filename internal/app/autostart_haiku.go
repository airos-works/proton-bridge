// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package app

/*
#include <FindDirectory.h>
#include <limits.h>
#include <string.h>
*/
import "C"

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/ProtonMail/proton-bridge/v3/internal/bridge"
)

type haikuAutostarter struct {
	directory string
	target    string
	initErr   error
}

func newAutostarter(exe string) bridge.Autostarter {
	var path [C.PATH_MAX]C.char
	status := C.find_directory(C.B_USER_BOOT_DIRECTORY, -1, false, &path[0], C.int32_t(len(path)))
	a := &haikuAutostarter{target: filepath.Join(filepath.Dir(exe), "bridge-autostart")}
	if status != 0 {
		a.initErr = fmt.Errorf("find air/OS startup directory: %s", C.GoString(C.strerror(status)))
	} else {
		a.directory = filepath.Join(C.GoString(&path[0]), "launch")
	}
	return a
}

func (a *haikuAutostarter) path() string { return filepath.Join(a.directory, "Proton Mail Bridge") }

func (a *haikuAutostarter) IsEnabled() bool {
	if a.initErr != nil {
		return false
	}
	target, err := os.Readlink(a.path())
	return err == nil && target == a.target
}

func (a *haikuAutostarter) Enable() error {
	if a.initErr != nil {
		return a.initErr
	}
	info, err := os.Stat(a.target)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() || info.Mode().Perm()&0111 == 0 {
		return errors.New("Bridge startup launcher is not executable")
	}
	if a.IsEnabled() {
		return nil
	}
	if _, err := os.Lstat(a.path()); !errors.Is(err, os.ErrNotExist) {
		if err != nil {
			return err
		}
		return errors.New("another item already occupies the Bridge startup entry")
	}
	if err := os.MkdirAll(a.directory, 0700); err != nil {
		return err
	}
	// Creating a link is atomic, refuses to overwrite an unrelated file, and
	// lets UserBootscript launch an ELF app without opening a Terminal window.
	return os.Symlink(a.target, a.path())
}

func (a *haikuAutostarter) Disable() error {
	if a.initErr != nil {
		return a.initErr
	}
	if !a.IsEnabled() {
		return nil
	}
	return os.Remove(a.path())
}
