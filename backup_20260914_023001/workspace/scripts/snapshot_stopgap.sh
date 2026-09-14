#!/bin/bash
# Snapshot Stopgap — keeps the daily backup chain alive until the real host
# crontab (HOST-SETUP-CRON.sh, 02:30 UTC job) is installed.
#
# Background: both install paths for the daily snapshot are blocked from
# inside the container (cron tool restricted in cron sessions; no crontab on
# the gateway container). The documented stopgap was "any daily cron session
# should re-run the manual snapshot" — but that relied on a session
# remembering to do it. This script makes the stopgap automatic.
#
# Behavior:
#   - Runs snapshot.sh with the daily_auto_snapshot label ONLY if the newest
#     labeled snapshot is older than STOPGAP_MIN_HOURS (default 23h, i.e.
#     effectively once per day).
#   - Idempotent: repeated calls within the window exit 0 without snapshotting.
#   - Never fatal: designed to be called from session bootstrap / status
#     routines; failures are reported on stdout but exit 0 (a broken backup
#     must not block daily memory creation). Health check #9 still reports
#     staleness independently, so a silent failure stays visible there.
#
# Usage: bash snapshot_stopgap.sh [--hours N] [--quiet]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT_DIR="/home/node/.openclaw/backups"
SNAPSHOT_SCRIPT="$SCRIPT_DIR/snapshot.sh"
QUIET=0
MIN_HOURS="${STOPGAP_MIN_HOURS:-23}"

while [ $# -gt 0 ]; do
  case "$1" in
    --hours) MIN_HOURS="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) shift ;;
  esac
done

log() { [ "$QUIET" -eq 1 ] || echo "$*"; return 0; }

if [ ! -f "$SNAPSHOT_SCRIPT" ]; then
  log "⚠️ snapshot_stopgap: snapshot.sh not found at $SNAPSHOT_SCRIPT"
  exit 0
fi

LATEST=$(find "$SNAPSHOT_DIR" -name 'snapshot-*-daily_auto_snapshot.tar.gz' -newermt "-${MIN_HOURS} hours" 2>/dev/null | head -n1)
if [ -n "$LATEST" ]; then
  log "✅ snapshot_stopgap: fresh daily_auto_snapshot exists ($(basename "$LATEST")) — nothing to do"
  exit 0
fi

log "🔄 snapshot_stopgap: last daily_auto_snapshot is ≥${MIN_HOURS}h old — running stopgap snapshot"
if OUT=$(bash "$SNAPSHOT_SCRIPT" daily_auto_snapshot 2>&1); then
  log "$OUT"
  log "✅ snapshot_stopgap: done"
else
  log "⚠️ snapshot_stopgap: snapshot.sh failed:"
  log "$OUT"
fi
exit 0
