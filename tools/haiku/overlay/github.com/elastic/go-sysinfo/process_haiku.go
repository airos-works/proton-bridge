// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: Apache-2.0

package sysinfo

/*
#include <OS.h>
#include <image.h>
#include <string.h>
static status_t bridge_team_info(team_id id, team_info *info) {
    return get_team_info(id, info);
}
static status_t bridge_next_team(int32 *cookie, team_info *info) {
    return get_next_team_info(cookie, info);
}
static status_t bridge_executable(team_id id, image_info *info) {
    int32 cookie = 0;
    status_t status;
    while ((status = get_next_image_info(id, &cookie, info)) == B_OK) {
        if (info->type == B_APP_IMAGE) return B_OK;
    }
    return status;
}
static status_t bridge_cpu_time(team_id id, team_usage_info *info) {
    return get_team_usage_info(id, B_TEAM_USAGE_SELF, info);
}
*/
import "C"

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/elastic/go-sysinfo/internal/registry"
	"github.com/elastic/go-sysinfo/types"
)

type haikuProcessProvider struct{}
type haikuProcess struct{ pid int }

func init()                                                 { registry.Register(haikuProcessProvider{}) }
func (p haikuProcessProvider) Self() (types.Process, error) { return p.Process(os.Getpid()) }
func (haikuProcessProvider) Process(pid int) (types.Process, error) {
	var info C.team_info
	if status := C.bridge_team_info(C.team_id(pid), &info); status != C.B_OK {
		return nil, fmt.Errorf("get_team_info: %s", C.GoString(C.strerror(status)))
	}
	return &haikuProcess{pid: int(info.team)}, nil
}
func (haikuProcessProvider) Processes() ([]types.Process, error) {
	var cookie C.int32
	var info C.team_info
	var result []types.Process
	for {
		status := C.bridge_next_team(&cookie, &info)
		if status == C.B_BAD_TEAM_ID {
			break
		}
		if status != C.B_OK {
			return nil, fmt.Errorf("get_next_team_info: %s", C.GoString(C.strerror(status)))
		}
		result = append(result, &haikuProcess{pid: int(info.team)})
	}
	return result, nil
}
func (p *haikuProcess) PID() int { return p.pid }
func (p *haikuProcess) Info() (types.ProcessInfo, error) {
	var team C.team_info
	if status := C.bridge_team_info(C.team_id(p.pid), &team); status != C.B_OK {
		return types.ProcessInfo{}, fmt.Errorf("get_team_info: %s", C.GoString(C.strerror(status)))
	}
	info := types.ProcessInfo{Name: C.GoString(&team.name[0]), PID: p.pid, PPID: int(team.parent),
		StartTime: time.Now().Add(time.Duration(team.start_time-C.system_time()) * time.Microsecond)}
	var image C.image_info
	if status := C.bridge_executable(C.team_id(p.pid), &image); status != C.B_OK {
		return info, fmt.Errorf("get_next_image_info: %s", C.GoString(C.strerror(status)))
	}
	info.Exe = C.GoString(&image.name[0])
	// team_info.args is truncated and unquoted; never present it as argv.
	if p.pid == os.Getpid() {
		info.Args = append([]string(nil), os.Args...)
		info.CWD, _ = os.Getwd()
	}
	return info, nil
}
func (p *haikuProcess) Parent() (types.Process, error) {
	info, err := p.Info()
	if err != nil {
		return nil, err
	}
	return (haikuProcessProvider{}).Process(info.PPID)
}
func (p *haikuProcess) CPUTime() (types.CPUTimes, error) {
	var info C.team_usage_info
	if status := C.bridge_cpu_time(C.team_id(p.pid), &info); status != C.B_OK {
		return types.CPUTimes{}, fmt.Errorf("get_team_usage_info: %s", C.GoString(C.strerror(status)))
	}
	return types.CPUTimes{User: time.Duration(info.user_time) * time.Microsecond,
		System: time.Duration(info.kernel_time) * time.Microsecond}, nil
}
func (p *haikuProcess) User() (types.UserInfo, error) {
	var info C.team_info
	if status := C.bridge_team_info(C.team_id(p.pid), &info); status != C.B_OK {
		return types.UserInfo{}, fmt.Errorf("get_team_info: %s", C.GoString(C.strerror(status)))
	}
	return types.UserInfo{UID: strconv.Itoa(int(info.real_uid)), EUID: strconv.Itoa(int(info.uid)),
		GID: strconv.Itoa(int(info.real_gid)), EGID: strconv.Itoa(int(info.gid))}, nil
}
func (p *haikuProcess) Memory() (types.MemoryInfo, error) {
	return types.MemoryInfo{}, types.ErrNotImplemented
}
