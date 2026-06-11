import requests
from datetime import datetime

url = "https://digital.ecomunivers.com/wp-json/wp/v2/posts?per_page=1"
try:
    response = requests.get(url)
    response.raise_for_status()  # Raises an exception for bad status codes
    posts = response.json()
    if posts:
        most_recent_post_date = datetime.fromisoformat(posts[0]['date'][:-1]).date()
        today = datetime.now().date()
        if most_recent_post_date == today:
            print("New blog post published today.")
        else:
            print("No new blog post published today.")
    else:
        print("No blog posts found.")

except requests.exceptions.RequestException as e:
    print(f"Error checking blog posts: {e}")
