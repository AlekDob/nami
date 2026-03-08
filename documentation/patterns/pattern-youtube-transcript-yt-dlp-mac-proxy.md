---
type: pattern
project: namios
created: 2026-03-08
last_verified: 2026-03-08
tags: [youtube, yt-dlp, mac-agent, proxy, datacenter-ip, transcript]
---
# YouTube Transcript via yt-dlp + Mac Agent Proxy

## Problem

YouTube blocks transcript/subtitle extraction from datacenter IPs (Hetzner, AWS, etc.). Multiple npm libraries (`youtube-transcript`, `youtube-transcript-plus`) fail from server due to:
1. IP-based blocking on watch page / Innertube API
2. Mac agent `exec` endpoint has `maxBuffer` limit (1MB default) — YouTube pages are ~1.4MB
3. Shell escaping hell when proxying POST requests with JSON bodies through curl

## Solution

Run `yt-dlp` on the Mac (residential IP) via the Mac agent's `osascript` command. Reuses the same Python extraction script as the Quack `youtube-transcript` skill.

### Architecture

```
Nami Server (Hetzner) → Mac Agent (Tailscale) → yt-dlp (local) → YouTube
     ↓                       ↓
  youtubeTranscript      osascript -e 'do shell script
  tool (AI SDK)            "python3 extract_transcript.py URL"'
```

### Key Implementation Details

1. **yt-dlp path**: Must use full path `/opt/homebrew/bin/yt-dlp` because `osascript`'s `do shell script` uses a minimal `PATH` that doesn't include Homebrew
2. **PATH injection**: `PATH=/opt/homebrew/bin:/usr/bin:/bin python3 script.py` ensures both yt-dlp and python3 are found
3. **Script location**: `/Users/alekdob/.claude/skills/youtube-transcript/scripts/extract_transcript.py` — shared with Quack skill
4. **Output**: JSON to stdout with title, channel, duration, chapters, transcript segments, available languages
5. **Timeout**: 60 seconds (yt-dlp needs ~10-30s for metadata + subtitle download)

### What Didn't Work

| Approach | Why it failed |
|----------|--------------|
| `youtube-transcript` npm | Unmaintained, returns 0 segments for all videos |
| `youtube-transcript-plus` direct | Blocked by datacenter IP |
| `youtube-transcript-plus` + curl proxy | Mac agent maxBuffer overflow (1.4MB page), POST body escaping issues |
| Innertube `get_transcript` API | FAILED_PRECONDITION error |
| Timedtext XML URLs | Return empty body even with cookies |
| Temp file + `/file` endpoint proxy | Works for GET but POST body via heredoc/base64 unreliable through nested exec |

### What Works

`yt-dlp` via `osascript` through Mac agent — single command, no proxying of individual HTTP requests, no maxBuffer issues (JSON output is small), no escaping problems.

## Files

- `src/tools/youtube.ts` — Nami server tool (calls Mac agent)
- `~/.claude/skills/youtube-transcript/scripts/extract_transcript.py` — Python extraction script (shared with Quack)
- `/Users/alekdob/nami-agent/server.js` — Mac agent (maxBuffer bumped to 5MB)

## Related

- `pattern-mac-remote-access-tailscale-agent.md` — Mac agent setup
- `reddit-datacenter-ip-block` memory entry — same IP blocking pattern
- Quack `youtube-transcript` skill — same Python script, runs locally
