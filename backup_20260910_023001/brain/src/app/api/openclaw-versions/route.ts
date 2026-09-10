import { NextResponse } from "next/server";

export async function GET() {
  try {
    const res = await fetch(
      "https://api.github.com/repos/openclaw/openclaw/releases?per_page=20",
      { headers: { "Accept": "application/vnd.github.v3+json" }, next: { revalidate: 300 } }
    );
    const releases = await res.json();

    const stable = releases
      .filter((r: any) => !r.prerelease && !r.draft)
      .slice(0, 3)
      .map((r: any) => ({
        version: r.tag_name.replace(/^v/, ""),
        name: r.name,
        published: r.published_at,
        url: r.html_url
      }));

    return NextResponse.json({ versions: stable });
  } catch (e) {
    return NextResponse.json({ versions: [], error: String(e) }, { status: 500 });
  }
}
