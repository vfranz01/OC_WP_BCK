#!/bin/bash
# OpenClaw Snapshot — creates a timestamped backup of all critical files
# Usage: bash snapshot.sh [label]
# Example: bash snapshot.sh "before-config-change"

set -euo pipefail

OPENCLAW_DIR="/home/node/.openclaw"
BACKUP_DIR="${OPENCLAW_DIR}/backups"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
LABEL="${1:-manual}"
FILENAME="snapshot-${TIMESTAMP}-${LABEL}.tar.gz"

mkdir -p "${BACKUP_DIR}"

# Critical files to back up (relative to OPENCLAW_DIR)
tar -czf "${BACKUP_DIR}/${FILENAME}" \
  -C "${OPENCLAW_DIR}" \
  openclaw.json \
  identity/ \
  devices/ \
  credentials/ \
  cron/ \
  exec-approvals.json \
  workspace/AGENTS.md \
  workspace/SOUL.md \
  workspace/USER.md \
  workspace/IDENTITY.md \
  workspace/TOOLS.md \
  workspace/HEARTBEAT.md \
  workspace/MEMORY.md \
  workspace/memory/ \
  workspace/scripts/ \
  agents/main/sessions/sessions.json \
  2>/dev/null || true

SIZE=$(du -h "${BACKUP_DIR}/${FILENAME}" | cut -f1)
echo "✅ Snapshot: ${FILENAME} (${SIZE})"

# Keep only last 20 snapshots
cd "${BACKUP_DIR}"
ls -1t snapshot-*.tar.gz 2>/dev/null | tail -n +21 | xargs -r rm --
COUNT=$(ls -1 snapshot-*.tar.gz 2>/dev/null | wc -l)
echo "📦 ${COUNT} snapshots total"
