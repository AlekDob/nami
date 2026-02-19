---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [macos, python, xcode, pip, bun]
---

# macOS Xcode Python3 Doesn't See pip3 Packages

## Symptom

`pip3 install cryptography` succeeds, but `python3 -c "import cryptography"` still fails with `ModuleNotFoundError`.

## Root Cause

macOS may resolve `python3` to **Xcode's embedded Python** (`/Applications/Xcode.app/.../python3`) instead of Homebrew or system Python. Xcode Python has its own isolated `site-packages` that `pip3` doesn't install to.

```bash
which python3
# /Applications/Xcode.app/Contents/Developer/usr/bin/python3  ← wrong one

pip3 install cryptography
# Installs to /usr/local/lib/python3.12/site-packages  ← different Python
```

## Quick Check

```bash
python3 -c "import sys; print(sys.executable)"
# If it shows Xcode path → that's the problem
```

## Fixes

1. **Use Homebrew Python explicitly**: `/usr/local/bin/python3` or `/opt/homebrew/bin/python3`
2. **Use `--break-system-packages`**: `python3 -m pip install cryptography --break-system-packages`
3. **Best: avoid Python entirely** — use Bun/Node built-in `crypto` module instead

## NamiOS Lesson

The `x-login.ts` script originally used Python for AES decryption of Chromium cookies. After this gotcha, it was rewritten in pure Bun using `bun:sqlite` + `crypto` (Node built-in). Zero external dependencies.

## Rule of Thumb

On macOS, never assume `python3` resolves to the Python you expect. For tools that spawn Python subprocesses, prefer native alternatives (`bun:sqlite`, Node `crypto`) when possible.
