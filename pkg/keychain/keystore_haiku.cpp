// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//go:build haiku && cgo

#include "keystore_haiku.h"
#include <Application.h>
#include <KeyStore.h>
#include <stdlib.h>
#include <string.h>
#include <new>

int32_t bridge_keystore_init()
{
    // Registration is required: keystore_server identifies and authorizes the
    // calling team through the roster. Keep the application for process life.
    if (be_app != NULL)
        return B_OK;
    status_t status;
    BApplication* app = new(std::nothrow) BApplication(
        "application/x-vnd.ProtonMail-Bridge", &status);
    if (app == NULL)
        return B_NO_MEMORY;
    if (status != B_OK) {
        delete app;
        return status;
    }
    app->Unlock();
    return B_OK;
}

static status_t copy_data(const BKey& key, void** data, size_t* size)
{
    *size = key.DataLength();
    *data = malloc(*size == 0 ? 1 : *size);
    if (*data == NULL)
        return B_NO_MEMORY;
    memcpy(*data, key.Data(), *size);
    return B_OK;
}

int32_t bridge_keystore_get(const char* service, const char* url, void** data, size_t* size)
{
    BKeyStore store;
    BKey key;
    status_t status = store.GetKey(B_KEY_TYPE_GENERIC, service, url, key);
    return status == B_OK ? copy_data(key, data, size) : status;
}

int32_t bridge_keystore_put(const char* service, const char* url, const void* data, size_t size)
{
    BKeyStore store;
    BKey next;
    status_t status = next.SetTo(B_KEY_PURPOSE_NETWORK, service, url,
        static_cast<const uint8*>(data), size);
    if (status != B_OK)
        return status;
    BKey previous;
    status = store.GetKey(B_KEY_TYPE_GENERIC, service, url, previous);
    if (status == B_ENTRY_NOT_FOUND)
        return store.AddKey(next);
    if (status != B_OK)
        return status;
    if (previous.DataLength() == size && memcmp(previous.Data(), data, size) == 0)
        return B_OK;
    // BKeyStore has no replace operation. Restore the previous value if the
    // replacement fails; never remove an entry following an access error.
    status = store.RemoveKey(previous);
    if (status != B_OK)
        return status;
    status = store.AddKey(next);
    if (status != B_OK) {
        status_t restored = store.AddKey(previous);
        if (restored != B_OK)
            return restored;
    }
    return status;
}

int32_t bridge_keystore_delete(const char* service, const char* url)
{
    BKeyStore store;
    BKey key;
    status_t status = store.GetKey(B_KEY_TYPE_GENERIC, service, url, key);
    return status == B_OK ? store.RemoveKey(key) : status;
}

int32_t bridge_keystore_next(const char* service, uint32_t* cookie, void** data, size_t* size)
{
    BKeyStore store;
    BKey key;
    status_t status;
    while ((status = store.GetNextKey(B_KEY_TYPE_GENERIC, B_KEY_PURPOSE_NETWORK,
        *cookie, key)) == B_OK) {
        if (strcmp(key.Identifier(), service) == 0)
            return copy_data(key, data, size);
    }
    return status;
}

void bridge_keystore_free(void* data, size_t size)
{
    // Do not leave the C copy of a vault key in a freed allocation.
    volatile unsigned char* bytes = static_cast<volatile unsigned char*>(data);
    while (size-- > 0)
        *bytes++ = 0;
    free(data);
}

int bridge_keystore_not_found(int32_t status) { return status == B_ENTRY_NOT_FOUND; }
const char* bridge_keystore_error(int32_t status) { return strerror(status); }
