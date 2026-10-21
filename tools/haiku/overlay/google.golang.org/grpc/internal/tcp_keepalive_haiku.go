// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: Apache-2.0

package internal

import (
	"net"
	"syscall"
	"time"
)

// Use Haiku's libnetwork-backed syscall implementation. Raw numbered system
// calls and golang.org/x/sys/unix are not available on Haiku.
func NetDialerWithTCPKeepalive() *net.Dialer {
	return &net.Dialer{
		KeepAlive: time.Duration(-1),
		Control: func(_, _ string, c syscall.RawConn) error {
			var socketErr error
			if err := c.Control(func(fd uintptr) {
				socketErr = syscall.SetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_KEEPALIVE, 1)
			}); err != nil {
				return err
			}
			return socketErr
		},
	}
}
