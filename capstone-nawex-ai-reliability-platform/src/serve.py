"""Single Flask app exposing every platform layer through one process.

Endpoints
---------
GET  /health             liveness check used by Kubernetes
GET  /metrics            Prometheus exposition format
POST /predict/fraud      classical ML fraud classifier (Layer 2)
POST /predict/anomaly    healthcare anomaly detector (Layer 2)
POST /chat               LLM customer service (Layer 8 / Week 15)
POST /chat-rag           RAG-grounded LLM (Layer 8 / Week 16)

The fraud and anomaly endpoints depend on `train_models.py` having run.
The RAG endpoint depends on `ingest_kb.py` having run.
"""

import os

import chromadb
import joblib
import pandas as pd
from anthropic import Anthropic
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest

import paths
from ingest_kb import COLLECTION
from train_models import FRAUD_FEATURES, VITALS_FEATURES

MODEL = "claude-sonnet-4-6"
SYSTEM_PROMPT = (
    "You are the customer-service assistant for the Nawex AI Reliability "
    "Platform. Answer concisely. If you do not know, say so."
)
TOP_K = 4

app = Flask(__name__)
fraud_model = joblib.load(paths.FRAUD_MODEL)
anomaly_model = joblib.load(paths.ANOMALY_MODEL)
anthropic = Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", "missing"))
chroma = chromadb.PersistentClient(path=str(paths.CHROMA_DIR)).get_collection(COLLECTION)

REQUESTS = Counter("nawex_requests_total", "Total requests by endpoint", ["endpoint"])
LATENCY = Histogram("nawex_request_seconds", "Request latency by endpoint", ["endpoint"])


def predict_dataframe(payload: dict, columns: list[str]) -> pd.DataFrame:
    return pd.DataFrame([[payload[c] for c in columns]], columns=columns)


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": "text/plain; version=0.0.4"}


@app.post("/predict/fraud")
def predict_fraud():
    REQUESTS.labels("predict_fraud").inc()
    with LATENCY.labels("predict_fraud").time():
        sample = predict_dataframe(request.get_json(force=True), FRAUD_FEATURES)
        proba = float(fraud_model.predict_proba(sample)[0, 1])
        return jsonify({"is_fraud": proba >= 0.5, "probability": proba})


@app.post("/predict/anomaly")
def predict_anomaly():
    REQUESTS.labels("predict_anomaly").inc()
    with LATENCY.labels("predict_anomaly").time():
        sample = predict_dataframe(request.get_json(force=True), VITALS_FEATURES)
        flagged = int(anomaly_model.predict(sample)[0] == -1)
        score = float(anomaly_model.score_samples(sample)[0])
        return jsonify({"is_anomaly": bool(flagged), "score": score})


@app.post("/chat")
def chat():
    REQUESTS.labels("chat").inc()
    with LATENCY.labels("chat").time():
        question = request.get_json(force=True)["message"]
        response = anthropic.messages.create(
            model=MODEL,
            max_tokens=512,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": question}],
        )
        return jsonify({"reply": response.content[0].text})


@app.post("/chat-rag")
def chat_rag():
    REQUESTS.labels("chat_rag").inc()
    with LATENCY.labels("chat_rag").time():
        question = request.get_json(force=True)["message"]
        hits = chroma.query(query_texts=[question], n_results=TOP_K)
        chunks = hits["documents"][0]
        sources = [m["source"] for m in hits["metadatas"][0]]

        prompt = (
            "Answer using only the context below. If the answer is not "
            f"in the context, say you do not know.\n\nContext:\n"
            + "\n\n---\n\n".join(chunks)
            + f"\n\nQuestion: {question}"
        )
        response = anthropic.messages.create(
            model=MODEL,
            max_tokens=512,
            messages=[{"role": "user", "content": prompt}],
        )
        return jsonify({"reply": response.content[0].text, "sources": sources})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
