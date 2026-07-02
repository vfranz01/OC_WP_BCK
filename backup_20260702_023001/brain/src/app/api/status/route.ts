import { NextResponse } from "next/server";
import os from "os";
import fs from "fs";
import { execSync } from "child_process";

export async function GET() {
  const backupsDir = "/home/node/.openclaw/backups/";
  let snapshotCount = 0;
  try {
    snapshotCount = fs.readdirSync(backupsDir).length;
  } catch { /* dir may not exist */ }

  let diskInfo = "";
  try {
    diskInfo = execSync("df -h / | tail -1").toString().trim();
  } catch { /* */ }

  let openclawUptime = null;
  try {
    const result = execSync("docker inspect openclaw-gateway --format '{{.State.StartedAt}}'").toString().trim();
    const startedAt = new Date(result);
    const uptimeSeconds = Math.floor((Date.now() - startedAt.getTime()) / 1000);
    const hours = Math.floor(uptimeSeconds / 3600);
    const minutes = Math.floor((uptimeSeconds % 3600) / 60);
    openclawUptime = `${hours}h ${minutes}m`;
  } catch { /* docker not available */ }

  const mem = os.totalmem();
  const free = os.freemem();
  return NextResponse.json({
    hostname: os.hostname(),
    uptime: os.uptime(),
    openclawUptime,
    memory: { total: mem, free, used: mem - free },
    disk: diskInfo,
    openclawConfigExists: fs.existsSync("/home/node/.openclaw/config.yaml") || fs.existsSync("/home/node/.openclaw/config.yml"),
    snapshotCount,
    platform: os.platform(),
    cpus: os.cpus().length,
  });
}
