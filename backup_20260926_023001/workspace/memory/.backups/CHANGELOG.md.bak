# Changelog

History of workspace automation improvements. Moved out of AGENTS.md on 2026-07-07 to keep the bootstrap file lean.

- **2026-06-20:** Added `compact-memory-promotions.sh` and archived raw auto-promoted MEMORY.md blocks into `memory/promoted-memory-archive.md`, bringing MEMORY.md back under its 5000-character target while preserving audit history.
- **2026-05-30:** Improved `daily-status-summary.sh` to create the daily memory file if it doesn't exist using `create_daily_memory_file.sh`. Also added a more explicit error message for when `TEMPLATE_FILE` is not found.
- **2026-05-16:** Created `sync-learnings.sh` to auto-scan memory files and suggest learnings to capture. Reduces manual effort keeping knowledge base updated.
- **2026-05-15:** Improved `daily-status-summary.sh` to double-check daily status creation and log errors if creation fails.
- **2026-05-11:** Created `HOST-SETUP-CRON.sh` to install all documented automation via host-level cron jobs (idempotent, one-time setup). Fixed critical gap: automation infrastructure was documented but not scheduled.
- **2026-05-10:** Added snapshot timestamp check to daily status summary.
