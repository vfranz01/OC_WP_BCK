import { NextResponse } from "next/server";
import fs from "fs";

export async function GET() {
  try {
    const content = fs.readFileSync("/home/node/.openclaw/workspace/MEMORY.md", "utf8");
    return NextResponse.json({ content });
  } catch (e) {
    return NextResponse.json({ content: "Error loading MEMORY.md: " + String(e) });
  }
}
