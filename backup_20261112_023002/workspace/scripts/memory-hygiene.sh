#!/usr/bin/env bash
# memory-hygiene.sh
# Keeps memory/ free of stale artifacts: .bak/.tmp/.old/.orig backups and test
# leftovers (test.txt, test_write.txt, etc.) that accumulate for months, bloat
# snapshots/backups, and add noise to every directory listing.
#
# Safety: NEVER deletes. Report mode (default) only lists. Apply mode moves
# stale files to memory/archive/ (created on demand), preserving names.
# Only scans the top level of memory/ — subdirectories (dreaming/, security/,
# archive/) are left alone. Active state/logs (.log, *.state, *.json) are
# never touched.
#
# Usage:
#   bash scripts/memory-hygiene.sh           # report mode (exit 1 if stale found)
#   bash scripts/memory-hygiene.sh --apply   # archive stale files
#   STALE_DAYS=14 bash scripts/memory-hygiene.sh --apply
#
# Exit codes: 0 = clean (or applied), 1 = stale files found (report mode), 2 = error

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MEM_DIR="$WORKSPACE_DIR/memory"
ARCHIVE_DIR="$MEM_DIR/archive"
STALE_DAYS="${STALE_DAYS:-30}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

[ -d "$MEM_DIR" ] || { echo "memory/ not found: $MEM_DIR"; exit 2; }

# Extensions/patterns considered disposable artifacts
ARTIFACT_PATTERNS=("*.bak" "*.tmp" "*.old" "*.orig" "*~")
# Known one-off test leftovers (safe to archive once older than STALE_DAYS)
TEST_FILES=("test.txt" "test_write.txt")

if [ "$APPLY" -eq 1 ]; then
  mkdir -p "$ARCHIVE_DIR"
fi

now=$(date +%s)
stale=0
moved=0

is_stale() { # $1=file  -> 0 if older than STALE_DAYS
  local f=$1 m
  m=$(stat -c '%Y' "$f" 2>/dev/null || echo "$now")
  (( now - m >= STALE_DAYS * 86400 ))
}

for f in "$MEM_DIR"/*; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  match=0
  for pat in "${ARTIFACT_PATTERNS[@]}"; do
    # shellcheck disable=SC2254
    case "$name" in $pat) match=1; break;; esac
  done
  for t in "${TEST_FILES[@]}"; do
    [ "$name" = "$t" ] && match=1
  done
  [ "$match" -eq 1 ] || continue
  is_stale "$f" || continue
  stale=$((stale+1))
  if [ "$APPLY" -eq 1 ]; then
    if mv -n "$f" "$ARCHIVE_DIR/"; then
      echo "📦 archived: $name"
      moved=$((moved+1))
    else
      echo "⚠️  failed to move: $name" >&2
    fi
  else
    echo "⏳ stale artifact: $name"
  fi
done

if [ "$APPLY" -eq 1 ]; then
  echo "✅ memory-hygiene: archived $moved of $stale stale file(s) → memory/archive/"
  exit 0
fi

if [ "$stale" -eq 0 ]; then
  echo "✅ memory-hygiene: clean — no stale artifacts in memory/"
  exit 0
fi

echo "ℹ️  memory-hygiene: $stale stale artifact(s) found (run with --apply to archive them)"
exit 1
