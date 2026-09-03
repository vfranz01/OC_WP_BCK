"use client";
import { useEffect, useState } from "react";
import Link from "next/link";

interface Stats {
  totalLogs: number;
  totalLines: number;
  byMonth: Record<string, number>;
  heatmap: Record<string, number>;
  keywords: Record<string, number>;
  errors: Array<{date: string, lines: string[]}>;
}

export default function StatsPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    fetch("/api/memory/stats").then(r => r.json()).then(d => { setStats(d); setLoading(false); }).catch(() => setLoading(false));
  }, []);
  if (loading) return <div style={{padding:"2rem",color:"#aaa"}}>Analysiere...</div>;
  if (!stats) return <div style={{padding:"2rem",color:"#f87171"}}>Fehler beim Laden.</div>;
  const months = Object.entries(stats.byMonth).sort();
  const maxMonth = Math.max(...months.map(m => m[1]), 1);
  const keywords = Object.entries(stats.keywords).sort((a, b) => b[1] - a[1]);
  const maxKw = Math.max(...keywords.map(k => k[1]), 1);
  return (
    <div style={{padding:"2rem",fontFamily:"system-ui",color:"#e5e5e5",maxWidth:900}}>
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"1.5rem"}}>
        <h1 style={{margin:0,color:"#60a5fa"}}>Memory Stats</h1>
        <Link href="/memory" style={{color:"#60a5fa",fontSize:14}}>Zuruck</Link>
      </div>
      <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:"1rem",marginBottom:"2rem"}}>
        {([{label:"Gesamt Logs",value:stats.totalLogs},{label:"Gesamt Zeilen",value:stats.totalLines},{label:"Monate aktiv",value:Object.keys(stats.byMonth).length}] as {label:string,value:number}[]).map(c => (
          <div key={c.label} style={{background:"#1a1a1a",borderRadius:8,padding:"1rem",border:"1px solid #2a2a2a",textAlign:"center"}}>
            <div style={{fontSize:32,fontWeight:"bold",color:"#60a5fa"}}>{c.value}</div>
            <div style={{fontSize:13,color:"#888",marginTop:4}}>{c.label}</div>
          </div>
        ))}
      </div>
      <div style={{background:"#1a1a1a",borderRadius:8,padding:"1.5rem",marginBottom:"1.5rem",border:"1px solid #2a2a2a"}}>
        <h2 style={{margin:"0 0 1rem",fontSize:16,color:"#ccc"}}>Logs pro Monat</h2>
        <div style={{display:"flex",flexDirection:"column",gap:8}}>
          {months.map(([month, count]) => (
            <div key={month} style={{display:"flex",alignItems:"center",gap:"1rem"}}>
              <span style={{width:80,fontSize:13,color:"#888"}}>{month}</span>
              <div style={{flex:1,background:"#111",borderRadius:4,height:20,overflow:"hidden"}}>
                <div style={{width:((count/maxMonth)*100)+"%",height:"100%",background:"#2563eb",borderRadius:4}}/>
              </div>
              <span style={{fontSize:13,color:"#60a5fa",width:30}}>{count}</span>
            </div>
          ))}
        </div>
      </div>
      <div style={{background:"#1a1a1a",borderRadius:8,padding:"1.5rem",marginBottom:"1.5rem",border:"1px solid #2a2a2a"}}>
        <h2 style={{margin:"0 0 1rem",fontSize:16,color:"#ccc"}}>Keywords</h2>
        <div style={{display:"flex",flexWrap:"wrap",gap:8}}>
          {keywords.map(([word, count]) => (
            <span key={word} style={{fontSize:12+(count/maxKw)*16,opacity:0.4+(count/maxKw)*0.6,color:"#60a5fa"}}>{word}</span>
          ))}
        </div>
      </div>
      <div style={{background:"#1a1a1a",borderRadius:8,padding:"1.5rem",border:"1px solid #2a2a2a"}}>
        <h2 style={{margin:"0 0 1rem",fontSize:16,color:"#ccc"}}>Fehler und Probleme</h2>
        {stats.errors.length === 0 ? <p style={{color:"#888",fontSize:13}}>Keine Fehler gefunden.</p> : (
          <div style={{display:"flex",flexDirection:"column",gap:"1rem"}}>
            {stats.errors.map((e, i) => (
              <div key={i} style={{borderLeft:"3px solid #f87171",paddingLeft:"1rem"}}>
                <Link href={"/memory/"+e.date} style={{color:"#f87171",fontSize:13,fontWeight:"bold"}}>{e.date}</Link>
                {e.lines.map((line, li) => <p key={li} style={{margin:"2px 0",fontSize:12,color:"#888"}}>{line.slice(0,120)}</p>)}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
