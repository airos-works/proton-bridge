// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//go:build haiku && cgo

package locations

/*
#include <FindDirectory.h>
#include <limits.h>
#include <string.h>
*/
import "C"

import "fmt"

func defaultUserDirs() (config, data, cache string, err error) {
	if config, err = haikuDirectory(C.B_USER_SETTINGS_DIRECTORY); err != nil {
		return
	}
	if data, err = haikuDirectory(C.B_USER_VAR_DIRECTORY); err != nil {
		return
	}
	cache, err = haikuDirectory(C.B_USER_CACHE_DIRECTORY)
	return
}

func haikuDirectory(which C.directory_which) (string, error) {
	var buffer [C.PATH_MAX]C.char
	status := C.find_directory(which, -1, false, &buffer[0], C.int32_t(len(buffer)))
	if status != 0 {
		return "", fmt.Errorf("find air/OS directory: %s", C.GoString(C.strerror(status)))
	}
	return C.GoString(&buffer[0]), nil
}
