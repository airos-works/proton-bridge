// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: MIT

package logrus

// #include <unistd.h>
import "C"

func isTerminal(fd int) bool { return C.isatty(C.int(fd)) == 1 }
