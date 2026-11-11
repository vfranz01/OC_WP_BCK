import { NextResponse } from 'next/server';

const WEBHOOK_URL = 'https://n8n.ecomunivers.cloud/webhook/event-update';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { id, booking_enabled } = body;
    if (!id) return NextResponse.json({ error: 'Missing id' }, { status: 400 });

    const res = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, booking_enabled }),
    });
    const data = await res.json();
    return NextResponse.json({ success: true, data });
  } catch (err) {
    console.error('Toggle booking failed:', err);
    return NextResponse.json({ error: 'Failed to update' }, { status: 500 });
  }
}
