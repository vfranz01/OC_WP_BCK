#!/bin/bash
# Sync Learnings — Auto-scan recent memory files and surface learnings to capture
# Purpose: Review daily memory logs and extract improvements/issues for .learnings/
# Usage: bash sync-learnings.sh [--auto] [--days N]
#
# --auto    = Auto-capture candidates into LEARNINGS.md (deduped, one section/day)
# --days N  = Look back N days (default: 7)
#
# 2026-09-11: Rewritten. The old version grepped for '^- \*\*2026' and
# '[improvement]' tags that no daily file ever used, so --auto reported
# "no substantial learnings" every run despite real fixes in the files.
# Now matches actual fix/bug/error language with word boundaries, shows
# file:line context, and dedupes against LEARNINGS.md before appending.

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_DIR="$WORKSPACE_DIR/memory"
LEARNINGS_DIR="$WORKSPACE_DIR/.learnings"
LEARNINGS_FILE="$LEARNINGS_DIR/LEARNINGS.md"
AUTO_MODE=false
DAYS_BACK=7
TODAY="$(date -u +%F)"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --auto) AUTO_MODE=true; shift ;;
    --days) DAYS_BACK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Ensure directories exist
mkdir -p "$LEARNINGS_DIR"

echo "🧠 Syncing Recent Learnings..."
echo "   Looking back $DAYS_BACK days"
echo ""

# Find recent daily memory files (year-agnostic YYYY-MM-DD.md, -mtime is
# inclusive of today so today's fresh file is still scanned).
RECENT_FILES=$(find "$MEMORY_DIR" -maxdepth 1 \
  -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" -type f \
  -mtime -$((DAYS_BACK + 1)) 2>/dev/null | sort -r | head -20)

if [ -z "$RECENT_FILES" ]; then
  echo "ℹ️  No recent memory files found (within $DAYS_BACK days)"
  exit 0
fi

echo "📄 Files to scan:"
while IFS= read -r f; do echo "   - $(basename "$f")"; done <<< "$RECENT_FILES"
echo ""

# Signal lines: fixed/fixes/repair/harden + bug/error/crash/lesson language.
# Word boundaries, case-insensitive, strips markdown emphasis for readability.
SIGNAL_RE='(^|[^A-Za-z])(fixed|fixes|fix|repaired|hardened|bug|bugfix|workaround|root cause|lesson|learned|fails?|broke|crash)([^A-Za-z]|$)'

# Recent sections of the self-improvement log carry most of the substance
# (daily files are often just status stubs), so scan them too.
CUTOFF=$(date -u -d "-$DAYS_BACK days" +%F 2>/dev/null || date -u +%F)
RECENT_LOG=""
if [ -f "$MEMORY_DIR/self-improvement-log.md" ]; then
  RECENT_LOG=$(awk -v cutoff="$CUTOFF" '
    /^## / { inr = ($0 ~ /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ && substr($0,4,10) >= cutoff) }
    inr { print }
  ' "$MEMORY_DIR/self-improvement-log.md")
fi

FINDINGS=$( { grep -HiE "$SIGNAL_RE" $RECENT_FILES 2>/dev/null; \
               printf '%s\n' "$RECENT_LOG" | grep -iE "$SIGNAL_RE" 2>/dev/null; } \
  | sed -E 's/\*\*//g; s/^([^:]+):[0-9]+:/\1: /; s|^\s*##+\s*||; s|/home/node/.openclaw/workspace/||g' \
  | sed -E 's/^\s+//' | awk 'length($0) < 240' \
  | sort -u | head -40)

if [ -n "$FINDINGS" ]; then
  echo "## Signal lines found:"
  printf '%s\n' "$FINDINGS" | head -25
else
  echo "## Signal lines found:"
  echo "   (none)"
fi
echo ""

# Count current learnings
LEARNINGS_COUNT=$(grep -c "^- " "$LEARNINGS_FILE" 2>/dev/null || echo 0)
ERRORS_COUNT=$(grep -c "^- " "$LEARNINGS_DIR/ERRORS.md" 2>/dev/null || echo 0)

echo "📊 Current Status:"
echo "   - LEARNINGS.md: $LEARNINGS_COUNT entries"
echo "   - ERRORS.md: $ERRORS_COUNT entries"
echo ""

if [ "$AUTO_MODE" != true ]; then
  echo "💡 To capture learnings:"
  echo "   1. Review findings above"
  echo "   2. Edit: $LEARNINGS_DIR/LEARNINGS.md"
  echo "   3. Or run: bash $0 --auto"
  echo ""
fi

# Auto-capture: append today's candidate list to LEARNINGS.md once per day,
# skipping lines already present (case-insensitive) to avoid duplicate noise.
if [ "$AUTO_MODE" = true ]; then
  if ! [ -f "$LEARNINGS_FILE" ]; then
    printf '# Learnings\n\nCorrections, knowledge gaps, and best practices discovered during sessions.\n\n' > "$LEARNINGS_FILE"
  fi

  if grep -qF "## $TODAY — Auto-synced candidates" "$LEARNINGS_FILE"; then
    echo "ℹ️  Auto-sync for $TODAY already present — nothing appended"
    exit 0
  fi

  if [ -z "$FINDINGS" ]; then
    echo "ℹ️  No substantial learnings found to auto-capture"
    exit 0
  fi

  # Dedupe: skip lines whose 40-char fingerprint already exists in LEARNINGS.md
  DEDUPED=$(printf '%s\n' "$FINDINGS" | while IFS= read -r line; do
    fp="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]' | tr -s ' ' | cut -c1-40)"
    if ! grep -qiF "$fp" "$LEARNINGS_FILE"; then
      printf -- '- %s\n' "$line"
    fi
  done)

  if [ -z "$DEDUPED" ]; then
    echo "ℹ️  All candidate lines already captured in LEARNINGS.md"
    exit 0
  fi

  {
    echo ""
    echo "## $TODAY — Auto-synced candidates from memory"
    echo "Scanned $DAYS_BACK days of daily memory files. Review and distill:"
    echo "$DEDUPED"
  } >> "$LEARNINGS_FILE"

  echo "✅ Auto-synced: appended candidates to LEARNINGS.md"
fi

echo "✅ Sync complete"
