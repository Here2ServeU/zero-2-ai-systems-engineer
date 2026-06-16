# Chapter 16 — Foundations of Large Language Models

**Book:** Chapter 16 (Foundations of Large Language Models) · Lab 16.5
**Layer:** 8 · Modern AI · **You build:** Your first production LLM endpoint

## What you build

- `verify_api.py` — the simplest call that proves your Anthropic API key works.
- `llm_api.py` — a Flask `/chat` endpoint wrapping Claude behind a system prompt, with
  input validation, request IDs, structured logging, and token accounting.

**Three provider options.** The book uses **Anthropic Claude**, but the exact same lab
works with **OpenAI** or **Google Gemini** — pick whichever account you have. Each provider
has its own pair of scripts that behave identically (same `/chat` door, same JSON answer):

| Provider | Verify script | API script | Install | API key env var |
|---|---|---|---|---|
| Anthropic (Claude) | `verify_api.py` | `llm_api.py` | `pip install anthropic flask` | `ANTHROPIC_API_KEY` |
| OpenAI (GPT) | `verify_api_openai.py` | `llm_api_openai.py` | `pip install openai flask` | `OPENAI_API_KEY` |
| Google (Gemini) | `verify_api_gemini.py` | `llm_api_gemini.py` | `pip install google-genai flask` | `GEMINI_API_KEY` |

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate

# ---- Option A: Anthropic (Claude) — the book's default ----
pip install anthropic flask python-dotenv
export ANTHROPIC_API_KEY='your-key-here'   # PowerShell: $env:ANTHROPIC_API_KEY='...'
python verify_api.py
python llm_api.py                           # Terminal 1

# ---- Option B: OpenAI (GPT) ----
pip install openai flask
export OPENAI_API_KEY='your-key-here'
python verify_api_openai.py
python llm_api_openai.py                     # Terminal 1

# ---- Option C: Google (Gemini) ----
pip install google-genai flask
export GEMINI_API_KEY='your-key-here'
python verify_api_gemini.py
python llm_api_gemini.py                      # Terminal 1

# Any of the three answers the SAME request (Terminal 2):
curl -X POST http://localhost:5000/chat \
  -H 'Content-Type: application/json' \
  -d '{"question":"How do I reset my pin?"}'
```

> **Model ids:** the book uses `model='claude-opus-4-7'`. Set this to a currently
> available model for whichever provider you chose:
> - **Anthropic:** `claude-opus-4-8` (smartest) or `claude-sonnet-4-6` (fast, cheaper)
> - **OpenAI:** `gpt-4o` (default) or `gpt-4o-mini` (fast, cheaper)
> - **Gemini:** `gemini-2.5-pro` (smartest) or `gemini-2.5-flash` (fast, cheaper)
>
> Never hardcode the API key — use an env var locally, a secrets manager in production.
> Get a key from [console.anthropic.com](https://console.anthropic.com),
> [platform.openai.com](https://platform.openai.com), or
> [aistudio.google.com](https://aistudio.google.com).

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

### The OpenAI and Gemini twins — the same robot, a different company

There isn't just one well-read robot for hire. Three big companies each rent you one,
and they all do the same job: you send words, they send words back. This chapter ships a
matching pair of scripts for each company so you can use whichever one you have a key for.

- **Anthropic's robot is named Claude** → `verify_api.py` + `llm_api.py`
- **OpenAI's robot is named GPT** → `verify_api_openai.py` + `llm_api_openai.py`
- **Google's robot is named Gemini** → `verify_api_gemini.py` + `llm_api_gemini.py`

**In one sentence:** The OpenAI and Gemini scripts are exact copies of the Claude scripts —
same test, same `/chat` door, same answer shape — just phoning a different company's robot.

**What's the same in all three:**

1. You still need a secret password (an **API key**), read from your computer's settings so
   it never sits in the file. Each company gives you its own key, stored under its own name:
   `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`.
2. You still send a **prompt** (your question) and the same **system prompt** (the standing
   "you are a Nawex Bank helper" instruction).
3. You still get back the answer plus how many word-pieces (**tokens**) went in and out.
4. The `/chat` web door still listens on port 5000 and replies with the same fields, so the
   one `curl` command works no matter which robot you started.

**What's a little different (just the robot's name tag):**

1. The shopping list changes: `pip install openai flask` for GPT, or
   `pip install google-genai flask` for Gemini.
2. The model name changes: `gpt-4o` for OpenAI, `gemini-2.5-flash` for Gemini (swap in
   `gpt-4o-mini` or `gemini-2.5-pro` to go cheaper or smarter) — just like you'd swap
   `claude-opus-4-7` for a real Claude name.
3. Each company words the phone call slightly differently inside the code, but you don't
   have to care — the scripts hide that for you and hand back the same tidy answer.

**What you get:** Three interchangeable ways to power the very same bank-helper door, so you
can start with whichever account you already have — or compare the robots side by side.

➡ Next: [chapter-17-rag](../chapter-17-rag) — ground the LLM in a private knowledge base.
