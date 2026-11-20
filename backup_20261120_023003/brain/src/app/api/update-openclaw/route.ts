import { NextResponse } from "next/server";
import { exec } from "child_process";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const version = body.version || "latest";

  const cmd = version === "latest"
    ? "sh /usr/local/bin/update-openclaw.sh"
    : `sh /usr/local/bin/update-openclaw.sh ${version}`;

  return new Promise<NextResponse>((resolve) => {
    exec(cmd, { timeout: 180000 }, (error, stdout, stderr) => {
      if (error) {
        resolve(NextResponse.json({ success: false, error: stderr || error.message }, { status: 500 }));
      } else {
        resolve(NextResponse.json({ success: true, output: stdout }));
      }
    });
  });
}
