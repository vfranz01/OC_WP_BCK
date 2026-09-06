import { NextResponse } from "next/server";
import { execSync } from "child_process";

export async function GET() {
  try {
    const containerName = execSync(
      "docker ps --format '{{.Names}}' | grep openclaw | grep -v brain | head -1",
      { timeout: 5000 }
    ).toString().trim();

    const version = execSync(
      `docker exec ${containerName} node dist/index.js --version`,
      { timeout: 10000 }
    ).toString().trim().replace("OpenClaw ", "");

    return NextResponse.json({ version });
  } catch (e) {
    return NextResponse.json({ version: "Unknown", error: String(e) });
  }
}
