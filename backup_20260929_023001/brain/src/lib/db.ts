import Database from 'better-sqlite3';
import path from 'path';
import { addToChroma, deleteFromChroma } from './chroma';

const DB_PATH = path.join(process.cwd(), 'brain.db');

let _db: Database.Database | null = null;

function getDb(): Database.Database {
  if (!_db) {
    _db = new Database(DB_PATH);
    _db.pragma('journal_mode = WAL');
    _db.exec(`
      CREATE TABLE IF NOT EXISTS articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
      CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
        title, content, tags, content='articles', content_rowid='id'
      );
      CREATE TRIGGER IF NOT EXISTS articles_ai AFTER INSERT ON articles BEGIN
        INSERT INTO articles_fts(rowid, title, content, tags) VALUES (new.id, new.title, new.content, new.tags);
      END;
      CREATE TRIGGER IF NOT EXISTS articles_ad AFTER DELETE ON articles BEGIN
        INSERT INTO articles_fts(articles_fts, rowid, title, content, tags) VALUES('delete', old.id, old.title, old.content, old.tags);
      END;
      CREATE TRIGGER IF NOT EXISTS articles_au AFTER UPDATE ON articles BEGIN
        INSERT INTO articles_fts(articles_fts, rowid, title, content, tags) VALUES('delete', old.id, old.title, old.content, old.tags);
        INSERT INTO articles_fts(rowid, title, content, tags) VALUES (new.id, new.title, new.content, new.tags);
      END;
    `);
  }
  return _db;
}

export interface Article {
  id: number;
  title: string;
  content: string;
  tags: string;
  created_at: string;
  updated_at: string;
}

export function getAllArticles(): Article[] {
  return getDb().prepare('SELECT * FROM articles ORDER BY updated_at DESC').all() as Article[];
}

export function searchArticles(query: string): Article[] {
  return getDb().prepare(
    `SELECT a.* FROM articles a JOIN articles_fts f ON a.id = f.rowid WHERE articles_fts MATCH ? ORDER BY rank`
  ).all(query) as Article[];
}

export function getArticle(id: number): Article | undefined {
  return getDb().prepare('SELECT * FROM articles WHERE id = ?').get(id) as Article | undefined;
}

export function createArticle(title: string, content: string, tags: string): Article {
  const result = getDb().prepare(
    'INSERT INTO articles (title, content, tags) VALUES (?, ?, ?)'
  ).run(title, content, tags);
  
  const article = getArticle(Number(result.lastInsertRowid))!;
  
  // Add to ChromaDB (async, non-blocking)
  addToChroma(
    article.id.toString(),
    `${title}\n\n${content}`,
    { title, tags, created_at: article.created_at }
  ).catch(err => console.error('ChromaDB sync failed:', err));
  
  return article;
}

export function updateArticle(id: number, title: string, content: string, tags: string): Article | undefined {
  getDb().prepare(
    "UPDATE articles SET title = ?, content = ?, tags = ?, updated_at = datetime('now') WHERE id = ?"
  ).run(title, content, tags, id);
  
  const article = getArticle(id);
  if (article) {
    // Update ChromaDB (delete + re-add)
    deleteFromChroma(id.toString())
      .then(() => addToChroma(
        id.toString(),
        `${title}\n\n${content}`,
        { title, tags, updated_at: article.updated_at }
      ))
      .catch(err => console.error('ChromaDB sync failed:', err));
  }
  
  return article;
}

export function deleteArticle(id: number): boolean {
  const result = getDb().prepare('DELETE FROM articles WHERE id = ?').run(id);
  if (result.changes > 0) {
    deleteFromChroma(id.toString()).catch(() => {});
  }
  return result.changes > 0;
}
