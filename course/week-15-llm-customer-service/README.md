# Week 15 - LLM-Powered Customer Service with Claude

> Chapter 16 of *Zero 2 AI Systems Engineer*. Layer 8 — Modern AI · LLMs & RAG.

## Objective

Add the platform's first generative-AI feature: a customer-service assistant powered by Anthropic's Claude. The feature must run behind production-grade controls — auth, rate limiting, structured logging, prompt and response auditing, and graceful degradation when the upstream model is unavailable.

## What I Will Build

- A Flask endpoint that proxies user questions to the Claude API
- A typed prompt template and system prompt versioned alongside the code
- Per-request structured logs that capture prompt, response, latency, token usage, and cost estimate
- An integration test suite using recorded model responses (so CI never calls the live API)

## Prerequisites

- An Anthropic API key in `ANTHROPIC_API_KEY` (see Chapter 16 setup)
- The Flask service from Week 4 (Serving Models via APIs) running locally

## Local Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export ANTHROPIC_API_KEY=...
python3 course/week-15-llm-customer-service/src/app.py
```

## Layered Position

- Depends on: Week 4 (APIs), Week 5 (Docker), Week 10 (Observability)
- Feeds into: Week 16 (RAG Pipeline), Week 17 (Production LLM Systems), Capstone
