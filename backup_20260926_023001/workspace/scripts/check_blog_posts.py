#!/usr/bin/env python3
"""
Check WordPress Blog Posts for digital.ecomunivers.com
Queries the WP REST API for posts published on the current UTC day (or recent days).
Falls back gracefully on timeouts or connection errors without failing the status check.
"""

import sys
import json
import urllib.request
import urllib.error
from datetime import datetime, timezone

WP_API_URL = "https://digital.ecomunivers.com/wp-json/wp/v2/posts?per_page=5"
TIMEOUT_SECS = 10

def check_posts():
    req = urllib.request.Request(
        WP_API_URL,
        headers={"User-Agent": "OpenClaw-HealthCheck/1.0"}
    )
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECS) as resp:
            if resp.status != 200:
                print(f"⚠️ WP API returned HTTP {resp.status}")
                return 0
            
            data = json.loads(resp.read().decode("utf-8"))
            if not isinstance(data, list):
                print(f"⚠️ Unexpected WP API response format")
                return 0
            
            today_posts = [p for p in data if p.get("date", "").startswith(today_str)]
            if today_posts:
                post = today_posts[0]
                title = post.get("title", {}).get("rendered", "Untitled")
                link = post.get("link", "")
                print(f"✅ ecomunivers blog post found for today ({today_str}): '{title}' ({link})")
            else:
                latest = data[0] if data else None
                if latest:
                    lat_date = latest.get("date", "unknown")
                    lat_title = latest.get("title", {}).get("rendered", "Untitled")
                    print(f"ℹ️ No ecomunivers blog post for today ({today_str}). Latest: '{lat_title}' on {lat_date}")
                else:
                    print(f"ℹ️ No blog posts found on digital.ecomunivers.com")
            return 0
    except urllib.error.HTTPError as e:
        print(f"⚠️ WP API check failed (HTTP {e.code}): {e.reason}")
        return 0
    except urllib.error.URLError as e:
        print(f"⚠️ WP API check failed (network/unreachable): {e.reason}")
        return 0
    except Exception as e:
        print(f"⚠️ WP API check encountered error: {e}")
        return 0

if __name__ == "__main__":
    sys.exit(check_posts())
