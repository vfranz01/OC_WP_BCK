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

# Reject compiled Python artifacts: .gitignore already excludes __pycache__/ and
# *.pyc, but a tracked/previously added .pyc kept showing up as "modified" in
# every daily snapshot (binary noise in history). If one ever gets staged again
# (e.g. via explicit git add -f), refuse instead of committing binary garbage.
# Deletions are allowed (untracking a stray .pyc is exactly the cleanup we want).
PYC_STAGED=()
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue            # skip deletions
  case "$f" in
    *_pycache__/*|*.pyc) PYC_STAGED+=("$f") ;;
  esac
done < <(git diff --cached --name-only -z)

if [ "${#PYC_STAGED[@]}" -gt 0 ]; then
  echo "❌ Refusing commit: compiled Python artifact (.pyc / __pycache__) staged. Aborting:"
  printf '   - %s\n' "${PYC_STAGED[@]}"
  echo "   Untrack it with: git rm --cached <file>  (or delete the file)"
  git reset -q
  exit 1
fi

# Secret content scan: refuse commits that would push credential material into
# git history. TOOLS.md is the documented exception (stores API keys by design)
# and gets a loud warning instead, so shipping it is a deliberate choice.
SECRET_PATTERNS=(
  'ck_[a-f0-9]{32}'              # WooCommerce consumer key
  'cs_[a-f0-9]{32}'              # WooCommerce consumer secret
  'ghp_[A-Za-z0-9]{36}'          # GitHub personal access token
  'github_pat_[A-Za-z0-9_]{22,}' # GitHub fine-grained PAT
  'AKIA[0-9A-Z]{16}'             # AWS access key id
  'sk_live_[A-Za-z0-9]{16,}'     # Stripe live secret key
  'sk-[A-Za-z0-9]{20,}'          # OpenAI-style secret key
  'xox[baprs]-[A-Za-z0-9-]{10,}' # Slack tokens
  '-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----'
)

DETECTED=()
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue            # skip deletions
  [ "$f" = "TOOLS.md" ] && continue # documented key location → warned below
  for pat in "${SECRET_PATTERNS[@]}"; do
    if grep -qE "$pat" "$f" 2>/dev/null; then
      DETECTED+=("$f (matches: $pat)")
      break
    fi
  done
done < <(git diff --cached --name-only -z)

if [ "${#DETECTED[@]}" -gt 0 ]; then
  echo "❌ Refusing commit: staged files contain credential patterns:"
  printf '   - %s\n' "${DETECTED[@]}"
  echo "   Remove the secrets first, or commit deliberately with: git add <file> && git commit"
  git reset -q
  exit 1
fi

if git diff --cached --name-only | grep -qx 'TOOLS.md'; then
  echo "⚠️  NOTE: TOOLS.md (documented API-key location) is staged — verify this is intended."
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