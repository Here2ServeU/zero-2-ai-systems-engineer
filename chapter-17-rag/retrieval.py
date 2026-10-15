# retrieval.py
import chromadb
from chromadb.utils import (
    embedding_functions as ef)

client = chromadb.PersistentClient(
    path='./vector_db')
embed = ef.SentenceTransformerEmbeddingFunction(
    model_name='all-MiniLM-L6-v2')
collection = client.get_collection(
    name='compliance_kb',
    embedding_function=embed)

def retrieve(question, k=3):
    results = collection.query(
        query_texts=[question],
        n_results=k)
    return results['documents'][0]

if __name__ == '__main__':
    q = 'What are KYC requirements?'
    for i, chunk in enumerate(retrieve(q)):
        print(f'--- Match {i+1} ---')
        print(chunk[:200])
        print()
