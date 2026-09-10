import { NextResponse } from "next/server";
import { exec } from "child_process";
import fs from "fs";
import path from "path";

const REPO_DIR = "/home/node/.openclaw/workspace/backup_repo";

export async function GET() {
  try {
    const dirs = fs.readdirSync(REPO_DIR)
      .filter(f => f.startsWith("backup_"))
      .sort()
      .reverse();
    const latest = dirs[0] || null;
    let lastDate = null;
    if (latest) {
      const match = latest.match(/backup_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/);
      if (match) {
        lastDate = `${match[1]}-${match[2]}-${match[3]} ${match[4]}:${match[5]}:${match[6]} UTC`;
      }
    }
    return NextResponse.json({
      success: true,
      latestBackup: latest,
      lastDate,
      totalBackups: dirs.length,
      backups: dirs.slice(0, 7)
    });
  } catch (e) {
    return NextResponse.json({ success: false, error: String(e) }, { status: 500 });
  }
}

export async function POST() {
  return new Promise<NextResponse>((resolve) => {
    exec("bash /home/node/.openclaw/workspace/backup_to_github.sh", { timeout: 120000 }, (error, stdout, stderr) => {
      if (error) {
        resolve(NextResponse.json({ success: false, error: stderr || error.message }, { status: 500 }));
      } else {
        resolve(NextResponse.json({ success: true, output: stdout }));
      }
    });
  });
}
