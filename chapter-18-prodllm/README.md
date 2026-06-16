# Chapter 18 — Production LLM Systems

**Book:** Chapter 18 (Production LLM Systems) · Lab 18.5
**Layer:** 8 · Modern AI · **You build:** A production-grade LLM wrapper

## What you build

`production_llm.py` consolidates every Part V guardrail into one deployable service:
prompt-hash caching, per-user token budgets, input safety filtering, retry with
exponential backoff (`tenacity`), structured logging with request IDs, and Prometheus
metrics for token consumption and latency.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install anthropic flask tenacity prometheus-client
export ANTHROPIC_API_KEY='your-key-here'

python production_llm.py
```

Test caching (3 identical calls → first hits the API, next two are cached/free),
the safety filter, and the metrics endpoint:

```bash
for i in 1 2 3; do
  curl -s -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
    -d '{"user_id":"alice","prompt":"What is RAG?"}'; echo
done
curl -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
  -d '{"user_id":"alice","prompt":"My SSN: 123-45-6789"}'   # rejected by safety filter
curl http://localhost:8000/metrics | grep llm_
```

> Set `model='claude-opus-4-7'` to a currently available Claude model for your account.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we get the robot ready for **production** — that just means real, everyday use by
many people at once. So we add safety rules and money-saving tricks around the robot.

### `production_llm.py` — the robot, all dressed up for the real world

**In one sentence:** It builds a web door (`/llm`) that talks to the robot, but wraps it in
guardrails so it is safe, cheap, and reliable for lots of users.

**What it does, step by step:**

1. It starts a Flask web server (a front desk that listens for visitors) and opens the
   phone line to the robot (Claude) using your secret password, the **API key**.
2. It sets up counters and timers so you can watch how the service is doing — how many calls,
   how many word-pieces, and how long each call takes.
3. It keeps a **cache** — a little memory box. If someone asks a question that was already
   answered, it hands back the saved answer instead of phoning the robot again. That means you
   don't pay to ask the same thing twice.
4. It keeps a **budget** for each user. `DAILY_TOKEN_LIMIT = 50000` is a spending cap: once a
   person uses about 50,000 word-pieces in a day, they're politely cut off so costs don't run
   wild.
5. It has a **safety filter** (a guardrail). It blocks any message that contains risky things
   like `ssn:`, `credit card:`, `password:`, or `api key:`, so private secrets don't get sent
   to the robot.
6. When a visitor knocks on `/llm`: it gives the visit a ticket number, checks there's a real
   question, runs the safety filter, checks the budget, and then checks the cache.
7. If the answer isn't in the cache, it phones the robot. The call has a **retry** built in:
   if the call fails, it waits a moment and tries again (up to 3 times), waiting a bit longer
   each time so it doesn't hammer the robot. Here `model='claude-opus-4-7'` is the example
   robot name the book uses — in real life set it to a robot that exists today, like
   `claude-opus-4-8` or `claude-sonnet-4-6`. `max_tokens=512` keeps each answer a sensible
   length.
8. When the answer comes back, it records the time and word-pieces, adds the answer to the
   cache for next time, charges the word-pieces to that user's budget, and sends the answer
   back with its ticket number.

**What you get:** A grown-up, real-world robot service that won't leak secrets, won't
overspend, won't pay twice for the same question, and keeps trying when the network hiccups.

➡ Next: the capstones — [nexaguard](../nexaguard) (FinTech) and [clarityai](../clarityai) (Healthcare).
