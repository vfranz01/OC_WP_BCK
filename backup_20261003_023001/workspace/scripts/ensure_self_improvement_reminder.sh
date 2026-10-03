#!/bin/bash
# Ensure the SELF_IMPROVEMENT_REMINDER.md file exists with standard content.

REMINDER_FILE="/home/node/.openclaw/workspace/SELF_IMPROVEMENT_REMINDER.md"
TEMPLATE_CONTENT="# Self-Improvement Reminder

After completing tasks, evaluate if any learnings should be captured:

**Log when:**
- User corrects you → \`.learnings/LEARNINGS.md\`
- Command/operation fails → \`.learnings/ERRORS.md\`
- User wants missing capability → \`.learnings/FEATURE_REQUESTS.md\`
- You discover your knowledge was wrong → \`.learnings/LEARNINGS.md\`
- You find a better approach → \`.learnings/LEARNINGS.md\`

**Promote when pattern is proven:**
- Behavioral patterns → \`SOUL.md\`
- Workflow improvements → \`AGENTS.md\`
- Tool gotchas → \`TOOLS.md\`

Keep entries simple: date, title, what happened, what to do differently.

---

## Reactions
Reactions are enabled for Telegram in MINIMAL mode.
React ONLY when truly relevant:
- Acknowledge important user requests or confirmations
- Express genuine sentiment (humor, appreciation) sparingly
- Avoid reacting to routine messages or your own replies
Guideline: at most 1 reaction per 5-10 exchanges.
"

if [ ! -f "$REMINDER_FILE" ]; then
    echo "SELF_IMPROVEMENT_REMINDER.md not found. Creating it."
    mkdir -p "$(dirname "$REMINDER_FILE")"
    echo "$TEMPLATE_CONTENT" > "$REMINDER_FILE"
    # No need to chmod +x for a markdown file, but good practice for scripts.
    # For this purpose, we'll omit it as it's a content file, not an executable script.
    echo "Created $REMINDER_FILE with standard content."
else
    echo "SELF_IMPROVEMENT_REMINDER.md already exists."
fi
