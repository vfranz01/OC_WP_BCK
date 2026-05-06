#!/bin/bash
# Validate the Critical Rules defined in MEMORY.md.

# Define the expected rules
declare -a expected_rules=(
  "Snapshot before ANY config change"
  "Never restart OpenClaw unless instructed by Volker"
  "Never run `openclaw` directly on host"
  "Volker has lost 2 previous installations (3+ days each). Non-negotiable."
)

# Function to check if a rule exists
check_rule() {
  local rule="$1"
  if grep -qF "$rule" /home/node/.openclaw/workspace/MEMORY.md; then
    echo "✅ Rule found: "$rule""
  else
    echo "❌ Rule missing: "$rule""
    return 1 # Indicate an error
  fi
}

# Iterate through the expected rules and check them
rule_found=true
for rule in "${expected_rules[@]}"; do
  if ! check_rule "$rule"; then
    rule_found=false
  fi
done

# Exit with an error if any rule is missing
if ! $rule_found; then
  echo "Validation failed.  See above for missing rules."
  exit 1
fi

echo "✅ All critical rules validated successfully."

bash /home/node/.openclaw/workspace/scripts/snapshot.sh "Critical rules validation"

