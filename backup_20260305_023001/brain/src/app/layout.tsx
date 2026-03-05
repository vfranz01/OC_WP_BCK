import './globals.css';
import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Brain Dashboard' };

const nav = [
  { href: '/', label: '🏠 Dashboard' },
  { href: '/kb', label: '📚 Knowledge Base' },
];

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="flex min-h-screen">
        <aside className="w-56 shrink-0 border-r border-[#2a2a2a] bg-[#111] p-4 flex flex-col gap-1">
          <h1 className="text-lg font-bold text-blue-400 mb-4">🧠 Brain</h1>
          {nav.map(n => (
            <Link key={n.href} href={n.href} className="block px-3 py-2 rounded hover:bg-[#1a1a1a] transition-colors text-sm">
              {n.label}
            </Link>
          ))}
        </aside>
        <main className="flex-1 p-6 overflow-auto">{children}</main>
      </body>
    </html>
  );
}
