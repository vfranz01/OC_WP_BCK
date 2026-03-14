import { NextResponse } from 'next/server';

interface GCCEvent {
  id: unknown;
  title_en: string;
  date: string;
  [key: string]: unknown;
}

export async function GET() {
  let gccEvents: { id: unknown; title: string; date: string; type: string; color: string; source: string }[] = [];
  try {
    const res = await fetch('https://n8n.ecomunivers.cloud/webhook/events-get', { next: { revalidate: 300 } });
    const data: GCCEvent[] = await res.json();
    gccEvents = Array.isArray(data) ? data.map(e => ({
      id: e.id,
      title: e.title_en,
      date: e.date,
      type: 'gcc',
      color: '#005baa',
      source: 'German Club'
    })) : [];
  } catch {}

  return NextResponse.json(gccEvents);
}
