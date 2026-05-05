"use client";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { Suspense } from "react";

interface TagMap {
  [tag: string]: Array<{date: string, title: string, summary: string}>;
}

function TagsContent() {
  const searchParams = useSearchParams();
  const activeTag = searchParams.get("tag") || "";
  const [tagMap, setTagMap] = useState<TagMap>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/memory/tags").then(r => r.json()).then(d => { setTagMap(d); setLoading(false); });
  }, []);

  if (loading) return <p style={{color:"#aaa"}}>Lade Tags...</p>;

  const tags = Object.keys(tagMap).sort();
  const activeLogs = activeTag ? tagMap[activeTag] || [] : [];

  return (
    <div style={{display:"flex",gap:"2rem"}}>
      <div style={{width:200,flexShrink:0}}>
        <h2 style={{fontSize:14,color:"#888",marginBottom:"1rem",textTransform:"uppercase",letterSpacing:1}}>Alle Tags</h2>
        <div style={{display:"flex",flexDirection:"column",gap:4}}>
          {tags.map(tag => (
            <Link
              key={tag}
              href={"/memory/tags?tag=" + tag}
              style={{
                display:"flex",justifyContent:"space-between",alignItems:"center",
                padding:"6px 10px",borderRadius:6,textDecoration:"none",
                background: activeTag === tag ? "#1e3a5f" : "transparent",
                color: activeTag === tag ? "#60a5fa" : "#aaa",
                fontSize:13
              }}
            >
              <span>#{tag}</span>
              <span style={{background:"#2a2a2a",borderRadius:10,padding:"1px 6px",fontSize:11}}>{tagMap[tag].length}</span>
            </Link>
          ))}
        </div>
      </div>

      <div style={{flex:1}}>
        {activeTag ? (
          <>
            <h2 style={{margin:"0 0 1rem",color:"#60a5fa"}}>#{activeTag} <span style={{color:"#888",fontSize:14,fontWeight:"normal"}}>({activeLogs.length} Logs)</span></h2>
            <div style={{display:"flex",flexDirection:"column",gap:"0.75rem"}}>
              {activeLogs.map((log, i) => (
                <div key={i} style={{background:"#1a1a1a",borderRadius:8,padding:"1rem",border:"1px solid #2a2a2a"}}>
                  <div style={{display:"flex",justifyContent:"space-between",marginBottom:4}}>
                    <Link href={"/memory/" + log.date} style={{color:"#60a5fa",fontWeight:"bold",fontSize:14}}>{log.title}</Link>
                    <span style={{color:"#888",fontSize:12}}>{log.date}</span>
                  </div>
                  {log.summary && <p style={{color:"#aaa",fontSize:13,margin:0}}>{log.summary}</p>}
                </div>
              ))}
            </div>
          </>
        ) : (
          <div style={{color:"#888",textAlign:"center",marginTop:"4rem"}}>
            <p style={{fontSize:32}}>🏷️</p>
            <p>Wähle einen Tag aus der Liste</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default function TagsPage() {
  return (
    <div style={{padding:"2rem",fontFamily:"system-ui",color:"#e5e5e5",maxWidth:1100}}>
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"1.5rem"}}>
        <h1 style={{margin:0,color:"#60a5fa"}}>🏷️ Memory Tags</h1>
        <Link href="/memory" style={{color:"#60a5fa",fontSize:14}}>← Zurück</Link>
      </div>
      <Suspense fallback={<p style={{color:"#aaa"}}>Lade...</p>}>
        <TagsContent />
      </Suspense>
    </div>
  );
}
