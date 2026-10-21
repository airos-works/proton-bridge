#!/usr/bin/env python3
"""Apply air/OS sources to a fresh `go mod vendor` tree; never edit the module cache."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
vendor = root / "vendor"

def replace(file, before, after):
    path = vendor / file
    text = path.read_text()
    if before not in text:
        if after in text:
            return
        raise SystemExit(f"dependency changed, review Haiku patch: {file}")
    path.write_text(text.replace(before, after, 1))

for name in ["term.go", "utils_unix.go"]:
    replace("github.com/abiosoft/readline/" + name,
            "// +build darwin dragonfly freebsd linux,!appengine netbsd openbsd solaris",
            "// +build darwin dragonfly freebsd linux,!appengine netbsd openbsd solaris haiku")
# Upstream ReadPassword aliases the saved state and would leave terminal echo
# disabled. Copy the termios value before modifying it on every Unix target.
replace("github.com/abiosoft/readline/term.go", "newState := oldState\n", "newStateValue := *oldState\n\tnewState := &newStateValue\n")
replace("google.golang.org/grpc/internal/tcp_keepalive_unix.go",
        "//go:build unix\n", "//go:build unix && !haiku\n")
replace("github.com/abiosoft/ishell/utils_unix.go",
        "// +build darwin dragonfly freebsd linux,!appengine netbsd openbsd solaris",
        "// +build darwin dragonfly freebsd linux,!appengine netbsd openbsd solaris haiku")
for source in (root / "tools/haiku/overlay").rglob("*"):
    if source.is_file():
        target = vendor / source.relative_to(root / "tools/haiku/overlay")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
