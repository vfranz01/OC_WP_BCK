'use client';
import { useState, useEffect } from "react";

const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const DAYS = ['Mo','Tu','We','Th','Fr','Sa','Su'];

interface CalEvent {
  id: unknown;
  title_en: string;
  title_de: string;
  date: string;
  tag_en: string;
  tag_de: string;
  text_en: string;
  text_de: string;
  link: string;
  btn_en: string;
  btn_de: string;
  status: string;
  source?: string;
  // legacy
  title?: string;
  type?: string;
  color?: string;
}

const TAG_COLORS: Record<string, string> = {
  Highlight: '#f59e0b',
  Test: '#6366f1',
  Special: '#22c55e',
  default: '#3b82f6',
};

export default function Calendar() {
  const [open, setOpen] = useState(true);
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

  const getTitle = (ev: CalEvent) => ev.title_en || ev.title || '';
  const getTag = (ev: CalEvent) => ev.tag_en || ev.type || '';
  const getTagColor = (tag: string) => TAG_COLORS[tag] || TAG_COLORS.default;

  return (
    <div style={{ marginTop: '16px' }}>
      {/* Submenu Header */}
      <button
        onClick={() => setOpen(o => !o)}
        style={{
          width: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: '6px 8px',
          borderRadius: '6px',
          color: '#9ba0b4',
          fontSize: '12px',
          fontWeight: 600,
          letterSpacing: '0.5px',
          textTransform: 'uppercase',
        }}
        onMouseEnter={e => (e.currentTarget.style.background = '#1a1a1a')}
        onMouseLeave={e => (e.currentTarget.style.background = 'none')}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span>📅</span> Calendar
        </span>
        <span style={{ fontSize: '10px', transition: 'transform 0.2s', display: 'inline-block', transform: open ? 'rotate(90deg)' : 'rotate(0deg)' }}>▶</span>
      </button>

      {/* Collapsible Content */}
      {open && (
        <div style={{ paddingLeft: '4px', paddingRight: '4px' }}>

          {/* Mini Calendar */}
          <div style={{ marginTop: '8px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <button onClick={prev} style={{ background: 'none', border: 'none', color: '#7b8099', cursor: 'pointer', fontSize: '16px', padding: '2px 6px' }}>‹</button>
              <span style={{ fontSize: '11px', fontWeight: 600, color: '#e8eaf0' }}>{MONTHS[month]} {year}</span>
              <button onClick={next} style={{ background: 'none', border: 'none', color: '#7b8099', cursor: 'pointer', fontSize: '16px', padding: '2px 6px' }}>›</button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: '2px', textAlign: 'center' }}>
              {DAYS.map(d => (
                <div key={d} style={{ fontSize: '9px', color: '#7b8099', fontWeight: 600, padding: '2px 0' }}>{d}</div>
              ))}
              {cells.map((d, i) => (
                <div
                  key={i}
                  onClick={() => d && setSelected(isSelected(d) ? null : dateStr(d))}
                  style={{
                    fontSize: '11px',
                    padding: '3px 1px',
                    borderRadius: '4px',
                    textAlign: 'center',
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
                      position: 'absolute', bottom: '1px', left: '50%',
                      transform: 'translateX(-50%)', width: '4px', height: '4px',
                      borderRadius: '50%', background: isSelected(d) ? '#fff' : '#3d8fe0', display: 'block'
                    }} />
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Event Count Badge */}
          {events.length > 0 && (
            <div style={{ marginTop: '10px', fontSize: '10px', color: '#4a5068', textAlign: 'center' }}>
              {events.length} event{events.length !== 1 ? 's' : ''} this view
            </div>
          )}

          {/* Selected Day Detail */}
          {selected && (
            <div style={{ marginTop: '12px' }}>
              <div style={{ fontSize: '10px', fontWeight: 600, color: '#7b8099', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                {new Date(selected + 'T12:00:00').toLocaleDateString('en-AU', { day: 'numeric', month: 'short', year: 'numeric' })}
              </div>

              {selectedEvents.length === 0 ? (
                <div style={{ fontSize: '11px', color: '#4a5068', padding: '8px 0' }}>No events</div>
              ) : (
                selectedEvents.map((ev, i) => {
                  const tag = getTag(ev);
                  const tagColor = getTagColor(tag);
                  return (
                    <div key={i} style={{
                      background: 'rgba(0,91,170,0.12)',
                      border: '1px solid rgba(0,91,170,0.25)',
                      borderRadius: '8px',
                      padding: '10px',
                      marginBottom: '8px',
                    }}>
                      {/* Tag */}
                      {tag && (
                        <div style={{
                          display: 'inline-block',
                          fontSize: '9px',
                          fontWeight: 700,
                          color: tagColor,
                          background: `${tagColor}22`,
                          border: `1px solid ${tagColor}44`,
                          borderRadius: '4px',
                          padding: '1px 6px',
                          marginBottom: '6px',
                          textTransform: 'uppercase',
                          letterSpacing: '0.5px',
                        }}>{tag}</div>
                      )}

                      {/* Title */}
                      <div style={{ fontSize: '12px', fontWeight: 700, color: '#e8eaf0', marginBottom: '4px' }}>
                        {getTitle(ev)}
                      </div>

                      {/* Description */}
                      {ev.text_en && (
                        <div style={{ fontSize: '10px', color: '#7b8099', lineHeight: '1.5', marginBottom: '8px' }}>
                          {ev.text_en.length > 100 ? ev.text_en.slice(0, 100) + '…' : ev.text_en}
                        </div>
                      )}

                      {/* Stats Row */}
                      <div style={{ display: 'flex', gap: '6px', marginBottom: '8px', flexWrap: 'wrap' }}>
                        {/* Table Bookings placeholder */}
                        <div style={{
                          flex: 1,
                          background: 'rgba(59,130,246,0.1)',
                          border: '1px solid rgba(59,130,246,0.2)',
                          borderRadius: '6px',
                          padding: '6px 8px',
                          minWidth: '70px',
                        }}>
                          <div style={{ fontSize: '9px', color: '#4a5068', marginBottom: '2px' }}>🪑 Bookings</div>
                          <div style={{ fontSize: '13px', fontWeight: 700, color: '#3b82f6' }}>—</div>
                        </div>

                        {/* Special Menu placeholder */}
                        <div style={{
                          flex: 1,
                          background: 'rgba(245,158,11,0.1)',
                          border: '1px solid rgba(245,158,11,0.2)',
                          borderRadius: '6px',
                          padding: '6px 8px',
                          minWidth: '70px',
                        }}>
                          <div style={{ fontSize: '9px', color: '#4a5068', marginBottom: '2px' }}>🍽️ Menu</div>
                          <div style={{ fontSize: '10px', fontWeight: 600, color: '#f59e0b' }}>
                            {ev.status === 'upcoming' ? 'TBD' : '—'}
                          </div>
                        </div>
                      </div>

                      {/* Status + Button */}
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span style={{
                          fontSize: '9px',
                          fontWeight: 600,
                          color: ev.status === 'upcoming' ? '#22c55e' : '#9ba0b4',
                          textTransform: 'uppercase',
                          letterSpacing: '0.5px',
                        }}>● {ev.status}</span>
                        {ev.btn_en && ev.link && (
                          <a
                            href={ev.link}
                            target="_blank"
                            rel="noopener noreferrer"
                            style={{
                              fontSize: '9px',
                              fontWeight: 600,
                              color: '#3b82f6',
                              textDecoration: 'none',
                              background: 'rgba(59,130,246,0.1)',
                              border: '1px solid rgba(59,130,246,0.3)',
                              borderRadius: '4px',
                              padding: '3px 8px',
                            }}
                          >
                            {ev.btn_en} →
                          </a>
                        )}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
