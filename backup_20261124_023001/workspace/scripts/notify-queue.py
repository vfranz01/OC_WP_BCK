#!/usr/bin/env python3
"""notify-queue.py — persistent queue for notifications that never reached Volker.

Problem this fixes (2026-10-20): telegram-send.sh treats delivery as verified
(ok:true) and returns non-zero on failure, but most callers only log a warning
and move on. During the Telegram 401 outage (since 2026-09-23) every script
alert — backup validation, blog monitors, recovery checks — evaporated. Only
blocker nudges had their own queue (send-blocker-nudges.sh → undelivered-nudges.md).

This queue is the generic safety net: whatever a script tried to tell Volker is
persisted verbatim, deduplicated, and can be flushed in one command once the
token works again.

File format (memory/undelivered-notifications.md) — one entry per notification:

    ## <UTC timestamp> — <source> — <subject>
    <!-- fp: <sha1 of body> -->
    <body>

    <!-- end-entry -->

The fp marker makes re-append idempotent: an outage that retries the same
alert every day keeps ONE copy instead of 27.

Subcommands:
    append --subject S --source SRC [--text TEXT | stdin]
    list            JSON array of {id, ts, source, subject, text}
    remove ID       drop one delivered entry
    status          human summary (count + oldest age)
    ids             newline-separated entry ids
"""

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone

WORKSPACE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE = os.path.join(WORKSPACE, "memory", "undelivered-notifications.md")

HEADER = """---
date: {today}
title: Undelivered Notifications
tags: ["automation", "incident", "telegram"]
projects: [general]
summary: Generic notification queue — messages a script could not deliver.
---

<!-- undelivered-notifications.md — notifications whose delivery FAILED.
     Written by scripts/notify-queue.py (called from scripts/telegram-send.sh).
     Do not hand-edit entries. Flush after Telegram is restored:
       bash scripts/telegram-send.sh --flush
     Blocker nudges have their own queue: memory/undelivered-nudges.md -->

"""

ENTRY_RE = re.compile(
    # NOTE: subject must stop at end-of-line. With re.DOTALL a greedy `.*`
    # skipped the first `<!-- fp:` marker and swallowed the whole next entry
    # (observed while testing: two entries collapsed into one, corrupting the
    # queue on every append).
    r"^## (?P<ts>\d{4}-\d\d-\d\d \d\d:\d\d UTC) — (?P<source>[^—\n]+?) — (?P<subject>[^\n]*)\n"
    r"<!-- fp: (?P<fp>[0-9a-f]{40}) -->\n"
    r"(?P<text>.*?)\n<!-- end-entry -->\n?",
    re.MULTILINE | re.DOTALL,
)


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def fingerprint(text: str) -> str:
    return hashlib.sha1(text.strip().encode("utf-8")).hexdigest()


def read_entries():
    if not os.path.exists(QUEUE):
        return ""
    with open(QUEUE, encoding="utf-8") as fh:
        return fh.read()


def parse(raw: str):
    entries = []
    for m in ENTRY_RE.finditer(raw):
        entries.append(
            {
                "id": m.group("fp")[:12],
                "fp": m.group("fp"),
                "ts": m.group("ts"),
                "source": m.group("source").strip(),
                "subject": m.group("subject").strip(),
                "text": m.group("text").strip("\n"),
            }
        )
    return entries


def write_entries(entries):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    body = HEADER.format(today=today)
    for e in entries:
        body += (
            f"## {e['ts']} — {e['source']} — {e['subject']}\n"
            f"<!-- fp: {e['fp']} -->\n"
            f"{e['text']}\n"
            f"<!-- end-entry -->\n\n"
        )
    os.makedirs(os.path.dirname(QUEUE), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(QUEUE), prefix=".notify-queue.")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(body)
    # mkstemp creates 0600; the rest of memory/*.md is world-readable and the
    # weekly safety audit flags permission drift.
    os.chmod(tmp, 0o644)
    os.replace(tmp, QUEUE)


def cmd_append(args) -> int:
    text = args.text if args.text is not None else sys.stdin.read()
    text = text.strip()
    if not text:
        print("notify-queue: empty text — nothing queued", file=sys.stderr)
        return 2

    fp = fingerprint(text)
    subject = args.subject or text.splitlines()[0][:70]
    source = args.source or "telegram-send"

    entries = parse(read_entries())
    if any(e["fp"] == fp for e in entries):
        print(f"dedupe:{fp[:12]}")
        return 0

    # Same subject from the same source is superseded, not stacked: a daily
    # "backup failed" alert should not accumulate 30 near-identical copies.
    entries = [
        e for e in entries
        if not (e["source"] == source and e["subject"] == subject)
    ]
    entries.append(
        {
            "id": fp[:12],
            "fp": fp,
            "ts": now_utc(),
            "source": source,
            "subject": subject,
            "text": text,
        }
    )
    write_entries(entries)
    print(f"queued:{fp[:12]}")
    return 0


def cmd_list(_args) -> int:
    print(json.dumps(parse(read_entries()), ensure_ascii=False))
    return 0


def cmd_remove(args) -> int:
    entries = parse(read_entries())
    kept = [e for e in entries if e["id"] != args.id]
    if len(kept) == len(entries):
        return 1
    write_entries(kept)
    return 0


def cmd_ids(_args) -> int:
    for e in parse(read_entries()):
        print(e["id"])
    return 0


def cmd_export(args) -> int:
    """Write each entry to DIR/<id>.txt + DIR/<id>.meta (ts, source, subject)."""
    os.makedirs(args.dir, exist_ok=True)
    entries = parse(read_entries())
    for e in entries:
        with open(os.path.join(args.dir, e["id"] + ".txt"), "w", encoding="utf-8") as fh:
            fh.write(e["text"])
        with open(os.path.join(args.dir, e["id"] + ".meta"), "w", encoding="utf-8") as fh:
            fh.write("\t".join([e["ts"], e["source"], e["subject"]]) + "\n")
        print(e["id"])
    return 0


def cmd_status(_args) -> int:
    entries = parse(read_entries())
    if not entries:
        print("Queue empty — no undelivered notifications.")
        return 0
    print(f"Undelivered notifications: {len(entries)}")
    for e in entries:
        print(f"  • {e['ts']} [{e['source']}] {e['subject']}")
    print("→ Flush after Telegram works: bash scripts/telegram-send.sh --flush")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("append")
    a.add_argument("--subject", default="")
    a.add_argument("--source", default="")
    a.add_argument("--text", default=None)
    a.set_defaults(func=cmd_append)

    sub.add_parser("list").set_defaults(func=cmd_list)
    sub.add_parser("status").set_defaults(func=cmd_status)
    sub.add_parser("ids").set_defaults(func=cmd_ids)

    x = sub.add_parser("export")
    x.add_argument("dir")
    x.set_defaults(func=cmd_export)

    r = sub.add_parser("remove")
    r.add_argument("id")
    r.set_defaults(func=cmd_remove)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
