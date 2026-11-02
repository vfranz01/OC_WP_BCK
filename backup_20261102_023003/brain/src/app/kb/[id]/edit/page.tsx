'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';

export default function EditArticle() {
  const { id } = useParams();
  const router = useRouter();
  const [title, setTitle] = useState('');
  const [tags, setTags] = useState('');
  const [content, setContent] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetch(`/api/kb/${id}`).then(r => r.json()).then(a => {
      setTitle(a.title); setTags(a.tags); setContent(a.content);
    });
  }, [id]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    await fetch(`/api/kb/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, content, tags }),
    });
    router.push(`/kb/${id}`);
  };

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-bold mb-6">Edit Article</h1>
      <form onSubmit={onSubmit} className="space-y-4">
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Title" required
          className="w-full bg-[#1a1a1a] border border-[#2a2a2a] rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500" />
        <input value={tags} onChange={e => setTags(e.target.value)} placeholder="Tags (comma-separated)"
          className="w-full bg-[#1a1a1a] border border-[#2a2a2a] rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500" />
        <textarea value={content} onChange={e => setContent(e.target.value)} placeholder="Content (Markdown)" rows={16}
          className="w-full bg-[#1a1a1a] border border-[#2a2a2a] rounded px-3 py-2 text-sm font-mono focus:outline-none focus:border-blue-500 resize-y" />
        <div className="flex gap-2">
          <button type="submit" disabled={saving} className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium disabled:opacity-50 transition-colors">
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
          <button type="button" onClick={() => router.back()} className="px-4 py-2 bg-[#2a2a2a] hover:bg-[#333] rounded text-sm transition-colors">Cancel</button>
        </div>
      </form>
    </div>
  );
}
