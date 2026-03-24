'use client';

'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

export default function MemoryDashboard() {
  const [logs, setLogs] = useState<Array<{date: string; title?: string}>>([]);

  useEffect(() => {
    fetch('/api/memory')
      .then(res => res.json())
      .then(data => setLogs(data))
      .catch(console.error);
  }, []);

  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui, sans-serif' }}>
      <h1>Memory Dashboard</h1>
      <p>Browse your daily memory logs.</p>
      
      {logs.length === 0 ? (
        <p>Loading logs...</p>
      ) : (
        <>
          <h2>Recent Logs</h2>
          <ul>
            {logs.map(log => (
              <li key={log.date}>
                <Link href={`/memory/${log.date}`}>
                  <strong>{log.date}</strong>{' '}
                  {log.title ? `– ${log.title}` : ''}
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}