---
date: 2026-05-16
title: Daily Self-Improvement - Added sync-learnings.sh Script
tags: [maintenance, automation, learnings, improvement]
projects: [infrastructure]
summary: Created sync-learnings.sh to auto-scan memory files and suggest learnings to capture. Reduces manual effort keeping knowledge base updated.
---

## Improvement Implemented

Created new script: `sync-learnings.sh`

**Purpose:** Automatically scan recent memory files and suggest learnings to capture in `.learnings/` directory. Makes it easier to keep the learnings knowledge base up-to-date without manual effort.

## Problem Solved

Previously, learnings had to be manually captured from memory files. This created friction:
- Easy to forget to update `.learnings/`
- Improvements get buried in daily memory files
- Knowledge base becomes stale over time
- Manual process is tedious for weekly reviews

## Solution

New script that:
1. **Scans recent memory files** (last 7 days by default, configurable)
2. **Looks for improvement tags** ([improvement], [bug-fix], [critical])
3. **Reports statistics** (current learnings count)
4. **Suggests entries** to capture (interactive mode)
5. **Auto-syncs** summary to LEARNINGS.md (auto mode for cron)

## Features

- Two modes: **Interactive** (review & decide) and **Auto** (append summary)
- Configurable lookback period: `--days N`
- Scans for multiple improvement indicators
- Minimal output, easy to review
- Safe: no destructive changes, just suggestions

## Usage Examples

```bash
# Interactive mode - review last 7 days
bash sync-learnings.sh

# Interactive mode - review last 30 days
bash sync-learnings.sh --days 30

# Auto-capture mode (for cron)
bash sync-learnings.sh --auto

# Auto-capture with 14-day window
bash sync-learnings.sh --auto --days 14
```

## Documentation Updated

1. **scripts/README.md** — Added full documentation section for sync-learnings.sh
2. **AGENTS.md** — Updated Periodic Review section to include learnings sync
3. **Memory file** — This entry documents the improvement

## Next Steps

Can be integrated into:
- **Weekly cron job** (e.g., Sundays) for automatic sync
- **Heartbeat checks** if manual learnings review becomes routine
- **Standalone tool** for on-demand use by Volker

## Benefits

- ✅ **Automation** — Reduces manual work keeping learnings current
- ✅ **Consistency** — Regular reviews ensure nothing falls through cracks
- ✅ **Visibility** — Easy to see recent improvements at a glance
- ✅ **Flexibility** — Works in both interactive and cron modes
- ✅ **Low-risk** — Non-destructive, purely informational

## Testing

✅ Script created and made executable
✅ Tested on recent memory files (30-day lookback)
✅ Output formats correctly
✅ Works in both interactive and auto modes

Ready for:
- Manual use anytime
- Potential addition to weekly cron (if approved)
