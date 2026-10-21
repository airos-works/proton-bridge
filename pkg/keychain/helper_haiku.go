// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//go:build haiku && cgo

package keychain

/*
#cgo LDFLAGS: -lbe -lstdc++
#include <stdlib.h>
#include "keystore_haiku.h"
*/
import "C"

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"unsafe"

	"github.com/docker/docker-credential-helpers/credentials"
)

const HaikuKeyStore = "airos-keystore"

// BKeyStore operates on the system keyring. Scope each helper to its own
// service, and serialize across helpers as replacement uses two OS calls.
var haikuKeyStoreMu sync.Mutex

type haikuKeyStore struct{ service string }

func listHelpers() (Helpers, string) {
	// Availability is not tested by writing a disposable password. A locked or
	// denied keyring must remain selected and return its actual access error.
	return Helpers{HaikuKeyStore: newHaikuKeyStore}, HaikuKeyStore
}

func newHaikuKeyStore(service string) (credentials.Helper, error) {
	if service == "" || strings.ContainsRune(service, 0) {
		return nil, errors.New("invalid key store service")
	}
	haikuKeyStoreMu.Lock()
	defer haikuKeyStoreMu.Unlock()
	if err := haikuKeyStoreError(C.bridge_keystore_init()); err != nil {
		return nil, err
	}
	return &haikuKeyStore{service: service}, nil
}

func haikuKeyStoreError(status C.int32_t) error {
	if status == 0 {
		return nil
	}
	if C.bridge_keystore_not_found(status) != 0 {
		return credentials.NewErrCredentialsNotFound()
	}
	return fmt.Errorf("air/OS key store: %s (%d)", C.GoString(C.bridge_keystore_error(status)), int32(status))
}

func (h *haikuKeyStore) validURL(url string) bool {
	return strings.HasPrefix(url, h.service+"/") && len(url) > len(h.service)+1 && !strings.ContainsRune(url, 0)
}

func (h *haikuKeyStore) Add(cred *credentials.Credentials) error {
	if cred == nil || !h.validURL(cred.ServerURL) || cred.Username == "" || cred.Secret == "" {
		return errors.New("invalid air/OS key store credential")
	}
	data, err := json.Marshal(cred)
	if err != nil {
		return err
	}
	defer clear(data)
	service, url := C.CString(h.service), C.CString(cred.ServerURL)
	defer C.free(unsafe.Pointer(service))
	defer C.free(unsafe.Pointer(url))
	haikuKeyStoreMu.Lock()
	defer haikuKeyStoreMu.Unlock()
	return haikuKeyStoreError(C.bridge_keystore_put(service, url, unsafe.Pointer(&data[0]), C.size_t(len(data))))
}

func (h *haikuKeyStore) Get(serverURL string) (string, string, error) {
	if !h.validURL(serverURL) {
		return "", "", credentials.NewErrCredentialsNotFound()
	}
	service, url := C.CString(h.service), C.CString(serverURL)
	defer C.free(unsafe.Pointer(service))
	defer C.free(unsafe.Pointer(url))
	haikuKeyStoreMu.Lock()
	defer haikuKeyStoreMu.Unlock()
	var data unsafe.Pointer
	var size C.size_t
	if err := haikuKeyStoreError(C.bridge_keystore_get(service, url, &data, &size)); err != nil {
		return "", "", err
	}
	defer C.bridge_keystore_free(data, size)
	cred, err := h.decode(data, size)
	if err != nil {
		return "", "", err
	}
	if cred.ServerURL != serverURL {
		return "", "", errors.New("air/OS key store credential URL mismatch")
	}
	return cred.Username, cred.Secret, nil
}

func (h *haikuKeyStore) Delete(serverURL string) error {
	if !h.validURL(serverURL) {
		return credentials.NewErrCredentialsNotFound()
	}
	service, url := C.CString(h.service), C.CString(serverURL)
	defer C.free(unsafe.Pointer(service))
	defer C.free(unsafe.Pointer(url))
	haikuKeyStoreMu.Lock()
	defer haikuKeyStoreMu.Unlock()
	return haikuKeyStoreError(C.bridge_keystore_delete(service, url))
}

func (h *haikuKeyStore) List() (map[string]string, error) {
	service := C.CString(h.service)
	defer C.free(unsafe.Pointer(service))
	haikuKeyStoreMu.Lock()
	defer haikuKeyStoreMu.Unlock()
	result := make(map[string]string)
	var cookie C.uint32_t
	for {
		var data unsafe.Pointer
		var size C.size_t
		status := C.bridge_keystore_next(service, &cookie, &data, &size)
		if C.bridge_keystore_not_found(status) != 0 {
			return result, nil
		}
		if err := haikuKeyStoreError(status); err != nil {
			return nil, err
		}
		cred, err := h.decode(data, size)
		C.bridge_keystore_free(data, size)
		if err != nil {
			return nil, err
		}
		result[cred.ServerURL] = cred.Username
	}
}

func (h *haikuKeyStore) decode(data unsafe.Pointer, size C.size_t) (credentials.Credentials, error) {
	var cred credentials.Credentials
	// Vault keys are small; bound corrupt/native lengths before converting to int.
	if size == 0 || size > 1024*1024 {
		return cred, errors.New("invalid air/OS key store record size")
	}
	raw := C.GoBytes(data, C.int(size))
	defer clear(raw)
	if err := json.Unmarshal(raw, &cred); err != nil {
		// Do not include the JSON or decoder error (which can contain secrets).
		return cred, errors.New("invalid air/OS key store record")
	}
	if !h.validURL(cred.ServerURL) || cred.Username == "" || cred.Secret == "" {
		return cred, errors.New("invalid air/OS key store credential")
	}
	return cred, nil
}
