import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

export async function GET() {
  const backupsDir = '/home/node/.openclaw/backups/';
  try {
    const files = fs.readdirSync(backupsDir).map(name => {
      const stat = fs.statSync(path.join(backupsDir, name));
      return { name, size: stat.size, date: stat.mtime.toISOString() };
    });
    files.sort((a, b) => b.date.localeCompare(a.date));
    return NextResponse.json(files);
  } catch {
    return NextResponse.json([]);
  }
}
