---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [chromium, cookies, aes, encryption, playwright]
---

# Chromium AES-CBC Cookie Decryption — First Block Garbage

## Symptom

After decrypting Chromium cookies with `AES-128-CBC` using IV `Buffer.alloc(16, ' ')`, the first ~16 bytes of each cookie value are garbled (non-printable Unicode chars). The rest of the value is correct.

Example: `auth_token` decrypts to `�y&Tu��#yZ�MjePc=�Z���l��d}ޤb75183fad691e9f2801fe9242e7146d8dac8dc56` — the real value starts after the garbage.

## Root Cause

AES-CBC XORs the first plaintext block with the IV before encryption. The documented IV for Chromium macOS cookies is 16 space chars (`0x20`), but some browser builds (Dia, possibly newer Chrome) use a different IV internally. Since only the first block depends on the IV, only the first 16 bytes of plaintext are corrupted. All subsequent blocks decrypt correctly because CBC chains from ciphertext blocks, not the IV.

## Key Observations

- 16 raw bytes = 27 UTF-8 chars (multi-byte encoding inflates the count)
- All cookies from the same browser have **identical garbage prefix** (same IV mismatch)
- Different browsers produce different garbage (different IVs)
- Playwright's `storageState` rejects cookies with non-printable chars → `Protocol error: Invalid cookie fields`

## Fix

Strip leading non-printable/non-ASCII chars. Cookie values are always printable ASCII (hex tokens, URL-encoded strings, base64):

```typescript
function decryptCookie(enc: Uint8Array, key: Buffer): string {
  const buf = Buffer.alloc(enc.length);
  for (let i = 0; i < enc.length; i++) buf[i] = enc[i];

  if (buf.length > 3 && buf.slice(0, 3).toString('ascii') === 'v10') {
    const iv = Buffer.alloc(16, ' ');
    const decipher = createDecipheriv('aes-128-cbc', key, iv);
    const raw = Buffer.concat([
      decipher.update(buf.slice(3)),
      decipher.final(),
    ]);
    const str = raw.toString('utf-8');

    // Find where printable ASCII starts
    for (let i = 0; i < str.length; i++) {
      const rest = str.slice(i);
      if ([...rest].every((c) => {
        const code = c.charCodeAt(0);
        return code >= 32 && code < 127;
      })) {
        return rest;
      }
    }
    return str;
  }
  return buf.toString('utf-8');
}
```

## Also Important

- `Buffer.from(Uint8Array)` in Bun may share the underlying `ArrayBuffer` — always copy byte-by-byte into a fresh `Buffer.alloc()`
- `expires: -1` (session cookies) is valid for Playwright `storageState` but was initially suspected as the cause — it's not

## Related

- `documentation/patterns/pattern-chromium-cookie-extraction-bun-sqlite.md`
- `documentation/gotchas/gotcha-x-twitter-blocks-playwright-chromium.md`
