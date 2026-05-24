import { NextResponse } from 'next/server';
import { getAllArticles, searchArticles, createArticle } from '@/lib/db';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const q = searchParams.get('q');
  const articles = q ? searchArticles(q) : getAllArticles();
  return NextResponse.json(articles);
}

export async function POST(request: Request) {
  const { title, content, tags } = await request.json();
  if (!title) return NextResponse.json({ error: 'Title required' }, { status: 400 });
  const article = createArticle(title, content || '', tags || '');
  return NextResponse.json(article, { status: 201 });
}
