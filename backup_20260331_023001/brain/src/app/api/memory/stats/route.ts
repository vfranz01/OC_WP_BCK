import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

const MEMORY_DIR = '/home/node/.openclaw/workspace/memory';
const ERROR_KEYWORDS = ['error', 'fail', 'issue', 'problem', 'critical', 'warning', 'exception', 'unable', 'broken', 'fix'];
const IGNORE_WORDS = new Set(['the','a','an','and','or','but','in','on','at','to','for','of','with','by','from','is','was','are','were','be','been','has','have','had','this','that','these','those','it','its','not','no','as','so','if','then','when','all','more','also','new','can','will','may','should','would','could','after','before','during','while','about','up','out','into','over','i','we','you','he','she','they','his','her','their','our','my','your','me','him','us','them','read','done']);

export async function GET() {
  try {
    const files = fs.readdirSync(MEMORY_DIR).filter(f => f.endsWith('.md')).sort();
    const stats = {
      totalLogs: 0, totalLines: 0,
      byMonth: {} as Record<string, number>,
      heatmap: {} as Record<string, number>,
      keywords: {} as Record<string, number>,
      errors: [] as Array<{date: string, lines: string[]}>,
    };
    for (const file of files) {
      const content = fs.readFileSync(path.join(MEMORY_DIR, file), 'utf8');
      const lines = content.split('\n');
      const dateMatch = file.match(/^(\d{4}-\d{2}-\d{2})/);
      const date = dateMatch ? dateMatch[1] : null;
      const month = date ? date.slice(0, 7) : null;
      stats.totalLogs++;
      stats.totalLines += lines.length;
      if (date) stats.heatmap[date] = (stats.heatmap[date] || 0) + lines.length;
      if (month) stats.byMonth[month] = (stats.byMonth[month] || 0) + 1;
      const words = content.toLowerCase().replace(/[^a-z\s]/g, ' ').split(/\s+/);
      for (const word of words) {
        if (word.length > 4 && !IGNORE_WORDS.has(word)) stats.keywords[word] = (stats.keywords[word] || 0) + 1;
      }
      const errorLines = lines.filter(l => ERROR_KEYWORDS.some(k => l.toLowerCase().includes(k)));
      if (errorLines.length > 0 && date) stats.errors.push({ date, lines: errorLines.slice(0, 3) });
    }
    stats.keywords = Object.fromEntries(Object.entries(stats.keywords).sort((a,b) => b[1]-a[1]).slice(0, 30));
    return NextResponse.json(stats);
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 });
  }
}
