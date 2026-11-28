#!/bin/bash
# redact-secrets.sh — Scan workspace text files for credential patterns and
# redact them in place, so commit-workspace.sh's secret scan can pass again.
#
# Why: memory/dreaming/*.md (session-transcript summaries) and other generated
# files can accidentally quote real credentials (e.g. a WooCommerce key copied
# from a debugging session). commit-workspace.sh then refuses EVERY checkpoint
# until someone hand-edits the file. This script automates the hand-editing.
#
# Design notes:
#   • Patterns kept in sync with commit-workspace.sh SECRET_PATTERNS.
#   • TOOLS.md is skipped — it is the documented, by-design key location.
#   • Redaction preserves the surrounding text; matches are replaced with
#     [REDACTED:<pattern-name>] so it stays obvious what was removed and where
#     the real value lives (TOOLS.md).
#   • Dry-run by default: shows what WOULD be redacted. Use --apply to write.
#
# Usage:
#   bash scripts/redact-secrets.sh            # dry-run
#   bash scripts/redact-secrets.sh --apply    # redact in place
#   bash scripts/redact-secrets.sh --apply path/to/file.md  # single file
#
# Exit: 0 = clean or redacted, 1 = usage error

set -euo pipefail

APPLY=0
FILES=()
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) FILES+=("$arg") ;;
  esac
done

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"

# pattern-name:regex pairs (name used in the redaction marker)
declare -A PATTERNS=(
  [woo-consumer-key]='ck_[a-f0-9]{32,}'
  [woo-consumer-secret]='cs_[a-f0-9]{32,}'
  [github-pat]='ghp_[A-Za-z0-9]{36}'
  [github-finegrained-pat]='github_pat_[A-Za-z0-9_]{22,}'
  [aws-access-key]='AKIA[0-9A-Z]{16}'
  [stripe-live]='sk_live_[A-Za-z0-9]{16,}'
  [openai-style-key]='sk-[A-Za-z0-9]{20,}'
  [slack-token]='xox[baprs]-[A-Za-z0-9-]{10,}'
)

if [ ${#FILES[@]} -eq 0 ]; then
  # Default scan set: generated text files that might quote secrets.
  # TOOLS.md excluded by design (documented key location).
  while IFS= read -r -d '' f; do FILES+=("$f"); done < <(
    find memory .learnings outbox -type f \( -name '*.md' -o -name '*.json' -o -name '*.txt' \) \
      ! -name 'undelivered-*' -print0 2>/dev/null
  )
fi

total=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "⚠️  skip (not a file): $f"; continue; }
  [ "$f" = "TOOLS.md" ] && continue
  file_hits=0
  for name in "${!PATTERNS[@]}"; do
    pat="${PATTERNS[$name]}"
    if grep -qE "$pat" "$f" 2>/dev/null; then
      count=$(grep -oE "$pat" "$f" | wc -l)
      file_hits=$((file_hits + count))
      echo "$([ $APPLY -eq 1 ] && echo '🔴 redacting' || echo '🟡 would redact'): $f — $count × $name"
      if [ $APPLY -eq 1 ]; then
        sed -i -E "s/$pat/[REDACTED:$name]/g" "$f"
      fi
    fi
  done
  total=$((total + file_hits))
done

# Private key blocks (multiline) — handle separately with perl
PRIVATE_KEY_RE='s/-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/[REDACTED:private-key-block]/gs'
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  [ "$f" = "TOOLS.md" ] && continue
  if grep -q 'BEGIN.*PRIVATE KEY-----' "$f" 2>/dev/null; then
    echo "$([ $APPLY -eq 1 ] && echo '🔴 redacting' || echo '🟡 would redact'): $f — private-key block"
    total=$((total + 1))
    [ $APPLY -eq 1 ] && perl -0777 -pi -e "$PRIVATE_KEY_RE" "$f"
  fi
done

if [ "$total" -eq 0 ]; then
  echo "✅ Clean — no credential patterns found in ${#FILES[@]} file(s)"
elif [ $APPLY -eq 1 ]; then
  echo "✅ Redacted $total match(es). Files ready for git checkpoint."
else
  echo "ℹ️  Found $total match(es). Re-run with --apply to redact in place."
fi
