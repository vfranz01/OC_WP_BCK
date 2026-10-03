#!/bin/bash
# check_telegram_token.sh — Verify Telegram bot tokens are valid via getMe.
#
# Problem: outbound Telegram sends (blocker nudges, notifications) fail with
# 401 Unauthorized when the bot token in openclaw.json is stale/revoked, but
# this was only discovered during nudge attempts — surfacing days late in
# daily memory instead of immediately in health checks.
#
# Checks every bot token under channels.telegram.accounts.*. Exit codes:
#   0 = all tokens valid
#   1 = at least one token unauthorized (needs regen via BotFather)
#   2 = no token found / config unreadable / network error
#
# Output: one line per account + a fix hint on failure.
# Used by health-quick-check.sh (check #11).
#
# Outage tracking (added 2026-09-28):
#   Telegram is the ONLY configured comms channel to Volker, so an outage
#   means nudges, notifications AND daily summaries silently stop reaching
#   him. Consecutive failed days are counted in memory/telegram-outage.state
#   and escalate: day 1-2 ⚠️ as before, day 3+ 🚨 CRITICAL with day count.
#   On recovery (fail → pass), prints a reminder to flush any nudges that
#   recorded 'failed' in memory/nudge-state.log during the outage.

CONFIG="/home/node/.openclaw/openclaw.json"
WORKSPACE_DIR="/home/node/.openclaw/workspace"
TIMEOUT=10
OUTAGE_STATE="$WORKSPACE_DIR/memory/telegram-outage.state"

[ -r "$CONFIG" ] || { echo "Telegram config unreadable: $CONFIG"; exit 2; }

# --- Outage state helpers -------------------------------------------------
read_outage_days() {
  # File format: <fail-streak-days> <first-failure-UTC-date>
  awk '{print $1}' "$OUTAGE_STATE" 2>/dev/null || echo 0
}
mark_outage_fail() {
  # File format: <fail-streak-days> <first-failure-UTC-date> <last-run-date>
  # Streak increments at most once per UTC day, so multiple health-check
  # runs on the same day don't inflate the count.
  local streak first lastrun today
  today=$(date -u +%Y-%m-%d)
  if [ -f "$OUTAGE_STATE" ]; then
    read -r streak first lastrun < "$OUTAGE_STATE"
  fi
  streak=${streak:-0}
  first=${first:-$today}
  if [ "$lastrun" != "$today" ]; then streak=$((streak + 1)); fi
  printf '%s %s %s\n' "$streak" "$first" "$today" > "$OUTAGE_STATE" 2>/dev/null || true
  echo "$streak"
}
mark_outage_recovered() {
  local streak; streak=$(read_outage_days)
  if [ "${streak:-0}" -gt 0 ] && [ -f "$OUTAGE_STATE" ]; then
    local first; first=$(awk '{print $2}' "$OUTAGE_STATE")
    echo "✅ TELEGRAM RECOVERED after ${streak}d outage (since $first)."
    echo "   → Check memory/nudge-state.log: blockers nudged 'failed' during the"
    echo "     outage were never delivered — send the current nudge backlog to"
    echo "     Volker now (bash scripts/nudge-blockers.sh)."
    : > "$OUTAGE_STATE"
  fi
}

python3 - "$CONFIG" <<'PYEOF' > /tmp/telegram_tokens.tsv 2>/tmp/telegram_tokens.err
import json, sys, os
try:
    d = json.load(open(sys.argv[1]))
    accounts = d.get("channels", {}).get("telegram", {}).get("accounts", {})
    if not accounts:
        print("NOTOKEN\t(no accounts configured)")
        sys.exit(0)
    # The gateway prefers a TELEGRAM_BOT_TOKEN env var over the per-account
    # botToken fields. If it is set, that env token (not the config one) is
    # what actually delivers messages — checking only the config would flag
    # a working env override as an outage, or miss a dead config token that
    # the env masks. Test the env token first, then any config tokens that
    # differ from it.
    seen = set()
    env_tok = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    if env_tok:
        print(f"__ENV__\t{env_tok}")
        seen.add(env_tok)
    for name, acc in accounts.items():
        tok = acc.get("botToken", "")
        if tok and tok in seen:
            continue
        print(f"{name}\t{tok}")
except Exception as e:
    print(f"ERROR\t{e}", file=sys.stderr)
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then
  echo "Telegram config parse failed: $(head -1 /tmp/telegram_tokens.err)"
  exit 2
fi

FAIL=0
while IFS=$'\t' read -r name token; do
  if [ "$name" = "__ENV__" ]; then
    name='env:TELEGRAM_BOT_TOKEN (gateway override — what actually delivers)'
  fi
  if [ -z "$token" ]; then
    echo "Telegram account '$name': no bot token configured"
    FAIL=1
    continue
  fi
  CODE=$(curl -s --max-time "$TIMEOUT" -o "/tmp/tg_getme_$name.json" -w "%{http_code}" \
    "https://api.telegram.org/bot$token/getMe" 2>/dev/null)
  if [ "$CODE" = "200" ]; then
    BOT=$(python3 -c "import json;print(json.load(open('/tmp/tg_getme_$name.json')).get('result',{}).get('username','?'))" 2>/dev/null || echo "?")
    echo "✅ Telegram bot '$name' (@$BOT) token valid"
    rm -f "/tmp/tg_getme_$name.json"
    RECOVERED=1
  elif [ "$CODE" = "401" ] || [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
    if [ "$CODE" = "401" ]; then
      echo "⚠️  Telegram bot '$name' token REJECTED (401 Unauthorized) — nudges &"
      echo "    notifications silently fail. Fix: regenerate via @BotFather and update"
      echo "    the token source for this account (env TELEGRAM_BOT_TOKEN or"
      echo "    channels.telegram.accounts.*.botToken in openclaw.json)."
      FAIL=1
    else
      echo "⚠️  Telegram bot '$name': network timeout (no answer in ${TIMEOUT}s)"
      FAIL=2
    fi
  else
    echo "⚠️  Telegram bot '$name': unexpected HTTP $CODE"
    FAIL=2
  fi
done < /tmp/telegram_tokens.tsv

# --- Outage escalation / recovery -----------------------------------------
if [ "$FAIL" -ne 0 ]; then
  STREAK=$(mark_outage_fail)
  if [ "$STREAK" -ge 3 ]; then
    FIRST=$(awk '{print $2}' "$OUTAGE_STATE" 2>/dev/null)
    echo "🚨 CRITICAL: Telegram outage day ${STREAK} (since ${FIRST:-?}) — Telegram is the"
    echo "    ONLY configured channel to Volker. Nudges, notifications and daily"
    echo "    summaries are NOT reaching him. Fix requires HIM: regenerate via"
    echo "    @BotFather → update the token (env TELEGRAM_BOT_TOKEN on the gateway"
    echo "    host takes priority, else channels.telegram.accounts.*.botToken in"
    echo "    openclaw.json) → restart gateway."
    echo "    NOTE: this cron session itself runs agent-side; also try a direct"
    echo "    message-tool send as a cross-check before alarming."
  fi
else
  mark_outage_recovered
fi

exit $FAIL