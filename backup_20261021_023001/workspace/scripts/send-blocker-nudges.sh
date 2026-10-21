#!/bin/bash
# send-blocker-nudges.sh — One command: print nudges → deliver → record outcome.
#
# Problem this fixes (2026-10-18): the daily-improvement routine had a manual
# 3-step contract documented in prose ("get nudges, send them, then run
# nudge-blockers.sh --record sent|failed"). Steps 1 and 2 were done by the
# agent, step 3 was forgotten on some days — memory/nudge-state.log shows
# failed attempts on 10-11/12/13/15 but NOTHING for 10-16/10-17, so silent
# failures looked like "nothing to nudge". Worse: when delivery fails (Telegram
# 401 since 2026-09-23) the composed reminder text was thrown away, so a
# recovery had to rebuild it from blockers.md.
#
# This wrapper makes the whole loop mechanical and lossless:
#   1. Asks nudge-blockers.sh which reminders are due (dedup/sent logic stays
#      there — single source of truth).
#   2. Sends each one through telegram-send.sh (delivery-verified: ok:true).
#   3. Records the real outcome with `nudge-blockers.sh --record sent|failed`
#      so "max 1 nudge/day" dedup keeps working and failures keep retrying.
#   4. On failure, appends the exact message to memory/undelivered-nudges.md
#      (a persistent queue). After Telegram is fixed, `--flush` delivers that
#      backlog verbatim and archives it, instead of reconstructing from scratch.
#
# Usage:
#   bash scripts/send-blocker-nudges.sh              # send + record + queue
#   bash scripts/send-blocker-nudges.sh --dry-run    # show, no send, no record
#   bash scripts/send-blocker-nudges.sh --flush      # deliver queued backlog
#   bash scripts/send-blocker-nudges.sh --status     # queue size + last runs
#   bash scripts/send-blocker-nudges.sh --dedupe     # collapse duplicate queue entries
#
# Exit codes: 0 = nothing due / everything delivered / backlog flushed,
#             1 = at least one delivery failed (message queued for retry),
#             2 = usage/config error.
#
# Used by: daily-improvement routine (AGENTS.md), daily-improve-context.sh
# (context brief), check_telegram_token.sh recovery message.

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NUDGE="$WORKSPACE_DIR/scripts/nudge-blockers.sh"
SENDER="$WORKSPACE_DIR/scripts/telegram-send.sh"
QUEUE="$WORKSPACE_DIR/memory/undelivered-nudges.md"
ARCHIVE="$WORKSPACE_DIR/memory/undelivered-nudges-archive.md"
STATE="$WORKSPACE_DIR/memory/nudge-state.log"
MODE="send"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) MODE="dry" ;;
    --flush)   MODE="flush" ;;
    --status)  MODE="status" ;;
    --dedupe)  MODE="dedupe" ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "send-blocker-nudges: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -f "$NUDGE" ]  || { echo "send-blocker-nudges: missing $NUDGE" >&2; exit 2; }
[ -x "$SENDER" ] || [ -f "$SENDER" ] || { echo "send-blocker-nudges: missing $SENDER" >&2; exit 2; }

TODAY=$(date -u +%Y-%m-%d)
NOW=$(date -u '+%Y-%m-%d %H:%M UTC')

ensure_queue() {
  [ -f "$QUEUE" ] && return 0
  cat > "$QUEUE" <<'EOF'
<!-- undelivered-nudges.md — reminders whose delivery FAILED.
     Written by scripts/send-blocker-nudges.sh. Do not hand-edit entries.
     Flush after Telegram is restored: bash scripts/send-blocker-nudges.sh --flush -->
EOF
}

# Truncate the queue back to its header (used after a fully successful flush).
reset_queue() {
  rm -f "$QUEUE"
  ensure_queue
}

# Queue entries: "## <UTC timestamp> — <blocker title>" followed by message body.
# Title is the same key prefix nudge-state.log uses, so dedup stays consistent.
queue_count() {
  [ -f "$QUEUE" ] && grep -c '^## ' "$QUEUE" 2>/dev/null || echo 0
}

# Collapse duplicate queue entries: keep only the NEWEST entry per blocker
# title, drop older ones. Why: before 2026-10-19 every failed send appended
# blindly, so one long outage produced one copy per day (the 26-day Telegram
# outage left 2 identical reminders for the same blocker). A flush would then
# deliver the same reminder N times — spam exactly when Volker finally fixes
# the channel and should get a clean status. Preamble (frontmatter/comment) is
# preserved verbatim.
queue_dedupe() {
  [ -f "$QUEUE" ] || return 0
  local tmp before after
  tmp=$(mktemp /tmp/nudge-dedupe.XXXXXX) || return 1
  awk '
    function keyof(line) { k=line; sub(/^## [^—]*—[[:space:]]*/, "", k); return k }
    /^## / {
      if (n > 0) { blocks[n]=buf; keys[n]=key }
      n++; buf=$0 "\n"; key=keyof($0); next
    }
    { if (n == 0) pre = pre $0 "\n"; else buf = buf $0 "\n" }
    END {
      if (n > 0) { blocks[n]=buf; keys[n]=key }
      for (i=1; i<=n; i++) last[keys[i]]=i      # last occurrence wins (newest)
      printf "%s", pre
      for (i=1; i<=n; i++) if (last[keys[i]] == i) printf "%s", blocks[i]
    }
  ' "$QUEUE" > "$tmp" || { rm -f "$tmp"; return 1; }
  before=$(queue_count); after=$(grep -c '^## ' "$tmp" 2>/dev/null || true)
  after=${after:-0}
  mv "$tmp" "$QUEUE"
  if [ "$before" -gt "$after" ]; then
    echo "   🧹 collapsed $((before - after)) duplicate queue entr(y/ies) for the same blocker"
  fi
}

queue_append() {
  local title="$1" body="$2"
  ensure_queue
  printf '\n## %s — %s\n%s\n' "$NOW" "$title" "$body" >> "$QUEUE"
  queue_dedupe
}

# Record "<sent|failed>" for a single blocker title, matching nudge-state.log
# format: <UTC date>\t<status>\t<first 60 chars of title>.
record_key() {
  local status="$1" title="$2"
  [ "$MODE" = "dry" ] && return 0
  mkdir -p "$(dirname "$STATE")" 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$TODAY" "$status" "$(printf '%s' "$title" | tr -d '\t' | cut -c1-60)" >> "$STATE"
}

print_status() {
  local n; n=$(queue_count)
  echo "📥 Undelivered nudge queue: ${n} item(s) — $QUEUE"
  [ "$n" -gt 0 ] && grep '^## ' "$QUEUE" | tail -5 | sed 's/^## /   • /'
  echo "🗓  Last recorded attempts (nudge-state.log):"
  tail -5 "$STATE" 2>/dev/null | awk -F'\t' '{printf "   • %s %s %s\n", $1, $2, $3}'
  return 0
}

if [ "$MODE" = "status" ]; then
  print_status
  exit 0
fi

if [ "$MODE" = "dedupe" ]; then
  ensure_queue
  queue_dedupe
  print_status
  exit 0
fi

# --- Parse nudge blocks into title/message pairs ---------------------------
# nudge-blockers.sh output per reminder:
#   ── NUDGE (age 672h, waiting_on: user) ──
#   TO: Volker
#   MSG: ⏳ Reminder: blocker still open (672h): <title>
#        Next action: <next>
collect_nudges() {
  bash "$NUDGE" 2>/dev/null | awk '
    function emit() { if (title != "") { printf "###NUDGE###\t%s\t%s\n", title, msg } ; title=""; msg="" }
    /^── NUDGE /            { emit(); inblock=1; next }
    inblock && /^── /      { emit(); inblock=0; next }
    inblock && /^TO: /     { next }
    inblock && /^MSG: /    { msg=substr($0,6); title=msg; sub(/^.*open \([0-9]+h\):[[:space:]]*/,"",title); next }
    inblock && /^[[:space:]]+[^[:space:]]/ { gsub(/^[[:space:]]+/,"",$0); msg=msg "\x1f" $0; next }
    END { emit() }
  '
}
# NOTE: multi-line bodies are joined with \x1f (unit separator), not \n.
# awk prints line-wise records; an embedded newline would split the TSV into
# a bogus second record and silently drop every continuation line
# (e.g. the "Next action:" part of a nudge).

if [ "$MODE" = "flush" ]; then
  # Defensive: an older queue (written before 2026-10-19) may hold one entry
  # per failed day for the same blocker. Collapse before counting so N is real.
  queue_dedupe
  N=$(queue_count)
  if [ "$N" -eq 0 ]; then echo "✅ Nothing queued — no backlog to flush"; exit 0; fi
  echo "📤 Flushing $N queued reminder(s)…"
  FAILED=0; SENT=0
  REMAIN=$(mktemp /tmp/nudge-remain.XXXXXX) || exit 2
  # One message per queued entry: keeps each send well under Telegram's 4096
  # char limit and means one bad entry cannot block the rest of the backlog.
  while IFS=$'\t' read -r _marker title body; do
    [ "$_marker" = "###QUEUE###" ] || continue
    [ -n "$body" ] || continue
    body=$(printf '%s' "$body" | tr '\037' '\n' | sed '/^[[:space:]]*$/d')
    if bash "$SENDER" --no-queue "$body" >/dev/null 2>&1; then
      echo "   ✅ delivered: $title"
      SENT=$((SENT + 1)); record_key sent "$title"
    else
      echo "   ⚠️  still failing: $title"
      FAILED=$((FAILED + 1))
      # Keep undelivered entries (only those) queued for the next attempt.
      printf '## %s — %s\n%s\n\n' "$NOW" "$title" "$body" >> "$REMAIN"
    fi
  done < <(awk '
      function emit() { if (title != "") printf "###QUEUE###\t%s\t%s\n", title, body; title=""; body="" }
      /^## / { emit(); title=$0; sub(/^## [^—]*—[[:space:]]*/, "", title); next }
      /^<!--/ || /^$/ { next }
      { body = (body == "" ? $0 : body "\x1f" $0) }
      END { emit() }' "$QUEUE")
  if [ "$FAILED" -eq 0 ]; then
    { echo "# Undelivered nudge archive"; echo; echo "Flushed successfully on $NOW ($SENT item(s)); see memory/undelivered-nudges.md for the queue."; echo; cat "$QUEUE"; } >> "$ARCHIVE"
    ensure_queue
    rm -f "$REMAIN"
    reset_queue
    echo "✅ Backlog flushed ($SENT item(s) delivered) — archived to memory/undelivered-nudges-archive.md"
    exit 0
  fi
  # Partial success: keep only the still-failing entries so nothing is
  # delivered twice on the next flush.
  ensure_queue
  { sed -n '1,/^$/p' "$QUEUE"; cat "$REMAIN" 2>/dev/null; } > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
  rm -f "$REMAIN"
  echo "⚠️  $FAILED of $((SENT + FAILED)) queued reminder(s) still undeliverable — ${SENT} delivered, remaining kept in $QUEUE"
  exit 1
fi

# --- Normal run ------------------------------------------------------------
BLOCKS=$(collect_nudges)
if [ -z "$BLOCKS" ]; then
  echo "✅ No blocker nudges due (nothing stale, or already delivered today)"
  exit 0
fi

DELIVERED=0; UNDELIVERED=0
while IFS=$'\t' read -r _marker title msg; do
  [ "$_marker" = "###NUDGE###" ] || continue
  [ -n "$title" ] || continue
  msg=$(printf '%s' "$msg" | tr '\037' '\n')
  echo "── Sending: $title"
  if [ "$MODE" = "dry" ]; then
    printf '%s\n\n' "$msg" | sed 's/^/   | /'
    continue
  fi
  if bash "$SENDER" --no-queue "$msg" >/dev/null 2>&1; then
    echo "   ✅ delivered"
    DELIVERED=$((DELIVERED + 1)); record_key sent "$title"
  else
    echo "   ⚠️  delivery FAILED — queued in memory/undelivered-nudges.md (retry next run / --flush after fix)"
    UNDELIVERED=$((UNDELIVERED + 1)); record_key failed "$title"; queue_append "$title" "$msg"
  fi
done <<< "$BLOCKS"

if [ "$MODE" = "dry" ]; then
  echo "ℹ️  Dry run — nothing sent, nothing recorded."
  exit 0
fi

echo "── Summary: ${DELIVERED} delivered, ${UNDELIVERED} failed"
if [ "$UNDELIVERED" -gt 0 ]; then
  echo "   Queue now holds $(queue_count) item(s). Flush once Telegram works: bash scripts/send-blocker-nudges.sh --flush"
  exit 1
fi
exit 0
