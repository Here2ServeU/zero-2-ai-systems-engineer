# Week 16 - Retrieval-Augmented Generation with ChromaDB

> Chapter 17 of *Zero 2 AI Systems Engineer*. Layer 8 — Modern AI · LLMs & RAG.

## Objective

Ground the Week 15 LLM feature in a private knowledge base. Build a retrieval-augmented generation (RAG) pipeline that ingests internal documents, embeds them, stores the vectors in ChromaDB, retrieves the most relevant chunks at query time, and feeds them to Claude as grounding context.

## What I Will Build

- A document ingestion script that chunks and embeds source documents
- A persistent ChromaDB collection that stores the embeddings and metadata
- A retrieval function that returns the top-k chunks for a query
- An updated `/chat` endpoint that augments the prompt with retrieved context and cites source documents in the response

## Prerequisites

- The Week 15 LLM endpoint working locally
- Sample knowledge-base documents under `data/` (the chapter ships seed text)

## Local Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export ANTHROPIC_API_KEY=...
python3 course/week-16-rag-pipeline/src/ingest.py
python3 course/week-16-rag-pipeline/src/app.py
```

## Layered Position

- Depends on: Week 15 (LLM Customer Service)
- Feeds into: Week 17 (Production LLM Systems), Capstone
