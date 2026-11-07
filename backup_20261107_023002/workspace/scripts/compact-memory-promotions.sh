#!/usr/bin/env bash
# Compact raw auto-promotion blocks out of MEMORY.md into an archive.
# Keeps long-term memory curated while preserving the original entries for audit/recovery.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_FILE="$WORKSPACE_DIR/MEMORY.md"
ARCHIVE_FILE="$WORKSPACE_DIR/memory/promoted-memory-archive.md"
TIMESTAMP="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
STAMP="$(date -u '+%Y%m%d%H%M%S')"
MAX_BYTES="${MAX_BYTES:-5000}"

if [ ! -f "$MEMORY_FILE" ]; then
  echo "ERROR: MEMORY.md not found: $MEMORY_FILE" >&2
  exit 1
fi

mkdir -p "$WORKSPACE_DIR/memory"

python3 - "$MEMORY_FILE" "$ARCHIVE_FILE" "$TIMESTAMP" "$STAMP" "$MAX_BYTES" <<'PY'
from pathlib import Path
import shutil
import sys

memory_path = Path(sys.argv[1])
archive_path = Path(sys.argv[2])
timestamp = sys.argv[3]
stamp = sys.argv[4]
max_bytes = int(sys.argv[5])

text = memory_path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)

start = None
for i, line in enumerate(lines):
    if line.startswith("## Promoted From Short-Term Memory"):
        start = i
        break

if start is None:
    size = len(text.encode("utf-8"))
    print(f"No auto-promotion blocks found. MEMORY.md size: {size} bytes (target: <= {max_bytes}).")
    raise SystemExit(0)

kept = lines[:start]
archived = lines[start:]

# Avoid stacking duplicate placeholders if the script is rerun after manual edits.
placeholder = (
    "\n## Archived Auto-Promotions\n"
    f"Raw auto-promoted short-term memory blocks were archived to `memory/{archive_path.name}` "
    "so MEMORY.md stays curated and under the 5000-character target. Restore only distilled learnings here.\n"
)
if not any(line.startswith("## Archived Auto-Promotions") for line in kept):
    if kept and kept[-1].strip():
        kept.append("\n")
    kept.append(placeholder)

backup_path = memory_path.with_name(f"MEMORY.pre-compact.{stamp}.bak")
shutil.copy2(memory_path, backup_path)

if archive_path.exists():
    archive_text = archive_path.read_text(encoding="utf-8")
else:
    archive_text = (
        "---\n"
        "date: 2026-06-20\n"
        "title: Archived MEMORY Auto-Promotions\n"
        "tags: [memory, archive, automation]\n"
        "projects: [infrastructure]\n"
        "summary: Raw auto-promoted MEMORY.md entries archived to keep long-term memory curated.\n"
        "---\n\n"
        "# Archived MEMORY Auto-Promotions\n\n"
        "This file preserves raw auto-promoted short-term memory blocks removed from `MEMORY.md`. "
        "Use it for audit/recovery; keep `MEMORY.md` distilled.\n"
    )

archive_text = archive_text.rstrip() + (
    f"\n\n## Archived from MEMORY.md — {timestamp}\n\n"
    f"Backup before compaction: `{backup_path.name}`\n\n"
    + "".join(archived).rstrip()
    + "\n"
)
archive_path.write_text(archive_text, encoding="utf-8")

new_text = "".join(kept)
memory_path.write_text(new_text, encoding="utf-8")

old_size = len(text.encode("utf-8"))
new_size = len(new_text.encode("utf-8"))
archive_count = sum(1 for line in archived if line.startswith("## Promoted From Short-Term Memory"))
print(f"Archived {archive_count} auto-promotion block(s).")
print(f"MEMORY.md: {old_size} -> {new_size} bytes (target: <= {max_bytes}).")
print(f"Archive: {archive_path}")
print(f"Backup: {backup_path}")
if new_size > max_bytes:
    print("NOTE: MEMORY.md is still above target; manual distillation may be needed.")
PY
