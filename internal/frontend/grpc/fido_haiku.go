// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package grpc

import (
	"context"
	"github.com/ProtonMail/proton-bridge/v3/internal/fido"
	"google.golang.org/protobuf/types/known/emptypb"
)

func (s *Service) LoginFido(context.Context, *LoginRequest) (*emptypb.Empty, error) {
	defer s.loginClean()
	return &emptypb.Empty{}, s.SendEvent(NewLoginError(LoginErrorType_FIDO_ERROR, fido.ErrHardwareKeyUnavailable.Error()))
}
