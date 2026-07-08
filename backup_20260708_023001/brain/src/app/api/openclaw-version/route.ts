import { NextResponse } from "next/server";
import { execSync } from "child_process";

export async function GET() {
  try {
    const version = execSync(
      "docker exec openclaw-gateway openclaw --version",
      { timeout: 10000 }
    ).toString().trim();
    return NextResponse.json({ version });
  } catch (e) {
    return NextResponse.json({ version: "Unknown", error: String(e) });
  }
}
