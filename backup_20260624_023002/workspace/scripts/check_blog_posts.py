#!/usr/bin/env python3
"""Check whether the latest Ecomunivers blog post was published today.

Uses only the Python standard library so cron/heartbeat checks do not depend on
optional packages like `requests` being installed in the OpenClaw runtime.
"""

from datetime import datetime, timezone
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

URL = "https://digital.ecomunivers.com/wp-json/wp/v2/posts?per_page=1"


def main() -> int:
    request = Request(URL, headers={"User-Agent": "OpenClaw-health-check/1.0"})
    try:
        with urlopen(request, timeout=20) as response:
            posts = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"Error checking blog posts: {exc}")
        return 0  # Status summary should record the issue, not fail the whole run.

    if not posts:
        print("No blog posts found.")
        return 0

    raw_date = posts[0].get("date_gmt") or posts[0].get("date")
    if not raw_date:
        print("Latest blog post has no date field.")
        return 0

    try:
        post_date = datetime.fromisoformat(raw_date.replace("Z", "+00:00")).date()
    except ValueError:
        print(f"Could not parse latest blog post date: {raw_date}")
        return 0

    today_utc = datetime.now(timezone.utc).date()
    if post_date == today_utc:
        print("New blog post published today.")
    else:
        print("No new blog post published today.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
