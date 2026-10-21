// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#include <OS.h>
#include <image.h>
#include <errno.h>
#include <Path.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main()
{
    int32 cookie = 0;
    image_info image;
    while (get_next_image_info(B_CURRENT_TEAM, &cookie, &image) == B_OK) {
        if (image.type != B_APP_IMAGE)
            continue;
        BPath path(image.name);
        if (path.GetParent(&path) != B_OK || path.Append("launcher") != B_OK)
            return 1;
        const char* args[] = {path.Path(), "--no-window", NULL};
        execv(path.Path(), const_cast<char* const*>(args));
        fprintf(stderr, "Could not start Proton Mail Bridge: %s\n", strerror(errno));
        return 1;
    }
    return 1;
}
