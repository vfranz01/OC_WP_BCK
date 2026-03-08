'use client';
import { useEffect, useState } from 'react';

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-4">
      <h2 className="text-sm font-semibold text-blue-400 mb-3">{title}</h2>
      {children}
    </div>
  );
}

function fmt(bytes: number) {
  if (bytes > 1e9) return (bytes / 1e9).toFixed(1) + ' GB';
  if (bytes > 1e6) return (bytes / 1e6).toFixed(1) + ' MB';
  return (bytes / 1e3).toFixed(1) + ' KB';
}

export default function Dashboard() {
  const [status, setStatus] = useState<Record<string, unknown> | null>(null);
  const [snapshots, setSnapshots] = useState<Array<{ name: string; size: number; date: string }>>([]);
  const [memory, setMemory] = useState('');

  useEffect(() => {
    fetch('/api/status').then(r => r.json()).then(setStatus);
    fetch('/api/snapshots').then(r => r.json()).then(setSnapshots);
    fetch('/api/memory').then(r => r.json()).then(d => setMemory(d.content));
  }, []);

  const mem = status?.memory as { total: number; free: number; used: number } | undefined;

  return (
    <div className="space-y-6 max-w-4xl">
      <h1 className="text-2xl font-bold">Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card title="System Status">
          {status ? (
            <dl className="text-sm space-y-1 text-gray-300">
              <div className="flex justify-between"><dt>Hostname</dt><dd className="font-mono">{String(status.hostname)}</dd></div>
              <div className="flex justify-between"><dt>Platform</dt><dd>{String(status.platform)}</dd></div>
              <div className="flex justify-between"><dt>CPUs</dt><dd>{String(status.cpus)}</dd></div>
              <div className="flex justify-between"><dt>Uptime</dt><dd>{Math.floor(Number(status.uptime) / 3600)}h {Math.floor((Number(status.uptime) % 3600) / 60)}m</dd></div>
              {mem && <div className="flex justify-between"><dt>Memory</dt><dd>{fmt(mem.used)} / {fmt(mem.total)}</dd></div>}
              <div className="flex justify-between"><dt>Disk</dt><dd className="font-mono text-xs">{String(status.disk)}</dd></div>
              <div className="flex justify-between"><dt>OpenClaw Config</dt><dd>{status.openclawConfigExists ? '✅' : '❌'}</dd></div>
              <div className="flex justify-between"><dt>Snapshots</dt><dd>{String(status.snapshotCount)}</dd></div>
            </dl>
          ) : <p className="text-gray-500 text-sm">Loading...</p>}
        </Card>
        <Card title="Recent Snapshots">
          {snapshots.length === 0 ? <p className="text-gray-500 text-sm">No snapshots found</p> : (
            <ul className="text-sm space-y-1 text-gray-300 max-h-48 overflow-auto">
              {snapshots.slice(0, 10).map(s => (
                <li key={s.name} className="flex justify-between font-mono text-xs">
                  <span className="truncate mr-2">{s.name}</span>
                  <span className="text-gray-500 shrink-0">{fmt(s.size)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
      <Card title="Memory (MEMORY.md)">
        <pre className="text-xs text-gray-300 whitespace-pre-wrap max-h-64 overflow-auto">{memory || 'Loading...'}</pre>
      </Card>
    </div>
  );
}
