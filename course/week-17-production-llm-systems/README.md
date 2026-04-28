# Week 17 - Production LLM Systems

> Chapter 18 of *Zero 2 AI Systems Engineer*. Layer 8 — Modern AI · LLMs & RAG.

## Objective

Take the LLM and RAG features built in Weeks 15-16 and harden them for production. Add the controls that distinguish a demo from a system you can run at 3 a.m. on a Sunday: prompt caching, evaluation harnesses, output validation, cost guardrails, fallback behavior, and PII handling.

## What I Will Build

- Prompt caching that reuses the cached system prompt across requests
- An evaluation harness that scores responses on a held-out question set
- An output validator that rejects responses violating shape or policy rules
- Cost guardrails: per-request token caps, per-tenant daily budgets, alerting hooks
- A fallback path that returns a degraded-but-safe response when Claude is unavailable
- A PII redactor that strips sensitive fields from logs

## Prerequisites

- Working LLM and RAG endpoints from Weeks 15-16
- Prometheus + Grafana stack from Week 10 (for cost and latency dashboards)

## Local Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export ANTHROPIC_API_KEY=...
python3 course/week-17-production-llm-systems/src/eval_harness.py
python3 course/week-17-production-llm-systems/src/app.py
```

## Layered Position

- Depends on: Week 15 (LLM), Week 16 (RAG), Week 10 (Observability), Week 14 (Dashboards)
- Feeds into: Capstone
