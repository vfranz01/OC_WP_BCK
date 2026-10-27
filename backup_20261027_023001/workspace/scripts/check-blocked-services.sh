#!/bin/bash
# check-blocked-services.sh — Mechanically probe services behind open blockers.
#
# Problem this fixes (2026-10-25): re-checking blocked services (WooCommerce REST
# keys, Cloudflare SSL mode, WP reachability) depended on cron-session agents
# remembering to run manual probes on blog days. Volker's fixes could sit
# undetected for days (the 2026-09-20 blocker went 35 days without automated
# detection). This script probes the KNOWN services behind open blockers on
# every health check and reports, per service, one of:
#   unchanged  — still dead, nothing new (no alert; health check already covers)
#   RECOVERED  — dead last run, works now → blocker work can start (exit 1!)
#   CHANGED    — status changed in some other way (investigate)
#   baseline   — first run, just recorded
#
# State: memory/blocked-services-state.json  (per-service last status)
# Log:   memory/blocked-services.log          (one line per probe, audit trail)
#
# Probes (cheap, read-only; no secrets written to logs):
#   woo_rest  — TOOLS.md WooCommerce key against /wp-json/wc/v3/products?per_page=1
#               (200 = FIXED, 401/403 = auth dead, 301 = Cloudflare scheme downgrade)
#   cf_ssl    — https://digital.ecomunivers.com/ must NOT redirect to http://
#               (301 → http = Full/Flexible mismatch still present)
#   wp_rest   — unauthenticated WP REST index: 200 = site reachable at all
#   wp_publish_auth — WP REST users/me with publishing credentials (when present):
#               200 = app password VALID -> publishing unblocked, backlog can go out
#               401 = auth reaches WP but password rejected (the 2026-09-20 blocker)
#               no_creds = no publishing credentials found (nothing to probe)
#
# Usage:
#   bash scripts/check-blocked-services.sh          # probe + compare + record
#
# Exit codes: 0 = unchanged/baseline (no action needed),
#             1 = at least one service RECOVERED (surface loudly in health check),
#             2 = usage/config error.
# Wired into: health-quick-check.sh (step 12), daily-improve-context.sh brief.

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$WORKSPACE_DIR/memory/blocked-services-state.json"
LOG="$WORKSPACE_DIR/memory/blocked-services.log"
DOMAIN="${BLOCKED_SVC_DOMAIN:-digital.ecomunivers.com}"
# WooCommerce credentials are parsed from TOOLS.md at runtime (single source of
# truth) rather than hardcoded here — hardcoding them trips the workspace
# credential scanner and blocks auto-commit (caught 2026-10-25).
TOOLS_MD="$WORKSPACE_DIR/TOOLS.md"
# NOTE: WooCommerce consumer keys are ck_/cs_ + 40 hex chars. An earlier
# pattern here used {32}, which matched only a PREFIX of the key → truncated
# credential → 401 → false 'auth_dead' reported 2026-10-25..26 while the real
# key was fine (fixed 2026-10-27). The sanity guard below now fails loudly if
# a parsed credential is not full-length, so this class of bug can't silently
# fake a service status again.
WOO_KEY="${BLOCKED_SVC_WOO_KEY:-$(grep -oE 'ck_[a-f0-9]{40}' "$TOOLS_MD" 2>/dev/null | head -1)}"
WOO_SECRET="${BLOCKED_SVC_WOO_SECRET:-$(grep -oE 'cs_[a-f0-9]{40}' "$TOOLS_MD" 2>/dev/null | head -1)}"
# WP publishing credentials are likewise parsed from TOOLS.md at runtime
# (section '### WordPress Publishing', lines WP_USER= / WP_APP_PASSWORD=).
# Keeping them out of this script avoids the credential scanner (see 2026-10-25).
WP_USER="${WP_USER:-$(grep -oE '^WP_USER=.*' "$TOOLS_MD" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | xargs)}"
WP_APP_PASSWORD="${WP_APP_PASSWORD:-$(grep -oE '^WP_APP_PASSWORD=.*' "$TOOLS_MD" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | xargs)}"
CURL_TIMEOUT=8

[ $# -eq 0 ] || { echo "usage: $0" >&2; exit 2; }
if [ -z "$WOO_KEY" ] || [ -z "$WOO_SECRET" ]; then
  echo "check-blocked-services: no WooCommerce key/secret found (TOOLS.md or env)" >&2
  exit 2
fi
# Sanity guard: reject truncated/malformed credentials BEFORE probing, so a
# parsing bug can never report a false 'auth_dead' (see 2026-10-27 fix note).
if ! [[ "$WOO_KEY" =~ ^ck_[a-f0-9]{40}$ ]] || ! [[ "$WOO_SECRET" =~ ^cs_[a-f0-9]{40}$ ]]; then
  echo "check-blocked-services: parsed WooCommerce credential is malformed \
(len=${#WOO_KEY}/${#WOO_SECRET}, expect ck_/cs_ + 40 hex) — refusing to probe \
to avoid a false auth_dead. Check TOOLS.md format or BLOCKED_SVC_WOO_KEY/SECRET env." >&2
  exit 2
fi

NOW=$(date -u '+%Y-%m-%d %H:%M UTC')

# --- probes (each prints a status word) ---------------------------------------
# Status words: ok | auth_dead | redirected | unreachable | http_<code>

probe_woo_rest() {
  local code
  code=$(curl -s -o /dev/null -m "$CURL_TIMEOUT" -w '%{http_code}' \
    -u "$WOO_KEY:$WOO_SECRET" \
    "https://$DOMAIN/wp-json/wc/v3/products?per_page=1" 2>/dev/null) || code="000"
  case "$code" in
    200) echo ok ;;
    401|403) echo auth_dead ;;
    301|302|307|308) echo redirected ;;
    000) echo unreachable ;;
    *) echo "http_$code" ;;
  esac
}

probe_cf_ssl() {
  local out redirect
  out=$(curl -s -o /dev/null -m "$CURL_TIMEOUT" -w '%{http_code} %{redirect_url}' \
    -I "https://$DOMAIN/" 2>/dev/null) || { echo unreachable; return; }
  redirect="${out#* }"
  case "${out%% *}" in
    200) echo ok ;;
    301|302|307|308)
      case "$redirect" in
        http://*) echo redirected ;;   # https → http downgrade = SSL mode bug
        https://*) echo ok ;;          # normal redirect, scheme preserved
        *) echo "redirect?" ;;
      esac ;;
    000) echo unreachable ;;
    *) echo "http_${out%% *}" ;;
  esac
}

probe_wp_rest() {
  local code
  code=$(curl -s -o /dev/null -m "$CURL_TIMEOUT" -w '%{http_code}' \
    "https://$DOMAIN/wp-json/" 2>/dev/null) || code="000"
  case "$code" in
    200) echo ok ;;
    301|302|307|308) echo redirected ;;
    000) echo unreachable ;;
    *) echo "http_$code" ;;
  esac
}

probe_wp_publish_auth() {
  if [ -z "$WP_USER" ] || [ -z "$WP_APP_PASSWORD" ]; then
    echo no_creds
    return
  fi
  local code
  code=$(curl -s -o /dev/null -m "$CURL_TIMEOUT" -w '%{http_code}' \
    -u "$WP_USER:$WP_APP_PASSWORD" \
    "https://$DOMAIN/wp-json/wp/v2/users/me" 2>/dev/null) || code="000"
  case "$code" in
    200) echo ok ;;
    401|403) echo auth_dead ;;
    000) echo unreachable ;;
    *) echo "http_$code" ;;
  esac
}

# --- run probes ----------------------------------------------------------------
declare -A RESULT
RESULT[woo_rest]=$(probe_woo_rest)
RESULT[cf_ssl]=$(probe_cf_ssl)
RESULT[wp_rest]=$(probe_wp_rest)
RESULT[wp_publish_auth]=$(probe_wp_publish_auth)
SERVICES=(woo_rest cf_ssl wp_rest wp_publish_auth)

# --- read prior state (python holds the JSON safely) ---------------------------
STATE_JSON=$(python3 - "$STATE" "${RESULT[woo_rest]}" "${RESULT[cf_ssl]}" "${RESULT[wp_rest]}" "${RESULT[wp_publish_auth]}" <<'PY'
import json, os, sys
path = sys.argv[1]
new = {"woo_rest": sys.argv[2], "cf_ssl": sys.argv[3], "wp_rest": sys.argv[4], "wp_publish_auth": sys.argv[5]}
prev = {}
try:
    prev = json.load(open(path))
except Exception:
    pass
lines, recoveries = [], 0
for svc in ("woo_rest", "cf_ssl", "wp_rest", "wp_publish_auth"):
    old = prev.get(svc, {}).get("status", "missing")
    cur = new[svc]
    if old == "missing":
        lines.append(("baseline", f"* {svc}: {cur} (baseline recorded — first run)"))
    elif cur == "ok" and old != "ok":
        lines.append(("recovered", f"\U0001F389 {svc}: RECOVERED ({old} -> ok) — blocker work can start! Re-verify, then set 'status: resolved' in memory/blockers.md"))
        recoveries += 1
    elif old != cur:
        lines.append(("changed", f"* {svc}: CHANGED ({old} -> {cur}) — investigate; may affect blockers"))
    elif cur == "no_creds":
        lines.append(("unchanged", f"* {svc}: no_creds — no WP publishing credentials in TOOLS.md/env yet; add WP_USER=/WP_APP_PASSWORD= under '### WordPress Publishing' so recovery is auto-detected"))
    else:
        lines.append(("unchanged", f"* {svc}: unchanged ({cur})"))
# write new state
import datetime
out = {svc: {"status": new[svc], "since": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")} for svc in new}
tmp = path + ".tmp"
json.dump(out, open(tmp, "w"), indent=1)
os.replace(tmp, path)
print("\n".join(l[0] + "\t" + l[1] for l in lines))
print("RECOVERIES=" + str(recoveries))
PY
) || { echo "check-blocked-services: state update failed" >&2; exit 2; }

# --- audit log -----------------------------------------------------------------
for svc in "${SERVICES[@]}"; do
  printf '%s\t%s\t%s\n' "$NOW" "$svc" "${RESULT[$svc]}" >> "$LOG"
done

# --- report --------------------------------------------------------------------
echo "── Blocked-services probe ($NOW) ──"
RECOVERIES=$(printf '%s\n' "$STATE_JSON" | sed -n 's/^RECOVERIES=//p')
RECOVERIES="${RECOVERIES:-0}"
printf '%s\n' "$STATE_JSON" | grep -v '^RECOVERIES=' | while IFS=$'\t' read -r kind text; do
  echo "$text"
done
if [ "${RECOVERIES:-0}" -gt 0 ]; then
  echo "→ Action: verify the recovered service, then clear the matching blocker in memory/blockers.md"
  exit 1
fi
exit 0
