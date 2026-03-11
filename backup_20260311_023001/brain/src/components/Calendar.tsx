'use client';
import { useState, useEffect } from "react";

const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const DAYS = ['Mo','Tu','We','Th','Fr','Sa','Su'];

interface CalEvent {
  id: unknown;
  title: string;
  date: string;
  type: string;
  color: string;
  source: string;
}

export default function Calendar() {
  const [current, setCurrent] = useState(new Date());
  const [selected, setSelected] = useState<string | null>(null);
  const [events, setEvents] = useState<CalEvent[]>([]);
  const today = new Date();

  useEffect(() => {
    fetch('/api/events').then(r => r.json()).then(setEvents).catch(() => {});
  }, []);

  const year = current.getFullYear();
  const month = current.getMonth();
  const firstDay = new Date(year, month, 1).getDay();
  const offset = (firstDay + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const prev = () => setCurrent(new Date(year, month - 1, 1));
  const next = () => setCurrent(new Date(year, month + 1, 1));

  const cells: (number | null)[] = [];
  for (let i = 0; i < offset; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);

  const isToday = (d: number) => d === today.getDate() && month === today.getMonth() && year === today.getFullYear();
  const dateStr = (d: number) => `${year}-${String(month+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
  const hasEvent = (d: number) => events.some(e => e.date?.startsWith(dateStr(d)));
  const isSelected = (d: number) => selected === dateStr(d);

  const selectedEvents = selected ? events.filter(e => e.date?.startsWith(selected)) : [];

  return (
    <>
      <div style={{marginTop:'24px', padding:'0 4px'}}>
        <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:'8px'}}>
          <button onClick={prev} style={{background:'none',border:'none',color:'#7b8099',cursor:'pointer',fontSize:'16px',padding:'2px 6px'}}>‹</button>
          <span style={{fontSize:'11px',fontWeight:600,color:'#e8eaf0'}}>{MONTHS[month]} {year}</span>
          <button onClick={next} style={{background:'none',border:'none',color:'#7b8099',cursor:'pointer',fontSize:'16px',padding:'2px 6px'}}>›</button>
        </div>
        <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:'2px',textAlign:'center'}}>
          {DAYS.map(d => (
            <div key={d} style={{fontSize:'9px',color:'#7b8099',fontWeight:600,padding:'2px 0'}}>{d}</div>
          ))}
          {cells.map((d, i) => (
            <div
              key={i}
              onClick={() => d && setSelected(isSelected(d) ? null : dateStr(d))}
              style={{
                fontSize:'11px',
                padding:'3px 1px',
                borderRadius:'4px',
                textAlign:'center',
                cursor: d ? 'pointer' : 'default',
                position: 'relative',
                color: isSelected(d!) ? '#fff' : isToday(d!) ? '#fff' : '#9ba0b4',
                background: isSelected(d!) ? '#3d8fe0' : isToday(d!) ? '#005baa' : 'transparent',
                fontWeight: (d && (isToday(d) || isSelected(d))) ? 700 : 400,
                outline: d && hasEvent(d) && !isSelected(d) ? '1px solid #005baa' : 'none',
              }}
            >
              {d || ''}
              {d && hasEvent(d) && (
                <span style={{
                  position:'absolute',
                  bottom:'1px',
                  left:'50%',
                  transform:'translateX(-50%)',
                  width:'4px',
                  height:'4px',
                  borderRadius:'50%',
                  background: isSelected(d) ? '#fff' : '#3d8fe0',
                  display:'block'
                }}/>
              )}
            </div>
          ))}
        </div>
      </div>

      {selected && (
        <div style={{marginTop:'16px',padding:'0 4px'}}>
          <div style={{fontSize:'11px',fontWeight:600,color:'#7b8099',marginBottom:'8px',textTransform:'uppercase',letterSpacing:'0.5px'}}>
            {new Date(selected + 'T12:00:00').toLocaleDateString('en-AU', {day:'numeric',month:'short',year:'numeric'})}
          </div>
          {selectedEvents.length === 0 ? (
            <div style={{fontSize:'11px',color:'#4a5068',padding:'8px 0'}}>No events</div>
          ) : (
            selectedEvents.map((ev, i) => (
              <div key={i} style={{
                background:'rgba(0,91,170,0.15)',
                border:'1px solid rgba(0,91,170,0.3)',
                borderRadius:'6px',
                padding:'8px 10px',
                marginBottom:'6px'
              }}>
                <div style={{fontSize:'12px',fontWeight:600,color:'#e8eaf0'}}>{ev.title}</div>
                <div style={{fontSize:'10px',color:'#7b8099',marginTop:'2px'}}>{ev.source}</div>
              </div>
            ))
          )}
        </div>
      )}
    </>
  );
}
