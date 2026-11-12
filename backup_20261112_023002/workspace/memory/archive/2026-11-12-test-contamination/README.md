# Test contamination incident — 2026-11-12

Read-only evidence retained from the live workspace and /tmp. The 2026-11-09
throwaway scripts in this directory hardcoded the production workspace and
explicitly replaced blockers, cleared nudge state/queue, or inserted test data.
`test_edge_case.sh.txt` exactly matches the bogus blocker left in memory.
Do not run the archived scripts.

Restored `memory/blockers.md`, `memory/nudge-state.log`, and the missing
`memory/undelivered-nudges.md` byte-for-byte from Git revision
`98cb72a^` (the last commit before the contamination was checkpointed).
All three restored hashes were verified against that revision. The blocker is
historical and its WordPress credentials remain missing on 2026-11-12; service
status must still be checked before any future action. No live nudge was sent.

Archived the original contaminated blocker and state, and the notification
queue before removing only the recognizable `test-script` / `Test message
body` item through `notify-queue.py remove 47dde8b3bee8`. The real latest
backup notification was retained. No queued reminder was flushed.

Future regressions must run copied scripts in temporary workspaces, with mock
senders; do not repurpose the live blocker/queue/state files as fixtures.
