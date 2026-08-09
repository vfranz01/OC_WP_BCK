import { NextResponse } from "next/server";
import fs from "fs";
import path from "path";

const MEMORY_DIR = "/home/node/.openclaw/workspace/memory";

function parseFrontmatter(content: string) {
  const fm: Record<string, string | string[]> = {};
  if (!content.startsWith("---")) return { fm, body: content };
  const end = content.indexOf("---", 3);
  if (end === -1) return { fm, body: content };
  const yaml = content.slice(3, end).trim();
  const body = content.slice(end + 3).trim();
  for (const line of yaml.split("\n")) {
    const [key, ...rest] = line.split(":");
    if (!key || !rest.length) continue;
    const val = rest.join(":").trim();
    if (val.startsWith("[") && val.endsWith("]")) {
      fm[key.trim()] = val.slice(1,-1).split(",").map(s => s.trim()).filter(Boolean);
    } else {
      fm[key.trim()] = val;
    }
  }
  return { fm, body };
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const q = searchParams.get("q")?.toLowerCase() || "";
  if (!q) return NextResponse.json([]);

  try {
    const files = fs.readdirSync(MEMORY_DIR).filter(f => f.endsWith(".md")).sort().reverse();
    const results = [];
    for (const file of files) {
      const content = fs.readFileSync(path.join(MEMORY_DIR, file), "utf8");
      const dateMatch = file.match(/^(\d{4}-\d{2}-\d{2})/);
      const date = dateMatch ? dateMatch[1] : file.replace(".md", "");
      const { fm, body } = parseFrontmatter(content);
      const title = (fm.title as string) || date;
      const tags = (fm.tags as string[]) || [];
      const summary = (fm.summary as string) || "";

      if (
        title.toLowerCase().includes(q) ||
        body.toLowerCase().includes(q) ||
        summary.toLowerCase().includes(q) ||
        tags.some(t => t.toLowerCase().includes(q))
      ) {
        const idx = body.toLowerCase().indexOf(q);
        const snippet = idx >= 0
          ? body.slice(Math.max(0, idx - 60), idx + 120).replace(/\n/g, " ")
          : summary || body.slice(0, 150);
        results.push({ date, title, tags, summary, snippet });
      }
    }
    return NextResponse.json(results);
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 });
  }
}
