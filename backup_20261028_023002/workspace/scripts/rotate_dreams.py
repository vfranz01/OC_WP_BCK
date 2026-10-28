#!/usr/bin/env python3
"""rotate_dreams.py — Keep DREAMS.md from growing forever.

DREAMS.md is an append-only dream diary (written by the daily dreaming runs)
and it is committed to git on every workspace snapshot. Because the whole file
is re-stored on each commit, an unbounded diary means unbounded repo bloat
(each entry day adds another full-size blob).

This script moves diary entries older than a cutoff (default: 60 days) out of
DREAMS.md into per-month archive files under memory/dreaming/archive/, while
preserving the exact marker structure the dreaming system expects:

    <!-- openclaw:dreaming:diary:start --> ... <!-- openclaw:dreaming:diary:end -->
    <!-- openclaw:dreaming:deep:start -->  ... <!-- openclaw:dreaming:deep:end -->

Safety:
  - Writes a timestamped backup to memory/.backups/ (gitignored) before editing.
  - Only rewrites DREAMS.md when there is something to archive (idempotent).
  - Refuses to touch the file if no recognizable entries are found (parse-fail = no-op).

Usage:
  python3 scripts/rotate_dreams.py [--days 60] [--dry-run]

Exit codes: 0 = ok (archived or nothing to do), 1 = error/skipped.
"""

import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

WORKSPACE = Path(__file__).resolve().parent.parent
DREAMS = WORKSPACE / "DREAMS.md"
ARCHIVE_DIR = WORKSPACE / "memory" / "dreaming" / "archive"
BACKUP_DIR = WORKSPACE / "memory" / ".backups"

DIARY_START = "<!-- openclaw:dreaming:diary:start -->"
DIARY_END = "<!-- openclaw:dreaming:diary:end -->"

# Entry headings look like:  *April 12, 2026 at 3:00 AM*   or  ... 3:00 AM UTC*
HEADING_RE = re.compile(
    r"^\*(?P<month>[A-Z][a-z]+)\s+(?P<day>\d{1,2}),\s+(?P<year>\d{4})\s+at\s+.*\*\s*$"
)

MONTHS = {
    m: i + 1
    for i, m in enumerate(
        ["January", "February", "March", "April", "May", "June",
         "July", "August", "September", "October", "November", "December"]
    )
}


def parse_args():
    days, dry = 60, False
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--days" and i + 1 < len(args):
            days = int(args[i + 1])
            i += 2
        elif args[i] == "--dry-run":
            dry = True
            i += 1
        else:
            print(f"Unknown argument: {args[i]}")
            sys.exit(1)
    return days, dry


def split_sections(text):
    """Return (header, diary_body, footer) keeping markers in header/footer."""
    s = text.find(DIARY_START)
    e = text.find(DIARY_END)
    if s == -1 or e == -1 or e < s:
        raise ValueError("diary markers not found")
    header = text[: s + len(DIARY_START)]
    body = text[s + len(DIARY_START): e]
    footer = text[e:]
    return header, body, footer


def parse_entries(body):
    """Split diary body into (heading, entry_text) pairs.

    Entries are separated by '---' horizontal rules; each entry begins with a
    date heading line. Returns [] if no entry headings are found at all.
    """
    entries = []
    current = []       # lines of the current entry (including its heading)
    for line in body.splitlines():
        if line.strip() == "---":
            if current:
                entries.append(current)
                current = []
            continue
        current.append(line)
    if current:
        entries.append(current)

    parsed = []
    for lines in entries:
        # Drop leading blank lines, find heading
        idx = next((i for i, l in enumerate(lines) if l.strip()), None)
        if idx is None:
            continue  # whitespace-only block
        m = HEADING_RE.match(lines[idx].strip())
        if not m:
            # Block without a date heading (e.g. intro text) — keep verbatim.
            parsed.append((None, "\n".join(lines).strip("\n")))
            continue
        month = MONTHS.get(m.group("month"))
        if not month:
            parsed.append((None, "\n".join(lines).strip("\n")))
            continue
        date = datetime(int(m.group("year")), month, int(m.group("day")))
        parsed.append((date, "\n".join(lines).strip("\n")))
    return parsed


def main():
    days, dry = parse_args()
    if not DREAMS.exists():
        print("DREAMS.md not found — nothing to do.")
        return 0

    original_size = DREAMS.stat().st_size
    text = DREAMS.read_text(encoding="utf-8")

    try:
        header, body, footer = split_sections(text)
    except ValueError as exc:
        print(f"SKIP: {exc} — refusing to edit DREAMS.md.")
        return 1

    entries = parse_entries(body)
    dated = [e for e in entries if e[0] is not None]
    if not dated:
        print("SKIP: no dated diary entries recognized — no-op for safety.")
        return 1

    cutoff = datetime.utcnow() - timedelta(days=days)
    keep, archive = [], {}
    for date, entry in entries:
        if date is None or date >= cutoff:
            keep.append((date, entry))
        else:
            archive.setdefault(date.strftime("%Y-%m"), []).append(entry)

    if not archive:
        print(f"OK: nothing older than {days} days "
              f"({len(entries)} entries, {original_size} bytes) — no-op.")
        return 0

    if dry:
        total = sum(len(v) for v in archive.values())
        print(f"DRY-RUN: would archive {total} entries ({', '.join(sorted(archive))}); "
              f"keep {len(keep)}.")
        return 0

    # Backup before touching anything (memory/.backups is gitignored).
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup = BACKUP_DIR / f"DREAMS.pre-rotate-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}.bak"
    backup.write_text(text, encoding="utf-8")

    # Write per-month archives (append, oldest entry first).
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    archived_count = 0
    for month in sorted(archive):
        path = ARCHIVE_DIR / f"dreams-{month}.md"
        block = "\n\n---\n\n".join(archive[month])
        if path.exists():
            path.write_text(path.read_text(encoding="utf-8") + "\n\n---\n\n" + block + "\n",
                            encoding="utf-8")
        else:
            path.write_text(
                f"# Dream Archive — {month}\n\n"
                f"Rotated from DREAMS.md on {datetime.utcnow():%Y-%m-%d}. Entries oldest-first.\n\n"
                + block + "\n",
                encoding="utf-8",
            )
        archived_count += len(archive[month])

    # Rebuild DREAMS.md keeping recent entries, preserving marker structure.
    new_body = "\n\n---\n\n".join(e for _, e in keep)
    DREAMS.write_text(f"{header}\n{new_body}\n\n{footer}", encoding="utf-8")

    new_size = DREAMS.stat().st_size
    print(f"OK: archived {archived_count} entries to "
          f"{', '.join(sorted(archive))} -> memory/dreaming/archive/; "
          f"kept {len(keep)} recent. Size {original_size} -> {new_size} bytes. "
          f"Backup: {backup.relative_to(WORKSPACE)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
