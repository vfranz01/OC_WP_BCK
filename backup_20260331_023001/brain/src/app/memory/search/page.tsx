"use client";
import { useState } from "react";
import Link from "next/link";

interface Result {
  date: string;
  title: string;
  tags: string[];
  summary: string;
  snippet: string;
}

export default function SearchPage() {
  const [q, setQ] = useState("");
  const [results, setResults] = useState<Result[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const search = async () => {
    if (!q.trim()) return;
    setLoading(true);
    setSearched(true);
    const res = await fetch("/api/memory/search?q=" + encodeURIComponent(q));
    setResults(await res.json());
    setLoading(false);
  };

  return (
    <div style={{padding:"2rem",fontFamily:"system-ui",color:"#e5e5e5",maxWidth:900}}>
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"1.5rem"}}>
        <h1 style={{margin:0,color:"#60a5fa"}}>🔍 Memory Search</h1>
        <Link href="/memory" style={{color:"#60a5fa",fontSize:14}}>← Zurück</Link>
      </div>
      <div style={{display:"flex",gap:8,marginBottom:"2rem"}}>
        <input
          value={q}
          onChange={e => setQ(e.target.value)}
          onKeyDown={e => e.key === "Enter" && search()}
          placeholder="Suche in Memory Logs..."
          style={{flex:1,background:"#1a1a1a",border:"1px solid #2a2a2a",borderRadius:6,padding:"10px 14px",color:"#e5e5e5",fontSize:14,outline:"none"}}
        />
        <button
          onClick={search}
          style={{background:"#2563eb",color:"#fff",border:"none",borderRadius:6,padding:"10px 20px",fontSize:14,cursor:"pointer"}}
        >
          Search
        </button>
      </div>

      {loading && <p style={{color:"#aaa"}}>Suche...</p>}

      {searched && !loading && results.length === 0 && (
        <p style={{color:"#888"}}>Keine Ergebnisse für "{q}"</p>
      )}

      <div style={{display:"flex",flexDirection:"column",gap:"1rem"}}>
        {results.map((r, i) => (
          <div key={i} style={{background:"#1a1a1a",borderRadius:8,padding:"1.25rem",border:"1px solid #2a2a2a"}}>
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:6}}>
              <Link href={"/memory/" + r.date} style={{color:"#60a5fa",fontWeight:"bold",fontSize:15}}>{r.title}</Link>
              <span style={{color:"#888",fontSize:12}}>{r.date}</span>
            </div>
            {r.tags.length > 0 && (
              <div style={{display:"flex",gap:4,flexWrap:"wrap",marginBottom:8}}>
                {r.tags.map(t => (
                  <Link key={t} href={"/memory/tags?tag=" + t} style={{background:"#1e3a5f",color:"#60a5fa",borderRadius:4,padding:"2px 8px",fontSize:11,textDecoration:"none"}}>#{t}</Link>
                ))}
              </div>
            )}
            {r.snippet && (
              <p style={{color:"#aaa",fontSize:13,margin:0,lineHeight:1.5}}>...{r.snippet}...</p>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
