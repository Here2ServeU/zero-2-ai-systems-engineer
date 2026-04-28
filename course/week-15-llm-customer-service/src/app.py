"""Customer-service LLM endpoint backed by Anthropic Claude.

Placeholder for Chapter 16. The full chapter adds auth, rate limiting,
prompt versioning, structured logging, and recorded-response tests.
"""

import os

from anthropic import Anthropic
from flask import Flask, jsonify, request

MODEL = "claude-sonnet-4-6"
SYSTEM_PROMPT = (
    "You are a customer-service assistant for the Nawex AI Reliability "
    "Platform. Answer concisely. If you do not know the answer, say so."
)

app = Flask(__name__)
client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


@app.post("/chat")
def chat():
    payload = request.get_json(force=True)
    user_message = payload["message"]

    response = client.messages.create(
        model=MODEL,
        max_tokens=512,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )
    return jsonify({"reply": response.content[0].text})


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
