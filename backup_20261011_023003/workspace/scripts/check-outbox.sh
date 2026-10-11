#!/bin/bash
# check-outbox.sh — Inventory of drafts waiting in outbox/ for publication.
#
# Problem: unfinished/delayed content drafts accumulate in outbox/ and, once a
# piece falls off the blockers list, nothing surfaces it again — a draft can sit
# forgotten for days (e.g. outbox/eco-2026-09-25-*.html was untracked for 6d
# while only the older 09-21 draft was in blockers.md).
#
# This script lists every draft still sitting in outbox/, its age, and the
# intended publish date encoded in the filename (eco-YYYY-MM-DD-*.html), and
# flags drafts whose intended date has passed by more than the threshold.
#
# Usage:
#   bash scripts/check-outbox.sh            # flag drafts >3 days overdue
#   bash scripts/check-outbox.sh --days N   # custom overdue threshold (days)
#   bash scripts/check-outbox.sh --quiet    # only print when something is pending
#
# Exit codes (informational — never fails a cron run):
#   0 = outbox empty / all drafts within threshold
#   1 = at least one draft overdue (intended publish date passed)   (informational)
#
# Not wired into health-quick-check.sh on purpose (would be daily noise); it is
# surfaced by daily-improve-context.sh so the daily agent sees it each morning.

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTBOX_DIR="$WORKSPACE_DIR/outbox"
THRESHOLD_DAYS=3
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --days) THRESHOLD_DAYS="${2:-3}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) shift ;;
  esac
done
case "$THRESHOLD_DAYS" in (*[!0-9]*|'') THRESHOLD_DAYS=3 ;; esac

[ -d "$OUTBOX_DIR" ] || exit 0

NOW=$(date -u +%s)
TODAY=$(date -u +%Y-%m-%d)
PENDING=0
OVERDUE=0

# Drafts = regular files matching *.html / *.md (ignore hidden + dirs).
PENDING_LIST=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  base=$(basename "$f")
  case "$base" in .*) continue ;; esac
  PENDING=$((PENDING + 1))

  # Intended publish date from an eco-YYYY-MM-DD-* filename, else file mtime.
  intended=$(printf '%s' "$base" | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1 || true)
  age_days=$(( (NOW - $(date -u -r "$f" +%s 2>/dev/null || echo "$NOW")) / 86400 ))
  if [ -n "$intended" ]; then
    intended_epoch=$(date -u -d "$intended" +%s 2>/dev/null || echo "$NOW")
    overdue_days=$(( (NOW - intended_epoch) / 86400 ))
    date_note="intended $intended"
  else
    overdue_days=$age_days
    date_note="no date in filename (age ${age_days}d)"
  fi

  if [ "$overdue_days" -gt "$THRESHOLD_DAYS" ]; then
    OVERDUE=$((OVERDUE + 1))
    PENDING_LIST="${PENDING_LIST}⏳ ${base} — ${date_note}, overdue ${overdue_days}d
"
  else
    PENDING_LIST="${PENDING_LIST}•  ${base} — ${date_note}
"
  fi
done < <(find "$OUTBOX_DIR" -maxdepth 1 -type f \( -name '*.html' -o -name '*.md' \) 2>/dev/null | sort)

if [ "$PENDING" -eq 0 ]; then
  [ "$QUIET" = 1 ] || echo "✅ Outbox empty"
  exit 0
fi

if [ "$QUIET" = 1 ] && [ "$OVERDUE" -eq 0 ]; then
  exit 0
fi

echo "── Outbox: ${PENDING} draft(s) pending publication, ${OVERDUE} overdue (>${THRESHOLD_DAYS}d) ──"
printf '%s' "$PENDING_LIST"
[ "$OVERDUE" -gt 0 ] && echo "→ Blocked drafts also appear under open blockers; publish or archive once WP access is restored."

[ "$OVERDUE" -gt 0 ] && exit 1
exit 0
