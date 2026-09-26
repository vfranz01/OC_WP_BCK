import { NextResponse } from 'next/server';
import { searchChroma } from '@/lib/chroma';
import { getArticle } from '@/lib/db';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const q = searchParams.get('q');
  
  if (!q) {
    return NextResponse.json({ error: 'Query required' }, { status: 400 });
  }

  try {
    const chromaResults = await searchChroma(q, 10);
    
    const articles = [];
    if (chromaResults.ids && chromaResults.ids[0]) {
      for (const id of chromaResults.ids[0]) {
        const article = getArticle(parseInt(id));
        if (article) {
          articles.push(article);
        }
      }
    }
    
    return NextResponse.json({
      method: 'vector',
      results: articles,
      distances: chromaResults.distances?.[0] || []
    });
  } catch (error: any) {
    console.error('Vector search failed:', error);
    return NextResponse.json({ 
      error: 'Search failed', 
      message: error?.message 
    }, { status: 500 });
  }
}
