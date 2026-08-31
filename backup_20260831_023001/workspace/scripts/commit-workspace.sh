#!/bin/bash
# commit-workspace.sh — Safe git commit of workspace docs & memory.
#
# AGENTS.md says "commit and push your own changes" is valid proactive work, but
# there was no single safe command for it. This script bridges that gap:
#   • Stages ONLY workspace documentation + memory + scripts
#   • NEVER touches credentials, openclaw.json, devices/, identities, *.bak
#   • Creates the commit only when there is something to commit
#   • Human-readable message summarizing what changed
#
# Usage:  bash scripts/commit-workspace.sh ["optional message"]
# Exit:   0 = committed (or nothing to do), 1 = error

set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"

# Repo must exist; bail quietly if this isn't a git checkout.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "⚠️  Not a git repo — skipping workspace commit."
  exit 0
fi

# Explicit allow-list of paths we are allowed to commit. Anything outside these
# (secrets, backups, node state) stays out of the commit by construction.
ALLOW_PATHS=(
  "AGENTS.md"
  "SOUL.md"
  "USER.md"
  "IDENTITY.md"
  "TOOLS.md"
  "MEMORY.md"
  "DREAMS.md"
  "HEARTBEAT.md"
  "SKILLS.md"
  "PROJECT_STATUS.md"
  "memory/"
  "scripts/"
  ".learnings/"
  ".gitignore"
)

# Reset index safety: unstage everything first so we never pick up pre-existing /
# unrelated staged content.
git reset -q 2>/dev/null || true

# NOTE: .gitignore already excludes `*.bak` and `memory/.backups/`, so no extra
# exclude pathspecs are passed here. Passing `:(exclude)` pathspecs alongside a
# directory pathspec makes plain `git add` SILENTLY SKIP untracked files under
# that directory (git quirk) — which is why daily memory logs were never staged.
# `git add -A -- <path>` avoids the quirk entirely.

staged_any=0
for p in "${ALLOW_PATHS[@]}"; do
  # Stage only if the path exists (protects against typos).
  if [ -e "$p" ]; then
    if git add -A -- "$p" 2>/dev/null; then
      staged_any=1
    fi
  fi
done

# Reject accidental .bak / secret files that might have slipped through.
if [ "$(git diff --cached --name-only | grep -Ec '(openclaw\.json|credentials/|devices/|identity/)' || true)" -gt 0 ]; then
  echo "❌ Refusing commit: sensitive/backup path staged. Aborting."
  git reset -q
  exit 1
fi

if [ "$staged_any" -eq 0 ]; then
  echo "ℹ️  Nothing to commit."
  exit 0
fi

if git diff --cached --quiet; then
  echo "ℹ️  No changes staged — nothing to commit."
  exit 0
fi

MESSAGE="${1:-chore: workspace docs & memory sync}"
git commit -q -m "$MESSAGE"

echo "✅ Committed workspace changes:"
git show --stat --oneline HEAD | head -20
exit 0