---
type: gotcha
project: namios
date: 2026-02-16
tags: [systemd, deployment, cron, duplicate, server]
---

# Gotcha: Duplicate Systemd Services Running Same Codebase

## The Trap
During the NamiOS rebrand (meow → nami), a new `nami.service` was created alongside the existing `meow.service`. Both were enabled and active, both executing the identical entry point (`bun run src/bin.ts`).

## Why It's Dangerous
- Both processes load the same `jobs.json` → cron jobs fire from **both** processes
- Both initialize APNs → push notifications sent **twice** per event
- Only one can bind to port 3000 (the first wins). The second sees "API server already running" and skips API, but still runs the scheduler
- Doubles memory usage on a 4GB server

## How to Detect
```bash
# Check for multiple bun processes
ps aux | grep 'bun run src/bin' | grep -v grep | wc -l
# Should be 1, not 2

# Check both services
systemctl is-active meow nami
# Only one should be "active"
```

## Fix
```bash
systemctl stop meow && systemctl disable meow
# Keep only nami.service
```

## Prevention
When renaming a systemd service:
1. Disable the old service BEFORE enabling the new one
2. Verify with `systemctl list-units --type=service | grep -E 'meow|nami'`
3. Check process count after reboot

## Trigger
Any service rename or migration where old and new `.service` files coexist.
