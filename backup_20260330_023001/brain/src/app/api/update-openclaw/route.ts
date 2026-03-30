import { NextResponse } from "next/server";
import { exec } from "child_process";

export async function POST() {
  return new Promise<NextResponse>((resolve) => {
    exec(
      "docker pull ghcr.io/openclaw/openclaw:latest && docker restart openclaw-openclaw-gateway-1",
      { timeout: 120000 },
      (error, stdout, stderr) => {
        if (error) {
          resolve(NextResponse.json({ success: false, error: stderr || error.message }, { status: 500 }));
        } else {
          resolve(NextResponse.json({ success: true, output: stdout }));
        }
      }
    );
  });
}
