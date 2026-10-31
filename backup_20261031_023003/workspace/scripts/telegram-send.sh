#!/bin/bash
# telegram-send.sh — Central Telegram sender with DELIVERY-VERIFIED semantics.
#
# Problem this fixes (2026-10-11): scripts that notify Volker hardcoded an old
# bot token and treated "curl didn't error" as success (backup_github_sync.sh
# redirected output to /dev/null). When the token was revoked (outage since
# 2026-09-23), those sends failed *silently* — the backup log looked fine
# while nothing reached Volker for weeks.
#
# This helper:
#   1. Never hardcodes a token. Candidates are discovered at call time:
#      $TELEGRAM_BOT_TOKEN first, then every channels.telegram.accounts.*.botToken
#      in openclaw.json. When Volker rotates a token via BotFather, this picks
#      it up with zero script edits (self-healing).
#   2. Treats delivery as verified ONLY on HTTP 200 + Telegram ok:true.
#      A queued/"Accepted" status is not delivery.
#   3. Tries each candidate token in order until one delivers.
#   4. Logs every attempt (success or failure) to memory/telegram-deliveries.log
#      so silent failures become auditable.
#
# Usage:
#   telegram-send.sh "message text"              # plain text
#   echo "multiline text" | telegram-send.sh     # stdin
#   telegram-send.sh --html "<b>text</b>"        # HTML parse mode
#   telegram-send.sh --silent "text"             # no notification sound
#   telegram-send.sh --chat 123456789 "text"     # override target chat
#   telegram-send.sh --test                      # labeled self-test message
#   telegram-send.sh --no-queue "text"           # do not persist on failure
#   telegram-send.sh --source backup-check "..." # label for the queue entry
#   telegram-send.sh --flush                     # deliver queued notifications now
#   telegram-send.sh --queue-status              # show the undelivered queue
#
# Outage safety net (2026-10-20): a verified-failure send used to be lost unless
# the caller had its own queue (only blocker nudges did). During the 401 outage
# every backup/blog/health alert therefore evaporated. On failure this script
# now appends the message to memory/undelivered-notifications.md (deduplicated
# by content and by source+subject), and --flush delivers that backlog after
# the token is fixed. Blocker nudges pass --no-queue because they persist to
# memory/undelivered-nudges.md themselves (avoids double delivery on flush).
#
# Exit codes: 0 = delivered (ok:true verified), 1 = all tokens failed,
#             2 = no token candidates found.
# Parent scripts: call as informational (never abort your flow):
#   bash scripts/telegram-send.sh "$MSG" || log "WARNING: Telegram not delivered"
set -uo pipefail

CONFIG="/home/node/.openclaw/openclaw.json"
LOG="/home/node/.openclaw/workspace/memory/telegram-deliveries.log"
DEFAULT_CHAT="${TELEGRAM_CHAT_ID:-881022003}"
TIMEOUT=10

QUEUE_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/notify-queue.py"

SILENT=0; HTML=0; TARGET="$DEFAULT_CHAT"; TEXT=""; USE_QUEUE=1
SOURCE="telegram-send"; MODE="send"
while [ $# -gt 0 ]; do
  case "$1" in
    --silent) SILENT=1; shift ;;
    --html)   HTML=1; shift ;;
    --chat)   TARGET="$2"; shift 2 ;;
    --no-queue) USE_QUEUE=0; shift ;;
    --source) SOURCE="$2"; shift 2 ;;
    --flush)  MODE="flush"; shift ;;
    --queue-status) MODE="status"; shift ;;
    --test)   TEXT="[telegram-send self-test $(date -u '+%F %T UTC')] If you read this, script-level Telegram delivery is working."; shift ;;
    --)       shift; break ;;
    -*)       echo "telegram-send: unknown flag: $1" >&2; shift ;;
    *)        break ;;
  esac
done

# --- Queue maintenance modes (no message needed) ---------------------------
if [ "$MODE" = "status" ]; then
  python3 "$QUEUE_TOOL" status
  exit 0
fi
if [ "$MODE" = "flush" ]; then
  TMPD=$(mktemp -d) || exit 1
  trap 'rm -rf "$TMPD"' EXIT
  # Entries are exported to files: shell `read` is line-based, so multi-line
  # bodies (stack traces, bullet lists) would otherwise be split and truncated.
  python3 "$QUEUE_TOOL" export "$TMPD" > "$TMPD/ids" || { echo "telegram-send: queue unreadable" >&2; exit 1; }
  TOTAL=$(grep -c . "$TMPD/ids" 2>/dev/null || echo 0)
  if [ "$TOTAL" -eq 0 ]; then
    echo "Queue empty — every notification already delivered."
    exit 0
  fi
  echo "Flushing $TOTAL queued notification(s)…"
  SENT=0; KEPT=0
  while IFS= read -r eid; do
    [ -n "$eid" ] || continue
    IFS=$'\t' read -r ets esrc esub < "$TMPD/$eid.meta"
    etext=$(cat "$TMPD/$eid.txt" 2>/dev/null)
    echo "── $ets [$esrc] $esub"
    if bash "${BASH_SOURCE[0]}" --no-queue --source "$esrc" --chat "$TARGET" "$etext" >/dev/null 2>&1; then
      python3 "$QUEUE_TOOL" remove "$eid" >/dev/null 2>&1 || true
      echo "   ✅ delivered"
      SENT=$((SENT + 1))
    else
      echo "   ⚠️  still failing — kept in queue"
      KEPT=$((KEPT + 1))
    fi
  done < "$TMPD/ids"
  echo "Flush done: $SENT delivered, $KEPT still queued."
  [ "$KEPT" -eq 0 ]
  exit $?
fi

# Remaining args = message text; empty -> read stdin (preserves newlines).
[ -z "$TEXT" ] && TEXT="$*"
[ -z "$TEXT" ] && TEXT=$(cat)
if [ -z "$TEXT" ]; then
  echo "telegram-send: no message text given" >&2
  exit 1
fi

log() { printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOG" 2>/dev/null || true; }

# --- Gather candidate tokens: env first, then config accounts --------------
TOKENS=()
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  TOKENS+=("env:TELEGRAM_BOT_TOKEN|$TELEGRAM_BOT_TOKEN")
fi
if [ -r "$CONFIG" ]; then
  while IFS=$'\t' read -r name token; do
    [ -n "$token" ] && TOKENS+=("acct:$name|$token")
  done < <(python3 - "$CONFIG" <<'PYEOF'
import json, sys
try:
    accs = json.load(open(sys.argv[1])).get("channels", {}).get("telegram", {}).get("accounts", {})
    for name, acc in accs.items():
        tok = (acc.get("botToken") or "").strip()
        if tok:
            print(f"{name}\t{tok}")
except Exception:
    pass
PYEOF
)
fi

if [ "${#TOKENS[@]}" -eq 0 ]; then
  log FAIL "no token candidates (env TELEGRAM_BOT_TOKEN empty, $CONFIG unreadable/no tokens)"
  echo "telegram-send: no token found" >&2
  exit 2
fi

# --- Try each token until Telegram confirms ok:true --------------------------
RESULT_JSON=/tmp/tg_send_result.$$.json
for entry in "${TOKENS[@]}"; do
  src="${entry%%|*}"; tok="${entry#*|}"
  code=$(curl -s --max-time "$TIMEOUT" -o "$RESULT_JSON" -w "%{http_code}" \
    "https://api.telegram.org/bot$tok/sendMessage" \
    --data-urlencode "chat_id=$TARGET" \
    --data-urlencode "text=$TEXT" \
    ${HTML:+--data-urlencode "parse_mode=HTML"} \
    ${SILENT:+--data-urlencode "disable_notification=true"} 2>/dev/null) || code="000"
  if [ "$code" = "200" ] && python3 -c "import json,sys;sys.exit(0 if json.load(open('$RESULT_JSON')).get('ok') else 1)" 2>/dev/null; then
    log OK "delivered via $src -> chat $TARGET (${#TEXT} chars)"
    rm -f "$RESULT_JSON"
    exit 0
  fi
  err=$(python3 -c "import json;print(json.load(open('$RESULT_JSON')).get('description','no description'))" 2>/dev/null || echo "unparseable response")
  log FAIL "HTTP ${code:-none} via $src -> chat $TARGET ($err)"
done

rm -f "$RESULT_JSON"
if [ "$USE_QUEUE" -eq 1 ] && [ -f "$QUEUE_TOOL" ]; then
  QRES=$(printf '%s' "$TEXT" | python3 "$QUEUE_TOOL" append --source "$SOURCE" 2>&1) || QRES="queue error"
  log QUEUE "$QRES (source: $SOURCE)"
  echo "telegram-send: delivery FAILED on all ${#TOKENS[@]} token candidates — persisted to memory/undelivered-notifications.md ($QRES); see $LOG" >&2
else
  echo "telegram-send: delivery FAILED on all ${#TOKENS[@]} token candidates — see $LOG" >&2
fi
exit 1
