#!/usr/bin/env python3
#
# update-memory-index.py — Auto-rebuild the "Daily Logs" section of memory/index.md
# from the actual daily memory files on disk.
#
# Why: index.md was maintained by hand and went stale (120+ daily logs, only 2 listed).
# This makes the index self-maintaining — run it from the daily heartbeat or after any
# session that creates daily logs.
#
# Scope: replaces everything between the AUTO:DAILY-LOGS markers (or inserts the block
# if missing) and refreshes the frontmatter `date:`. All other prose is untouched.
#
# Usage: scripts/update-memory-index.py [--dry-run]

import os
import re
import sys
from datetime import datetime, timezone

WORKSPACE = "/home/node/.openclaw/workspace"
INDEX = os.path.join(WORKSPACE, "memory", "index.md")
MEMORY_DIR = os.path.join(WORKSPACE, "memory")

DRY_RUN = "--dry-run" in sys.argv

if not os.path.isfile(INDEX):
    print(f"ERROR: {INDEX} not found", file=sys.stderr)
    sys.exit(1)

# Excluded non-daily files.
EXCLUDE = {
    "index.md", "template.md", "dashboard-plan.md",
    "promoted-memory-archive.md", "self-improvement-log.md",
}

files = sorted(
    f for f in os.listdir(MEMORY_DIR)
    if f.endswith(".md")
    and re.match(r"^\d{4}-\d{2}-\d{2}", f)
    and f not in EXCLUDE
)

if not files:
    print("WARNING: no daily log files found; leaving index untouched.", file=sys.stderr)
    sys.exit(0)

lines = [
    "<!-- AUTO:DAILY-LOGS START -->",
    "## Daily Logs",
    "",
]
lines += [f"- [{f[:-3]}](./memory/{f})" for f in files]
lines += ["", "<!-- AUTO:DAILY-LOGS END -->"]
block = "\n".join(lines)

with open(INDEX, "r", encoding="utf-8") as fh:
    content = fh.read()

start_marker = "<!-- AUTO:DAILY-LOGS START -->"
end_marker = "<!-- AUTO:DAILY-LOGS END -->"

if start_marker in content and end_marker in content:
    new_content = re.sub(
        re.escape(start_marker) + r".*?" + re.escape(end_marker),
        block,
        content,
        flags=re.DOTALL,
    )
elif start_marker in content or end_marker in content:
    print("ERROR: index has only one AUTO:DAILY-LOGS marker; fix manually.", file=sys.stderr)
    sys.exit(1)
else:
    # No markers yet: insert block before "## How to Use", or append if absent.
    howto = "## How to Use"
    if howto in content:
        new_content = content.replace(
            howto, f"{block}\n\n{howto}", 1
        )
    else:
        new_content = content.rstrip("\n") + "\n\n" + block + "\n"

# Refresh the frontmatter `date:` field (only if it currently has a YYYY-MM-DD value).
today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
new_content, n_date = re.subn(
    r"^(date: )\d{4}-\d{2}-\d{2}\s*$",
    rf"\g<1>{today}",
    new_content,
    count=1,
    flags=re.MULTILINE,
)

if DRY_RUN:
    print(f"DRY-RUN: would update {INDEX} with {len(files)} daily logs "
          f"({'date refreshed' if n_date else 'date untouched'})")
    sys.exit(0)

with open(INDEX, "w", encoding="utf-8") as fh:
    fh.write(new_content)

print(f"Memory index updated: {len(files)} daily logs listed "
      f"({'date refreshed' if n_date else 'date untouched'})")