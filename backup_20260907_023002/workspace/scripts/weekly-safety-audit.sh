#!/usr/bin/env bash
# Weekly Safety Audit — Run critical validation checks
# Purpose: Comprehensive safety audit to ensure critical rules are in place
# Usage: bash weekly-safety-audit.sh
# Recommended: Run once per week (e.g., Sundays)

WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AUDIT_LOG="${AUDIT_LOG:-$WORKSPACE_DIR/memory/weekly-safety-audit.log}"
MEMORY_MAX_BYTES="${MEMORY_MAX_BYTES:-5000}"

mkdir -p "$(dirname "$AUDIT_LOG")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Weekly Safety Audit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Starting: $(date '+%Y-%m-%d %H:%M UTC')"
echo "---" >> "$AUDIT_LOG"
echo "Weekly Safety Audit - $(date '+%Y-%m-%d %H:%M UTC')" >> "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"

ISSUES=0

# 1. Validate critical rules
echo "1️⃣  Validating critical rules..."
if bash "$WORKSPACE_DIR/scripts/validate_critical_rules.sh" >> "$AUDIT_LOG" 2>&1; then
  echo "   ✅ Critical rules validated"
else
  echo "   ❌ Critical rules validation FAILED"
  ((ISSUES++))
fi
echo "" >> "$AUDIT_LOG"

# 2. Check file permissions on critical files
echo "2️⃣  Checking file permissions..."
PERM_ISSUES=0
for file in "$WORKSPACE_DIR"/{MEMORY.md,AGENTS.md,TOOLS.md,SOUL.md,USER.md}; do
  if [ -f "$file" ]; then
    # MEMORY.md contains private long-term context; no group/other access is allowed.
    if [[ "$file" == *"MEMORY.md" ]]; then
      MODE=$(stat -c '%a' "$file")
      if (( (8#$MODE & 8#077) != 0 )); then
        echo "   ⚠️  WARNING: $file mode is $MODE (should be 600; group/other access detected)" >> "$AUDIT_LOG"
        ((PERM_ISSUES++))
      fi
    fi
  fi
done
if [ $PERM_ISSUES -eq 0 ]; then
  echo "   ✅ File permissions OK"
else
  echo "   ⚠️  $PERM_ISSUES permission issue(s) found"
  ((ISSUES++))
fi
echo "" >> "$AUDIT_LOG"

# 3. Verify backup freshness
echo "3️⃣  Verifying backup system..."
if bash "$WORKSPACE_DIR/scripts/validate_backup.sh" >> "$AUDIT_LOG" 2>&1; then
  echo "   ✅ Backup system healthy"
else
  echo "   ⚠️  Backup validation issues detected"
  ((ISSUES++))
fi
echo "" >> "$AUDIT_LOG"

# 4. Check memory file structure and archive raw auto-promotions
echo "4️⃣  Checking memory hygiene..."
MEMORY_ISSUES=0
if [ ! -f "$WORKSPACE_DIR/MEMORY.md" ]; then
  echo "   ⚠️  MEMORY.md missing" >> "$AUDIT_LOG"
  ((MEMORY_ISSUES++))
elif [ ! -s "$WORKSPACE_DIR/MEMORY.md" ]; then
  echo "   ⚠️  MEMORY.md is empty" >> "$AUDIT_LOG"
  ((MEMORY_ISSUES++))
else
  MEMORY_LINES=$(wc -l < "$WORKSPACE_DIR/MEMORY.md")
  if [ "$MEMORY_LINES" -lt 5 ]; then
    echo "   ⚠️  MEMORY.md very small ($MEMORY_LINES lines)" >> "$AUDIT_LOG"
    ((MEMORY_ISSUES++))
  fi

  PROMOTION_COUNT=$(grep -c '^## Promoted From Short-Term Memory' "$WORKSPACE_DIR/MEMORY.md" || true)
  if [ "$PROMOTION_COUNT" -gt 0 ]; then
    echo "   ℹ️  Archiving $PROMOTION_COUNT raw auto-promotion block(s)" | tee -a "$AUDIT_LOG"
    if MAX_BYTES="$MEMORY_MAX_BYTES" bash "$WORKSPACE_DIR/scripts/compact-memory-promotions.sh" >> "$AUDIT_LOG" 2>&1; then
      echo "   ✅ Raw auto-promotions archived"
    else
      echo "   ⚠️  Auto-promotion compaction failed" | tee -a "$AUDIT_LOG"
      ((MEMORY_ISSUES++))
    fi
  fi

  MEMORY_BYTES=$(wc -c < "$WORKSPACE_DIR/MEMORY.md")
  if [ "$MEMORY_BYTES" -gt "$MEMORY_MAX_BYTES" ]; then
    echo "   ⚠️  MEMORY.md is $MEMORY_BYTES bytes (target: <= $MEMORY_MAX_BYTES); manual distillation needed" >> "$AUDIT_LOG"
    ((MEMORY_ISSUES++))
  fi
fi
if [ $MEMORY_ISSUES -eq 0 ]; then
  echo "   ✅ Memory file healthy and curated"
else
  echo "   ⚠️  Memory hygiene issues found"
  ((ISSUES++))
fi
echo "" >> "$AUDIT_LOG"

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ISSUES -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED"
  echo "---" >> "$AUDIT_LOG"
  echo "Result: ✅ PASS" >> "$AUDIT_LOG"
  echo "" >> "$AUDIT_LOG"
  exit 0
else
  echo "⚠️  FOUND $ISSUES ISSUE(S) — REVIEW LOG"
  echo "---" >> "$AUDIT_LOG"
  echo "Result: ⚠️  FAIL ($ISSUES issues)" >> "$AUDIT_LOG"
  echo "" >> "$AUDIT_LOG"
  echo ""
  echo "📋 Full audit log: $AUDIT_LOG"
  exit 1
fi
