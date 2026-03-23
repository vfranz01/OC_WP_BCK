import { notFound } from "next/navigation";
import fs from "fs/promises";
import path from "path";
import Link from "next/link";

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

export default async function MemoryLogPage({ params }: { params: Promise<{ date: string }> }) {
  const { date } = await params;
  const filePath = path.join(MEMORY_DIR, date + ".md");
  let raw: string;
  try {
    raw = await fs.readFile(filePath, "utf8");
  } catch {
    notFound();
  }
  const { fm, body } = parseFrontmatter(raw!);
  const tags = (fm.tags as string[]) || [];
  const projects = (fm.projects as string[]) || [];
  const summary = fm.summary as string || "";

  return (
    <div style={{padding:"2rem",fontFamily:"system-ui,sans-serif",color:"#e5e5e5",maxWidth:900}}>
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"1rem"}}>
        <h1 style={{margin:0,color:"#60a5fa"}}>Memory Log – {date}</h1>
        <Link href="/memory" style={{color:"#60a5fa",fontSize:14}}>← Zurück</Link>
      </div>
      {summary && <p style={{color:"#aaa",fontSize:14,marginBottom:"1rem",fontStyle:"italic"}}>{summary}</p>}
      {tags.length > 0 && (
        <div style={{display:"flex",gap:6,flexWrap:"wrap",marginBottom:"1rem"}}>
          {tags.map(tag => (
            <span key={tag} style={{background:"#1e3a5f",color:"#60a5fa",borderRadius:4,padding:"2px 8px",fontSize:12}}>#{tag}</span>
          ))}
        </div>
      )}
      {projects.length > 0 && (
        <div style={{display:"flex",gap:6,flexWrap:"wrap",marginBottom:"1.5rem"}}>
          {projects.map(p => (
            <span key={p} style={{background:"#1a2e1a",color:"#4ade80",borderRadius:4,padding:"2px 8px",fontSize:12}}>📁 {p}</span>
          ))}
        </div>
      )}
      <div style={{whiteSpace:"pre-wrap",backgroundColor:"#1a1a1a",padding:"1.5rem",borderRadius:8,border:"1px solid #2a2a2a",fontSize:14,lineHeight:1.6}}>
        {body}
      </div>
    </div>
  );
}
