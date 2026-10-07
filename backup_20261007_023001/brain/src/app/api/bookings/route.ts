import { NextResponse } from 'next/server';

const BOOKINGS_URL = 'https://n8n.ecomunivers.cloud/webhook/bookings-get';

function normalizeDate(raw: string): string | null {
  if (!raw) return null;
  if (/^\d{4}-\d{2}-\d{2}/.test(raw)) return raw.slice(0, 10);
  const dmy = raw.match(/^(\d{1,2})[/.](\d{1,2})[/.](\d{4})/);
  if (dmy) return `${dmy[3]}-${dmy[2].padStart(2, '0')}-${dmy[1].padStart(2, '0')}`;
  return null;
}

export async function GET() {
  try {
    const res = await fetch(BOOKINGS_URL, { next: { revalidate: 120 } });
    const data = await res.json();
    if (!Array.isArray(data)) return NextResponse.json({});

    const bookingsPerDate: Record<string, number> = {};
    for (const row of data) {
      const date = normalizeDate(row.Date || row.date || '');
      if (!date) continue;
      const guests = parseInt(String(row.Guests ?? row.guests ?? 1), 10);
      bookingsPerDate[date] = (bookingsPerDate[date] || 0) + (isNaN(guests) || guests <= 0 ? 1 : guests);
    }

    return NextResponse.json(bookingsPerDate);
  } catch (err) {
    console.error('Failed to fetch bookings:', err);
    return NextResponse.json({ error: 'Failed to fetch bookings' }, { status: 500 });
  }
}
