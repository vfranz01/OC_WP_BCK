import { NextResponse } from 'next/server';
interface GCCEvent {
  [key: string]: unknown;
}
export async function GET() {
  try {
    const res = await fetch('https://n8n.ecomunivers.cloud/webhook/events-get', { next: { revalidate: 300 } });
    const data: GCCEvent[] = await res.json();
    const events = Array.isArray(data) ? data.map(e => ({
      ...e,
      type: 'gcc',
      color: '#005baa',
      source: 'German Club'
    })) : [];
    return NextResponse.json(events);
  } catch {
    return NextResponse.json([]);
  }
}
