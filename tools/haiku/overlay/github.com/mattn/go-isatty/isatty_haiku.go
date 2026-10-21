// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: MIT

package isatty

// #include <unistd.h>
import "C"

func IsTerminal(fd uintptr) bool       { return C.isatty(C.int(fd)) == 1 }
func IsCygwinTerminal(fd uintptr) bool { return false }
