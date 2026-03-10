'use client';
import { useState } from "react";

const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const DAYS = ['Mo','Tu','We','Th','Fr','Sa','Su'];

export default function Calendar() {
  const [current, setCurrent] = useState(new Date());
  const today = new Date();
  const year = current.getFullYear();
  const month = current.getMonth();
  const firstDay = new Date(year, month, 1).getDay();
  const offset = (firstDay + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const prev = () => setCurrent(new Date(year, month - 1, 1));
  const next = () => setCurrent(new Date(year, month + 1, 1));
  const cells = [];
  for (let i = 0; i < offset; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  const isToday = (d: number | null) => d && d === today.getDate() && month === today.getMonth() && year === today.getFullYear();
  return (
    <div style={{marginTop:'24px',padding:'0 4px'}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:'8px'}}>
        <button onClick={prev} style={{background:'none',border:'none',color:'#7b8099',cursor:'pointer',fontSize:'16px'}}>‹</button>
        <span style={{fontSize:'11px',fontWeight:600,color:'#e8eaf0'}}>{MONTHS[month]} {year}</span>
        <button onClick={next} style={{background:'none',border:'none',color:'#7b8099',cursor:'pointer',fontSize:'16px'}}>›</button>
      </div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:'2px',textAlign:'center'}}>
        {DAYS.map(d => <div key={d} style={{fontSize:'9px',color:'#7b8099',fontWeight:600,padding:'2px 0'}}>{d}</div>)}
        {cells.map((d, i) => (
          <div key={i} style={{fontSize:'11px',padding:'3px 1px',borderRadius:'4px',textAlign:'center',color:isToday(d)?'#fff':'#9ba0b4',background:isToday(d)?'#005baa':'transparent',fontWeight:isToday(d)?700:400}}>{d||''}</div>
        ))}
      </div>
    </div>
  );
}
