#!/bin/bash
# check-scripts-doc.sh — Detect scripts missing from scripts/README.md.
#
# Problem: scripts/README.md is the documented entry point for the automation
# suite, but it silently drifted ~5 months behind the code — 20 of the .sh
# scripts (all the recent self-healing ones: snapshot_stopgap.sh,
# check-blockers.sh, check-outbox.sh, check_telegram_token.sh, commit-workspace.sh,
# daily-improve-context.sh, …) were absent. New automation was undiscoverable and
# the doc's "Checks:" lists described behaviour that no longer existed.
#
# This guard lists any scripts/*.sh whose filename never appears in
# scripts/README.md, so drift is caught the next time the daily agent runs
# instead of months later. Informational: exit 1 only means "document these".
#
# Usage:
#   bash scripts/check-scripts-doc.sh            # report + exit code
#   bash scripts/check-scripts-doc.sh --quiet    # exit code only
#   bash scripts/check-scripts-doc.sh --list     # one filename per line
#
# Exit codes:
#   0 = every script documented
#   1 = at least one script missing from README.md
#   2 = README.md not found
#
# Wired into daily-improve-context.sh (section: Script docs drift).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README="$SCRIPT_DIR/README.md"

QUIET=0
LIST_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --list) LIST_ONLY=1 ;;
  esac
done

[ -f "$README" ] || { echo "⚠️  scripts/README.md not found: $README" >&2; exit 2; }

MISSING=()
for script_path in "$SCRIPT_DIR"/*.sh; do
  [ -e "$script_path" ] || continue
  name="$(basename "$script_path")"
  if ! grep -qF "$name" "$README"; then
    MISSING+=("$name")
  fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
  [ "$QUIET" -eq 0 ] && [ "$LIST_ONLY" -eq 0 ] && echo "✅ All scripts documented in scripts/README.md"
  exit 0
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  printf '%s\n' "${MISSING[@]}"
else
  [ "$QUIET" -eq 0 ] && {
    echo "ℹ️  ${#MISSING[@]} script(s) missing from scripts/README.md:"
    printf '    - %s\n' "${MISSING[@]}"
    echo "    → Add a short entry to scripts/README.md (purpose + usage + integration)."
  }
fi
exit 1
