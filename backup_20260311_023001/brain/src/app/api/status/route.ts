import { NextResponse } from 'next/server';
import os from 'os';
import fs from 'fs';
import { execSync } from 'child_process';

export async function GET() {
  const backupsDir = '/home/node/.openclaw/backups/';
  let snapshotCount = 0;
  try {
    snapshotCount = fs.readdirSync(backupsDir).length;
  } catch { /* dir may not exist */ }

  let diskInfo = '';
  try {
    diskInfo = execSync('df -h / | tail -1').toString().trim();
  } catch { /* */ }

  const mem = os.totalmem();
  const free = os.freemem();

  return NextResponse.json({
    hostname: os.hostname(),
    uptime: os.uptime(),
    memory: { total: mem, free, used: mem - free },
    disk: diskInfo,
    openclawConfigExists: fs.existsSync('/home/node/.openclaw/config.yaml') || fs.existsSync('/home/node/.openclaw/config.yml'),
    snapshotCount,
    platform: os.platform(),
    cpus: os.cpus().length,
  });
}
