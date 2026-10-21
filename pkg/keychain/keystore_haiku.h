// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef BRIDGE_KEYSTORE_H
#define BRIDGE_KEYSTORE_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
int32_t bridge_keystore_init(void);
int32_t bridge_keystore_get(const char* service, const char* url, void** data, size_t* size);
int32_t bridge_keystore_put(const char* service, const char* url, const void* data, size_t size);
int32_t bridge_keystore_delete(const char* service, const char* url);
int32_t bridge_keystore_next(const char* service, uint32_t* cookie, void** data, size_t* size);
void bridge_keystore_free(void* data, size_t size);
int bridge_keystore_not_found(int32_t status);
const char* bridge_keystore_error(int32_t status);
#ifdef __cplusplus
}
#endif
#endif
