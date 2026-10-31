#!/usr/bin/env bash
# sync-agents-improvements.sh — Keep AGENTS.md's "Recent Improvements" list in
# sync with the canonical self-improvement log.
#
# Problem: memory/self-improvement-log.md is appended on every daily
# self-improvement run (via log-self-improvement.sh), but the hand-maintained
# "## Recent Improvements" list inside AGENTS.md is NOT — it silently drifts.
# Observed 2026-10-07: the list was frozen at 2026-09-28 while 7 newer log
# entries existed, and it carried a stray "^" typo on the newest bullet.
# AGENTS.md is loaded into every session, so a stale list is actively
# misleading (it hides recent automation) rather than merely missing.
#
# This mirrors the scripts/README.md drift guard (check-scripts-doc.sh,
# 2026-10-05): derive the durable summary from the single source of truth.
#
# Usage:
#   bash scripts/sync-agents-improvements.sh          # rewrite list if stale
#   bash scripts/sync-agents-improvements.sh --limit N # keep N newest (default 12)
#   bash scripts/sync-agents-improvements.sh --check   # report-only; exit 1 = drift
#
# Behavior:
#   - Parses newest `## YYYY-MM-DD — Title` entries from the log (newest first).
#   - Replaces ONLY the bullet block under "## Recent Improvements"; the
#     heading, surrounding blank lines, and all other AGENTS.md content are
#     preserved byte-for-byte.
#   - Idempotent: a synced list is a no-op (no write, exit 0).
#   - Safe: aborts without writing if the section or its bullets can't be found.
# Exit codes:
#   0 = in sync (or successfully synced)
#   1 = --check found drift
#   2 = section not found / log missing / write error (nothing modified)

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$WORKSPACE_DIR/memory/self-improvement-log.md"
AGENTS="$WORKSPACE_DIR/AGENTS.md"
LIMIT=12
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --limit) LIMIT="${2:-12}"; shift 2 ;;
    --check) CHECK=1; shift ;;
    *) shift ;;
  esac
done
case "$LIMIT" in (*[!0-9]*|'') LIMIT=12 ;; esac

[ -f "$LOG" ]    || { echo "self-improvement log not found: $LOG" >&2; exit 2; }
[ -f "$AGENTS" ] || { echo "AGENTS.md not found: $AGENTS" >&2; exit 2; }

python3 - "$LOG" "$AGENTS" "$LIMIT" "$CHECK" <<'PYEOF'
import re, sys

log_path, agents_path, limit, check = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4] == "1"

# --- Parse newest entries from the log (newest at the bottom) -------------
entries = []  # (date, title)
with open(log_path, encoding="utf-8") as fh:
    for line in fh:
        m = re.match(r"^##\s+(\d{4}-\d{2}-\d{2})\s+[—-]\s+(.*\S)\s*$", line)
        if not m:
            continue
        date, title = m.group(1), m.group(2)
        # Some entries duplicate the date inside the title
        # ("## 2026-10-05 — 2026-10-05 — Foo"); strip the redundant prefix.
        title = re.sub(r"^\d{4}-\d{2}-\d{2}\s+[—-]\s+", "", title)
        title = re.sub(r"\s+", " ", title).strip()
        entries.append((date, title))

if not entries:
    sys.stderr.write("no '## DATE — Title' entries found in log\n")
    sys.exit(2)

# newest first, stable per date (later log lines win ties)
entries = list(reversed(entries))
seen, ordered = set(), []
for date, title in entries:
    if title in seen:
        continue
    seen.add(title)
    ordered.append((date, title))
    if len(ordered) >= limit:
        break

new_bullets = [f"- **{d}:** {t}" for d, t in ordered]

# --- Locate the bullet block under "## Recent Improvements" ----------------
with open(agents_path, encoding="utf-8") as fh:
    lines = fh.read().split("\n")

heading = None
for i, line in enumerate(lines):
    if line.strip() == "## Recent Improvements":
        heading = i
        break
if heading is None:
    sys.stderr.write("'## Recent Improvements' section not found in AGENTS.md\n")
    sys.exit(2)

def is_bullet(l):
    # tolerate a stray leading '^' (observed 2026-10-07) and indentation
    return re.match(r"^\s*\^?\s*- ", l) is not None

i = heading + 1
while i < len(lines) and lines[i].strip() == "":
    i += 1
body_start = i
while i < len(lines) and is_bullet(lines[i]):
    i += 1
body_end = i

if body_start == body_end:
    sys.stderr.write("'## Recent Improvements' has no bullet list — refusing to edit\n")
    sys.exit(2)

old_bullets = lines[body_start:body_end]
drift = old_bullets != new_bullets

if check:
    if drift:
        if len(old_bullets) != len(new_bullets):
            reason = f"{len(old_bullets)} bullets vs {len(new_bullets)} expected"
        else:
            reason = "same bullet count but dates/order differ"
        print(f"AGENTS.md 'Recent Improvements' is stale "
              f"({reason}; newest log {ordered[0][0]}).")
        sys.exit(1)
    print("✅ AGENTS.md 'Recent Improvements' in sync")
    sys.exit(0)

if not drift:
    print("✅ AGENTS.md 'Recent Improvements' already in sync — no change")
    sys.exit(0)

lines[body_start:body_end] = new_bullets
with open(agents_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines))

print(f"🔧 Synced AGENTS.md 'Recent Improvements': {len(old_bullets)} → {len(new_bullets)} bullets "
      f"(newest {ordered[0][0]}: {ordered[0][1][:60]})")
PYEOF
