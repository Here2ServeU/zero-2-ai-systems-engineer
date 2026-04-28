"""Ingest knowledge-base documents into a persistent ChromaDB collection.

Placeholder for Chapter 17. The chapter walks through chunking strategy,
embedding choice, and metadata design in detail.
"""

import pathlib

import chromadb

DATA_DIR = pathlib.Path("course/week-16-rag-pipeline/data")
PERSIST_DIR = "course/week-16-rag-pipeline/chroma"
COLLECTION = "knowledge_base"


def chunk(text: str, size: int = 800, overlap: int = 100) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + size, len(text))
        chunks.append(text[start:end])
        start = end - overlap
    return chunks


def main() -> None:
    client = chromadb.PersistentClient(path=PERSIST_DIR)
    collection = client.get_or_create_collection(COLLECTION)

    for path in sorted(DATA_DIR.glob("*.md")):
        text = path.read_text()
        for idx, piece in enumerate(chunk(text)):
            doc_id = f"{path.stem}-{idx}"
            collection.upsert(
                ids=[doc_id],
                documents=[piece],
                metadatas=[{"source": path.name, "chunk": idx}],
            )
    print(f"Indexed {collection.count()} chunks into {COLLECTION}")


if __name__ == "__main__":
    main()
