import { NextResponse } from 'next/server';
import fs from 'fs';

export async function GET() {
  const memoryPath = '/home/node/.openclaw/workspace/MEMORY.md';
  try {
    const content = fs.readFileSync(memoryPath, 'utf-8');
    return NextResponse.json({ content });
  } catch {
    return NextResponse.json({ content: '_No MEMORY.md found._' });
  }
}
