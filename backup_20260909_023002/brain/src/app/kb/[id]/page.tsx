'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeHighlight from 'rehype-highlight';

interface Article { id: number; title: string; content: string; tags: string; created_at: string; updated_at: string; }

export default function ViewArticle() {
  const { id } = useParams();
  const router = useRouter();
  const [article, setArticle] = useState<Article | null>(null);

  useEffect(() => { fetch(`/api/kb/${id}`).then(r => r.json()).then(setArticle); }, [id]);

  const onDelete = async () => {
    if (!confirm('Delete this article?')) return;
    await fetch(`/api/kb/${id}`, { method: 'DELETE' });
    router.push('/kb');
  };

  if (!article) return <p className="text-gray-500">Loading...</p>;

  return (
    <div className="max-w-3xl">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold">{article.title}</h1>
        <div className="flex gap-2">
          <Link href={`/kb/${id}/edit`} className="px-3 py-1.5 bg-[#2a2a2a] hover:bg-[#333] rounded text-sm transition-colors">Edit</Link>
          <button onClick={onDelete} className="px-3 py-1.5 bg-red-600/20 hover:bg-red-600/40 text-red-400 rounded text-sm transition-colors">Delete</button>
        </div>
      </div>
      {article.tags && <div className="flex gap-1 mb-4">{article.tags.split(',').map(t => (
        <span key={t} className="text-xs bg-blue-500/20 text-blue-300 px-2 py-0.5 rounded">{t.trim()}</span>
      ))}</div>}
      <p className="text-xs text-gray-500 mb-6">Updated {new Date(article.updated_at).toLocaleString()}</p>
      <div className="prose prose-invert prose-sm max-w-none">
        <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeHighlight]}>
          {article.content}
        </ReactMarkdown>
      </div>
      <Link href="/kb" className="inline-block mt-6 text-sm text-blue-400 hover:underline">← Back to Knowledge Base</Link>
    </div>
  );
}
