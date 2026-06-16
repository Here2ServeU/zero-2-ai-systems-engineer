# Chapter 16 — Foundations of Large Language Models

**Book:** Chapter 16 (Foundations of Large Language Models) · Lab 16.5
**Layer:** 8 · Modern AI · **You build:** Your first production LLM endpoint

## What you build

- `verify_api.py` — the simplest call that proves your Anthropic API key works.
- `llm_api.py` — a Flask `/chat` endpoint wrapping Claude behind a system prompt, with
  input validation, request IDs, structured logging, and token accounting.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install anthropic flask python-dotenv

export ANTHROPIC_API_KEY='your-key-here'   # PowerShell: $env:ANTHROPIC_API_KEY='...'

python verify_api.py
python llm_api.py            # Terminal 1
# Terminal 2:
curl -X POST http://localhost:5000/chat \
  -H 'Content-Type: application/json' \
  -d '{"question":"How do I reset my pin?"}'
```

> **Model id:** the book uses `model='claude-opus-4-7'`. Set this to a currently
> available Claude model (e.g. `claude-opus-4-8` or `claude-sonnet-4-6`) for your account.
> Never hardcode the API key — use an env var locally, a secrets manager in production.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we phone a very well-read robot (called an **LLM** — think of it as a
super-smart pen pal that can read and write words) and ask it questions over the
internet. The robot lives at a company called Anthropic, and the model we talk to is
named **Claude**.

### `verify_api.py` — the "is the phone working?" test

**In one sentence:** It makes the simplest possible call to the robot to prove your
secret password works.

**What it does, step by step:**

1. It picks up the phone to the robot. The robot's phone number is the **Claude/Anthropic
   API** — "API" just means a way for your program to talk to the robot over the internet.
2. To make the call you need a secret password called an **API key**. The code reads
   that password from your computer's settings (`os.environ['ANTHROPIC_API_KEY']`) so you
   never have to type it into the file.
3. It sends a tiny **prompt** — a prompt is just the question or instructions you send.
   Here the prompt is: "Say hello in one sentence."
4. The line `model='claude-opus-4-7'` is the robot's name tag. `claude-opus-4-7` is the
   name the book uses as an example. In real life you set it to a robot that exists today,
   like `claude-opus-4-8` (very smart) or `claude-sonnet-4-6` (fast and a little cheaper).
5. `max_tokens=200` is a size limit. A "token" is a small piece of a word. This says
   "don't write back more than about 200 little word-pieces."
6. It prints the robot's answer, plus how many word-pieces went in and came out — that's
   how you see how much the call "cost."

**What you get:** Proof that your secret password works and the robot is answering you.

### `llm_api.py` — a little front desk that passes your questions to the robot

**In one sentence:** It builds a tiny website door (`/chat`) so other people can send a
banking question and get the robot's answer back.

**What it does, step by step:**

1. It starts a small web server using Flask. Think of Flask as a front desk that listens
   for visitors knocking at the door.
2. It opens the phone line to the robot using your secret password (the **API key**),
   just like `verify_api.py` did.
3. It writes a **system prompt** — that's a standing instruction the robot always follows.
   Here it says: "You are a helpful customer support agent for Nawex Bank. Answer in two
   short paragraphs. If the question isn't about banking, politely say no."
4. When someone knocks on the `/chat` door and hands over a question, the front desk first
   gives that visit a short ticket number (a "request ID") so it can be tracked in the logs.
5. It checks the visitor actually wrote a question. If the question is empty, it politely
   sends back an error instead of bothering the robot.
6. It phones the robot with the system prompt plus the visitor's question. Again
   `model='claude-opus-4-7'` is the example robot name — swap it for a real one like
   `claude-opus-4-8` or `claude-sonnet-4-6` for your own account. `max_tokens=512` lets the
   answer be a bit longer than the test script.
7. It writes the answer back to the visitor, along with the ticket number, the time, and
   how many word-pieces were used.

**What you get:** A working "ask the bank robot a question" web door that logs every call.

➡ Next: [chapter-17-rag](../chapter-17-rag) — ground the LLM in a private knowledge base.
