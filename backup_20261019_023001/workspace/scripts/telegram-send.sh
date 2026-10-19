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

SILENT=0; HTML=0; TARGET="$DEFAULT_CHAT"; TEXT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --silent) SILENT=1; shift ;;
    --html)   HTML=1; shift ;;
    --chat)   TARGET="$2"; shift 2 ;;
    --test)   TEXT="[telegram-send self-test $(date -u '+%F %T UTC')] If you read this, script-level Telegram delivery is working."; shift ;;
    --)       shift; break ;;
    -*)       echo "telegram-send: unknown flag: $1" >&2; shift ;;
    *)        break ;;
  esac
done
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
echo "telegram-send: delivery FAILED on all ${#TOKENS[@]} token candidates — see $LOG" >&2
exit 1
