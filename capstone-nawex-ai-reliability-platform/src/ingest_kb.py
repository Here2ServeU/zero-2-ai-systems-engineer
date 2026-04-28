"""Ingest the knowledge-base markdown files into a persistent ChromaDB collection.

Wires Layer 8 (RAG) into the capstone. Run before `serve.py` so the
`/chat-rag` endpoint has documents to retrieve from.
"""

import chromadb

import paths

COLLECTION = "nawex_knowledge_base"


def chunk(text: str, size: int = 800, overlap: int = 100) -> list[str]:
    chunks, start = [], 0
    while start < len(text):
        end = min(start + size, len(text))
        chunks.append(text[start:end])
        start = end - overlap
    return chunks


def main() -> None:
    paths.CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(paths.CHROMA_DIR))
    collection = client.get_or_create_collection(COLLECTION)

    for md in sorted(paths.KNOWLEDGE_BASE.glob("*.md")):
        text = md.read_text()
        for idx, piece in enumerate(chunk(text)):
            doc_id = f"{md.stem}-{idx}"
            collection.upsert(
                ids=[doc_id],
                documents=[piece],
                metadatas=[{"source": md.name, "chunk": idx}],
            )
    print(f"Indexed {collection.count()} chunks into {COLLECTION}")


if __name__ == "__main__":
    main()
