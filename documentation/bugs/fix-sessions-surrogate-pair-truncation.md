---
type: gotcha
project: namios
created: 2026-03-05
last_verified: 2026-03-05
tags: [unicode, json, swift, sessions]
---

# JavaScript String.slice() Cuts Emoji Surrogate Pairs

## Symptom
Sessions tab shows "No Conversations Yet" on both iOS and macOS, despite server having 336+ sessions. No visible error in UI.

## Root Cause
`SessionStore.toMeta()` used `last.content.slice(0, 100)` to truncate `lastMessage`. JavaScript strings are UTF-16 — emojis like 🌊 are two code units (high surrogate + low surrogate). When `slice()` cuts between them, it leaves a lone high surrogate (e.g. `\uD83D`).

Swift's `JSONDecoder` (via `NSJSONSerialization`) is strict about Unicode conformance — a lone surrogate makes the **entire JSON** invalid, not just the affected field. All 336 sessions fail to decode.

Python's `json.loads()` and most other JSON parsers accept lone surrogates, so `curl` tests pass while the app fails silently.

## Fix
Added `safeSlice()` to `SessionStore` that checks if the last character is a high surrogate (`0xD800-0xDBFF`) and backs off by one:

```ts
private safeSlice(str: string, maxLen: number): string {
  if (str.length <= maxLen) return str;
  const code = str.charCodeAt(maxLen - 1);
  const end = (code >= 0xD800 && code <= 0xDBFF) ? maxLen - 1 : maxLen;
  return str.slice(0, end);
}
```

Applied in two places:
- `toMeta()` → `lastMessage` truncation
- `appendMessage()` → auto-title from first user message

## Prevention
- **Server**: Always use `safeSlice()` (or `Array.from(str).slice()`) when truncating user content that may contain emoji
- **Client**: Added error banner to `SessionListView` so decode errors are visible instead of silently showing empty state

## Detection
Test: `swift -e 'try JSONDecoder().decode(...)'` against the API response. The error message "Missing low code point in surrogate pair" pinpoints the issue.
