# index_corpus.py
import chromadb
from chromadb.utils import (
    embedding_functions as ef)

def chunk_text(text, size=500, overlap=100):
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + size, len(text))
        chunks.append(text[start:end])
        start = end - overlap
        if start <= 0:
            break
    return chunks

with open('knowledge_base.txt') as f:
    raw = f.read()
chunks = chunk_text(raw)
print(f'Produced {len(chunks)} chunks')

client = chromadb.PersistentClient(
    path='./vector_db')
embed = ef.SentenceTransformerEmbeddingFunction(
    model_name='all-MiniLM-L6-v2')

try:
    client.delete_collection('compliance_kb')
except Exception:
    pass
collection = client.create_collection(
    name='compliance_kb',
    embedding_function=embed)

collection.add(
    documents=chunks,
    ids=[f'chunk_{i}' for i in range(len(chunks))])
print(f'Indexed {collection.count()} chunks')
