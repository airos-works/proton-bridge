// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: MIT

package readline

/*
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
static int terminal_size(int fd, struct winsize* size) {
    return ioctl(fd, TIOCGWINSZ, size);
}
*/
import "C"
import (
	"syscall"
	"unsafe"
)

type Termios syscall.Termios

func getTermios(fd int) (*Termios, error) {
	value := new(Termios)
	result, err := C.tcgetattr(C.int(fd), (*C.struct_termios)(unsafe.Pointer(value)))
	if result != 0 {
		return nil, err
	}
	return value, nil
}
func setTermios(fd int, value *Termios) error {
	result, err := C.tcsetattr(C.int(fd), C.TCSANOW, (*C.struct_termios)(unsafe.Pointer(value)))
	if result != 0 {
		return err
	}
	return nil
}
func GetSize(fd int) (int, int, error) {
	var value C.struct_winsize
	result, err := C.terminal_size(C.int(fd), &value)
	if result != 0 {
		return 0, 0, err
	}
	return int(value.ws_col), int(value.ws_row), nil
}
