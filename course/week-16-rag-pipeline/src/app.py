"""RAG-augmented chat endpoint.

Placeholder for Chapter 17. Retrieves the top-k chunks from ChromaDB
for each user question and includes them in the Claude prompt as
grounding context, with citations returned in the response payload.
"""

import os

import chromadb
from anthropic import Anthropic
from flask import Flask, jsonify, request

MODEL = "claude-sonnet-4-6"
PERSIST_DIR = "course/week-16-rag-pipeline/chroma"
COLLECTION = "knowledge_base"
TOP_K = 4

app = Flask(__name__)
client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
chroma = chromadb.PersistentClient(path=PERSIST_DIR).get_collection(COLLECTION)


def build_prompt(question: str, chunks: list[str]) -> str:
    context = "\n\n---\n\n".join(chunks)
    return (
        "Answer the question using only the context below. "
        "If the answer is not in the context, say you do not know.\n\n"
        f"Context:\n{context}\n\nQuestion: {question}"
    )


@app.post("/chat")
def chat():
    question = request.get_json(force=True)["message"]
    hits = chroma.query(query_texts=[question], n_results=TOP_K)
    chunks = hits["documents"][0]
    sources = [m["source"] for m in hits["metadatas"][0]]

    response = client.messages.create(
        model=MODEL,
        max_tokens=512,
        messages=[{"role": "user", "content": build_prompt(question, chunks)}],
    )
    return jsonify({"reply": response.content[0].text, "sources": sources})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
