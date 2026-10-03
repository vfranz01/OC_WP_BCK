'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

interface Article { id: number; title: string; content: string; tags: string; created_at: string; updated_at: string; }

export default function KBList() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [query, setQuery] = useState('');

  const load = (q?: string) => {
    const url = q ? `/api/kb?q=${encodeURIComponent(q)}` : '/api/kb';
    fetch(url).then(r => r.json()).then(setArticles);
  };

  useEffect(() => { load(); }, []);

  const onSearch = (e: React.FormEvent) => { e.preventDefault(); load(query); };

  return (
    <div className="max-w-4xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Knowledge Base</h1>
        <Link href="/kb/new" className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium transition-colors">
          + New Article
        </Link>
      </div>
      <form onSubmit={onSearch} className="flex gap-2">
        <input
          value={query} onChange={e => setQuery(e.target.value)}
          placeholder="Search articles..."
          className="flex-1 bg-[#1a1a1a] border border-[#2a2a2a] rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500"
        />
        <button type="submit" className="px-4 py-2 bg-[#2a2a2a] hover:bg-[#333] rounded text-sm transition-colors">Search</button>
      </form>
      {articles.length === 0 ? (
        <p className="text-gray-500 text-sm">No articles found.</p>
      ) : (
        <div className="space-y-3">
          {articles.map(a => (
            <Link key={a.id} href={`/kb/${a.id}`} className="block bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-4 hover:border-blue-500/50 transition-colors">
              <h3 className="font-semibold mb-1">{a.title}</h3>
              {a.tags && <div className="flex gap-1 mb-2">{a.tags.split(',').map(t => (
                <span key={t} className="text-xs bg-blue-500/20 text-blue-300 px-2 py-0.5 rounded">{t.trim()}</span>
              ))}</div>}
              <p className="text-sm text-gray-400 line-clamp-2">{a.content.slice(0, 200)}</p>
              <p className="text-xs text-gray-500 mt-2">{new Date(a.updated_at).toLocaleDateString()}</p>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
