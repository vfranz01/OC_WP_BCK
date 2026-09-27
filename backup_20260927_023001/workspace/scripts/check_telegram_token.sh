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

CONFIG="/home/node/.openclaw/openclaw.json"
TIMEOUT=10

[ -r "$CONFIG" ] || { echo "Telegram config unreadable: $CONFIG"; exit 2; }

python3 - "$CONFIG" <<'PYEOF' > /tmp/telegram_tokens.tsv 2>/tmp/telegram_tokens.err
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    accounts = d.get("channels", {}).get("telegram", {}).get("accounts", {})
    if not accounts:
        print("NOTOKEN\t(no accounts configured)")
        sys.exit(0)
    for name, acc in accounts.items():
        tok = acc.get("botToken", "")
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
  elif [ "$CODE" = "401" ] || [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
    if [ "$CODE" = "401" ]; then
      echo "⚠️  Telegram bot '$name' token REJECTED (401 Unauthorized) — nudges &"
      echo "    notifications silently fail. Fix: regenerate via @BotFather and update"
      echo "    channels.telegram.accounts.$name.botToken in openclaw.json."
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

exit $FAIL