import { NextResponse } from 'next/server';
import { exec } from 'child_process';

export async function POST(): Promise<NextResponse> {
  return new Promise<NextResponse>((resolve) => {
    exec('docker restart openclaw-openclaw-gateway-1', (error, _stdout, stderr) => {
      if (error) {
        resolve(NextResponse.json({ success: false, error: stderr }, { status: 500 }));
      } else {
        resolve(NextResponse.json({ success: true }));
      }
    });
  });
}
