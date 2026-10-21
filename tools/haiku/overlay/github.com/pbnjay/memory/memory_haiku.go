// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: BSD-3-Clause

package memory

// #include <OS.h>
import "C"

func sysTotalMemory() uint64 {
	var info C.system_info
	if C.get_system_info(&info) != 0 {
		return 0
	}
	return uint64(info.max_pages) * uint64(C.B_PAGE_SIZE)
}
func sysFreeMemory() uint64 {
	var info C.system_info
	if C.get_system_info(&info) != 0 || info.used_pages > info.max_pages {
		return 0
	}
	return uint64(info.max_pages-info.used_pages) * uint64(C.B_PAGE_SIZE)
}
