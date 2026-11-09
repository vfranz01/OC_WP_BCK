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

export async function GET() {
  try {
    const files = fs.readdirSync(MEMORY_DIR).filter(f => f.endsWith(".md")).sort().reverse();
    const tagMap: Record<string, Array<{date: string, title: string, summary: string}>> = {};

    for (const file of files) {
      const content = fs.readFileSync(path.join(MEMORY_DIR, file), "utf8");
      const dateMatch = file.match(/^(\d{4}-\d{2}-\d{2})/);
      const date = dateMatch ? dateMatch[1] : file.replace(".md", "");
      const { fm } = parseFrontmatter(content);
      const title = (fm.title as string) || date;
      const tags = (fm.tags as string[]) || [];
      const summary = (fm.summary as string) || "";

      for (const tag of tags) {
        if (!tagMap[tag]) tagMap[tag] = [];
        tagMap[tag].push({ date, title, summary });
      }
    }
    return NextResponse.json(tagMap);
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 });
  }
}
