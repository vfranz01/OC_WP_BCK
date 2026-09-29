#!/bin/bash
# Update heartbeat-state.json with the current timestamp.
# AGENTS.md documents memory/heartbeat-state.json as the heartbeat check tracker,
# but nothing ever wrote to it — it sat stale since April 2026. This script makes
# that documented tracking real: every heartbeat routine run stamps the checks.
# Safe to run on every heartbeat: purely a state-file update, idempotent.

WORKSPACE_DIR="/home/node/.openclaw/workspace"
STATE_FILE="$WORKSPACE_DIR/memory/heartbeat-state.json"

mkdir -p "$WORKSPACE_DIR/memory"

# Current unix epoch (UTC)
NOW=$(date +%s)

# Atomic write via temp file, then rename, so we never leave a half-written state.
TMP_FILE="$STATE_FILE.tmp"

python3 - "$NOW" "$STATE_FILE" "$TMP_FILE" <<'PY'
import json, os, sys

now = int(sys.argv[1])
state_file = sys.argv[2]
tmp_file = sys.argv[3]

state = {}
# Preserve any existing entries; only bump the check timestamps.
if os.path.exists(state_file):
    try:
        with open(state_file, "r") as f:
            state = json.load(f)
    except (json.JSONDecodeError, OSError):
        state = {}  # Corrupt/stale file — rebuild rather than crash the heartbeat

last = state.get("lastChecks", {})
for key in ("email", "calendar", "weather", "mentions"):
    last[key] = now
state["lastChecks"] = last
state["lastHeartbeatRoutine"] = now

with open(tmp_file, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
os.replace(tmp_file, state_file)
PY

echo "heartbeat-state.json updated ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
exit 0