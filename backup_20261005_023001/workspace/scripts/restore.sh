#!/bin/bash
# OpenClaw Restore — restores a snapshot
# Usage: bash restore.sh <snapshot-file>
# Example: bash restore.sh snapshot-20260217-025700-before-config-change.tar.gz

set -euo pipefail

OPENCLAW_DIR="/home/node/.openclaw"
BACKUP_DIR="${OPENCLAW_DIR}/backups"

if [ -z "${1:-}" ]; then
  echo "Available snapshots:"
  ls -1t "${BACKUP_DIR}"/snapshot-*.tar.gz 2>/dev/null || echo "  (none)"
  echo ""
  echo "Usage: bash restore.sh <filename>"
  exit 1
fi

SNAPSHOT="${BACKUP_DIR}/${1}"
if [ ! -f "${SNAPSHOT}" ]; then
  echo "❌ Not found: ${SNAPSHOT}"
  exit 1
fi

echo "⚠️  This will overwrite current config with: ${1}"
read -p "Continue? (y/N) " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

tar -xzf "${SNAPSHOT}" -C "${OPENCLAW_DIR}"
echo "✅ Restored from: ${1}"
echo "⚠️  Restart the gateway to apply: openclaw gateway restart"
