#!/bin/bash
# publish-outbox.sh — Publish queued outbox/ drafts to the WordPress REST API.
#
# Problem: blog drafts accumulate in outbox/ (see check-outbox.sh) and their
# publication is blocked whenever WP auth is broken. Once credentials work
# again, publishing the backlog meant hand-writing REST calls per draft —
# error-prone, and easy to put off (backlog reached 3 drafts / 22 days).
# This closes the loop: one command drains the whole outbox safely.
#
# Draft formats supported:
#   *.json  — full WP REST payload (title/content/status/categories/meta),
#             as produced by the blog-post generators.
#   *.html  — raw HTML body; title derived from first <h1>/<h2>, else filename.
#   *.md    — markdown body; title from first heading, else filename.
#
# Safety model (IMPORTANT):
#   * DRY-RUN IS THE DEFAULT. Without --publish nothing leaves the machine.
#   * Without WP credentials the script refuses to run in publish mode and
#     tells you exactly which env vars are missing — it never falls back to
#     a different auth source silently.
#   * Drafts are never deleted: successful ones move to outbox/published/
#     (dated prefix), and every attempt is logged to memory/outbox-publish.log
#     with the returned post URL, so a retry can never silently double-publish.
#
# Credentials (env, application password style):
#   WP_BASE_URL       default https://digital.ecomunivers.com
#   WP_USER           WordPress username
#   WP_APP_PASSWORD   WordPress application password (NOT the login password)
#
# Usage:
#   bash scripts/publish-outbox.sh                 # dry-run: list what would be sent
#   bash scripts/publish-outbox.sh --publish       # publish ALL pending drafts
#   bash scripts/publish-outbox.sh --publish --file 'eco-2026-09-25-*.html'
#   bash scripts/publish-outbox.sh --status draft  # publish as drafts (WP-side review)
#
# Exit codes:
#   0 = dry-run done / nothing pending / all published
#   1 = at least one draft failed to publish (draft stays in outbox/)
#   2 = usage error
#   3 = publish mode requested but credentials missing
#
# Integration: surfaced by check-outbox.sh; run manually once WP access is
# restored (blocked since 2026-09-20, see memory/blockers.md).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTBOX_DIR="$WORKSPACE_DIR/outbox"
PUBLISHED_DIR="$OUTBOX_DIR/published"
LOG_FILE="$WORKSPACE_DIR/memory/outbox-publish.log"

WP_BASE_URL="${WP_BASE_URL:-https://digital.ecomunivers.com}"
WP_USER="${WP_USER:-}"
WP_APP_PASSWORD="${WP_APP_PASSWORD:-}"
POST_STATUS="publish"
DO_PUBLISH=0
TARGET_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --publish) DO_PUBLISH=1; shift ;;
    --file) TARGET_FILE="${2:-}"; [ -n "$TARGET_FILE" ] || { echo "--file needs a filename (glob ok)" >&2; exit 2; }; shift 2 ;;
    --status) case "${2:-}" in draft|publish|pending|private) POST_STATUS="$2" ;; *) echo "--status must be draft|publish|pending|private" >&2; exit 2 ;; esac; shift 2 ;;
    --dry-run) DO_PUBLISH=0; shift ;;
    -h|--help) sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# --- Credentials gate (publish mode only) ---------------------------------
CRED_ERR=""
[ -n "$WP_USER" ] || CRED_ERR="WP_USER"
[ -n "$WP_APP_PASSWORD" ] || CRED_ERR="${CRED_ERR:+$CRED_ERR, }WP_APP_PASSWORD"
if [ "$DO_PUBLISH" = 1 ] && [ -n "$CRED_ERR" ]; then
  echo "❌ Publish mode requires credentials — missing: $CRED_ERR"
  echo "   Set them for this run only (nothing is stored):"
  echo "     WP_USER='...' WP_APP_PASSWORD='...' bash scripts/publish-outbox.sh --publish"
  exit 3
fi

[ -d "$OUTBOX_DIR" ] || { echo "✅ No outbox directory — nothing to publish"; exit 0; }
mkdir -p "$PUBLISHED_DIR"

PAYLOAD=$(mktemp)
trap 'rm -f "$PAYLOAD"' EXIT

# --- Draft parsing ----------------------------------------------------------
# Builds a WP REST payload JSON at $PAYLOAD; prints the post title on stdout.
# Non-zero exit = draft cannot be used (reason on stderr).
parse_draft() {
  local f="$1" base
  base=$(basename "$f")
  case "$base" in
    *.json)
      python3 - "$f" "$PAYLOAD" "$POST_STATUS" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"unparseable JSON: {e}", file=sys.stderr); sys.exit(1)
t = d.get("title", "")
if isinstance(t, dict): t = t.get("rendered", "")
payload = {"title": t, "content": d.get("content", ""), "status": d.get("status") or sys.argv[3]}
for k in ("categories", "tags", "meta", "excerpt", "date"):
    if d.get(k): payload[k] = d[k]
if not payload["content"]:
    print("JSON draft has no content field", file=sys.stderr); sys.exit(1)
json.dump(payload, open(sys.argv[2], "w"))
print(t)
PYEOF
      ;;
    *.html|*.md)
      python3 - "$f" "$PAYLOAD" "$POST_STATUS" "$base" <<'PYEOF'
import json, sys, re, os
f, out, status, base = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
body = open(f, encoding="utf-8", errors="replace").read()
m = re.search(r"<h[12][^>]*>([^<]+)", body, re.I) or re.search(r"^#\s+(.+)$", body, re.M)
if m:
    title = m.group(1).strip()
else:
    title = re.sub(r"^eco-\d{4}-\d{2}-\d{2}-", "", os.path.splitext(base)[0]).replace("-", " ").title()
if not body.strip():
    print("draft file is empty", file=sys.stderr); sys.exit(1)
json.dump({"title": title, "content": body, "status": status}, open(out, "w"))
print(title)
PYEOF
      ;;
    *) echo "unsupported draft type" >&2; return 9 ;;
  esac
}

# --- Collect pending drafts ---------------------------------------------------
DRAFTS=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ -n "$TARGET_FILE" ]; then
    case "$(basename "$f")" in $TARGET_FILE) DRAFTS+=("$f") ;; esac
  else
    DRAFTS+=("$f")
  fi
done < <(find "$OUTBOX_DIR" -maxdepth 1 -type f \( -name '*.html' -o -name '*.md' -o -name '*.json' \) | sort)

if [ "${#DRAFTS[@]}" = 0 ]; then
  echo "✅ Outbox empty — nothing pending"
  [ -n "$TARGET_FILE" ] && echo "   (no match for --file '$TARGET_FILE')"
  exit 0
fi

CRED_NOTE="present ✓"
[ -n "$CRED_ERR" ] && CRED_NOTE="MISSING ($CRED_ERR)"

# --- Dry run -------------------------------------------------------------------
if [ "$DO_PUBLISH" != 1 ]; then
  echo "🔍 DRY RUN — nothing will be sent. Add --publish to post for real."
  echo "   Endpoint: $WP_BASE_URL/wp-json/wp/v2/posts | status: $POST_STATUS (json drafts keep their own status)"
  echo "   Credentials: $CRED_NOTE"
  echo
  for f in "${DRAFTS[@]}"; do
    if ! title=$(parse_draft "$f" 2>/tmp/pub_err.txt); then
      echo "  ⚠️ $(basename "$f"): skipped — $(head -1 /tmp/pub_err.txt)"
      continue
    fi
    echo "  📄 $(basename "$f") → \"$title\" ($(wc -c < "$PAYLOAD") bytes payload)"
  done
  echo
  echo "   ${#DRAFTS[@]} draft(s) ready. Review above, then: bash scripts/publish-outbox.sh --publish"
  exit 0
fi

# --- Publish ---------------------------------------------------------------------
FAIL=0
OK=0
for f in "${DRAFTS[@]}"; do
  base=$(basename "$f")
  if ! title=$(parse_draft "$f" 2>/tmp/pub_err.txt); then
    echo "  ⚠️ $base: skipped — $(head -1 /tmp/pub_err.txt)"
    FAIL=1; continue
  fi
  resp=$(mktemp)
  code=$(curl -s --max-time 30 -o "$resp" -w "%{http_code}" \
    -u "$WP_USER:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    "$WP_BASE_URL/wp-json/wp/v2/posts" \
    --data-binary @"$PAYLOAD")
  link=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('link') or d.get('message', json.dumps(d)[:150]))
except Exception:
    print('unparseable response')
" "$resp" 2>/dev/null)
  if [ "$code" = "201" ]; then
    mv "$f" "$PUBLISHED_DIR/$(date -u +%Y%m%d)-$base"
    echo "  ✅ $base → $link"
    printf '%s\tpublished\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$base" "$link" >> "$LOG_FILE"
    OK=$((OK + 1))
  else
    echo "  ❌ $base: HTTP $code — $link"
    printf '%s\tfailed(%s)\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$code" "$base" "$link" >> "$LOG_FILE"
    FAIL=1
  fi
  rm -f "$resp"
done

if [ "$FAIL" = 0 ]; then
  echo "✅ Outbox drained — $OK draft(s) published and archived to outbox/published/"
  echo "   → Consider closing the WP blocker in memory/blockers.md if this was the last pending item."
else
  echo "⚠️ Some drafts failed — failed ones remain in outbox/ and will be retried next run."
fi
exit $FAIL
