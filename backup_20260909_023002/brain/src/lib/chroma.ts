import { ChromaClient, Collection } from 'chromadb';

const CHROMA_URL = process.env.CHROMA_URL || 'http://localhost:8000';
let client: ChromaClient | null = null;
let collection: Collection | null = null;

export async function getChromaClient(): Promise<ChromaClient> {
  if (!client) {
    client = new ChromaClient({ path: CHROMA_URL });
  }
  return client;
}

export async function getKnowledgeCollection(): Promise<Collection> {
  if (!collection) {
    const client = await getChromaClient();
    try {
      // Create collection WITHOUT embedding function
      // ChromaDB will use server-side default embeddings
      collection = await client.getOrCreateCollection({
        name: 'knowledge_base',
        metadata: { description: 'German Club Cairns Knowledge Base' }
      });
    } catch (e) {
      console.error('ChromaDB connection failed:', e);
      throw e;
    }
  }
  return collection;
}

export async function addToChroma(id: string, text: string, metadata: Record<string, any>) {
  try {
    const collection = await getKnowledgeCollection();
    await collection.add({
      ids: [id],
      documents: [text],
      metadatas: [metadata],
      embeddings: undefined // Let server handle it
    });
  } catch (e) {
    console.error('ChromaDB add failed:', e);
  }
}

export async function searchChroma(query: string, nResults: number = 5) {
  const collection = await getKnowledgeCollection();
  const results = await collection.query({
    queryTexts: [query],
    nResults,
    queryEmbeddings: undefined // Let server handle it
  });
  return results;
}

export async function deleteFromChroma(id: string) {
  try {
    const collection = await getKnowledgeCollection();
    await collection.delete({ ids: [id] });
  } catch (e) {
    console.error('ChromaDB delete failed:', e);
  }
}
