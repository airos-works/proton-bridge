// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: Apache-2.0

package sysinfo

/*
#include <OS.h>
#include <sys/utsname.h>
#include <string.h>
*/
import "C"

import (
	"context"
	"fmt"
	"net"
	"os"
	"strings"
	"time"

	"github.com/elastic/go-sysinfo/internal/registry"
	"github.com/elastic/go-sysinfo/types"
)

type haikuHostProvider struct{}
type haikuHost struct{ info types.HostInfo }

func init() { registry.Register(haikuHostProvider{}) }
func (haikuHostProvider) Host() (types.Host, error) {
	var uts C.struct_utsname
	if status, err := C.uname(&uts); status != 0 {
		return nil, err
	}
	hostname, err := os.Hostname()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	zone, offset := now.Zone()
	arch := C.GoString(&uts.machine[0])
	return &haikuHost{info: types.HostInfo{
		Architecture: arch, NativeArchitecture: arch, Hostname: hostname,
		BootTime: now.Add(-time.Duration(C.system_time()) * time.Microsecond),
		Timezone: zone, TimezoneOffsetSec: offset,
		KernelVersion: C.GoString(&uts.version[0]),
		OS: &types.OSInfo{Type: "unix", Family: "haiku", Platform: "haiku", Name: "air/OS",
			Version: C.GoString(&uts.release[0]), Build: C.GoString(&uts.version[0])},
	}}, nil
}
func (h *haikuHost) Info() types.HostInfo { return h.info }
func (h *haikuHost) Memory() (*types.HostMemoryInfo, error) {
	var info C.system_info
	if status := C.get_system_info(&info); status != 0 {
		return nil, fmt.Errorf("get_system_info: %s", C.GoString(C.strerror(status)))
	}
	total := uint64(info.max_pages) * uint64(C.B_PAGE_SIZE)
	used := uint64(info.used_pages) * uint64(C.B_PAGE_SIZE)
	if used > total {
		return nil, fmt.Errorf("invalid memory page counts")
	}
	return &types.HostMemoryInfo{Total: total, Used: used, Free: total - used, Available: total - used}, nil
}
func (h *haikuHost) CPUTime() (types.CPUTimes, error) {
	// Haiku reports aggregate active time, not the user/system split required
	// by this interface. Bridge uses host identity and memory only.
	return types.CPUTimes{}, types.ErrNotImplemented
}
func (h *haikuHost) FQDN() (string, error) { return h.FQDNWithContext(context.Background()) }
func (h *haikuHost) FQDNWithContext(ctx context.Context) (string, error) {
	name, err := net.DefaultResolver.LookupCNAME(ctx, h.info.Hostname)
	return strings.TrimSuffix(name, "."), err
}
