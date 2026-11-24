# Chapter 16 — Talk to a smart writing robot (LLM)

> Matches Chapter 16 in the book.

**Labels:** Needs an LLM account that may cost money (a fraction of a cent per test) · Needs the internet · Phase 2 and 3 need an AWS account that costs money

---

> ### Money and secrets: please read this first
>
> This chapter talks to a paid online robot service. To use it you need an **API key**. Think of
> an API key as a **credit card for a robot service**. Each time your program phones the robot,
> it can cost a small amount of money (usually a fraction of a cent for these tiny tests, but it
> is not free).
>
> - **Get permission first** if the account isn't yours. Ask the person who owns it before you
>   run anything that spends money.
> - **Never paste the key into your code, never commit it to git, and never share it.** Anyone
>   with your key can spend your money. Keep it in an **environment variable** (a setting in your
>   terminal), exactly as this chapter shows.
> - **You only need ONE robot company.** The book offers three (Anthropic Claude, OpenAI,
>   Google Gemini). Pick whichever you can sign up for. **Google Gemini has a free tier**, the
>   cheapest, friendliest way to start.
> - **No key? No problem.** It's completely fine to *read* this chapter to understand how it
>   works. You can still do Steps 1, 2 and 5 and see the friendly "no key" error yourself.

---

## The platform you are building

From this chapter on you build an **LLM application platform**, sometimes called an **AI
gateway**: one API of your own that sits in front of LLM providers (Anthropic, OpenAI, Google).
Your other apps ask *your* API, never the provider directly. That means the secret keys live in
one safe place, you can switch providers with one setting, and you can count every token you pay
for. Companies pay for this because every team wants to use LLMs, and nobody wants keys copied
into fifty apps or a surprise bill. The people who build it are called **AI Engineers**, **LLM
Engineers**, **AI Platform Engineers** and **ML Platform Engineers**.

## How this builds on Chapter 15

Chapters 11 to 15 watched and released a fraud model that *you* trained. This is the first
chapter where the "model" is a giant text robot that someone else runs, and you call it over the
internet.

What carries over:

- **Flask from Chapter 05.** The `/chat` front desk is a Flask app with a `/health` door, like
  every app so far.
- **Docker from Chapter 06.** The same container habits: a `Dockerfile`, a non-root user, and
  secrets passed in at run time, never baked in.
- **The whole shared cloud platform from Chapter 10.** In Phase 2 and 3 you reuse the EKS cluster,
  the shared Helm chart, the platform load balancer (ALB) and the monitoring stack from
  Chapters 11 and 15 (Grafana shows your pods' CPU and memory, and `kubectl logs` shows every
  request's ticket number and token count).

What is new: **API keys** (a secret that costs money if it leaks), **tokens** (how LLMs measure
work and cost), and in Phase 3 **AWS Secrets Manager** with **External Secrets** to keep the
keys safe.

```text
Your platform so far

  Ch 10  EKS cluster + shared Helm chart + load balancer (ALB)
  Ch 11  apps count things -> Prometheus collects the numbers
  Ch 12  a watcher reacts to those numbers
  Ch 13  retraining when the model drifts
  Ch 14  safe releases (canary, blue/green)
  Ch 15  Grafana dashboards as code + golden-signal alerts
  Ch 16  your own LLM API, keys kept in AWS Secrets Manager   <-- you are here
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **1 — Build it on your laptop** | Your computer (Python, then Docker) | Phone the LLM once, build the `/chat` front desk, pack it in a container | Free on your laptop, plus a fraction of a cent per LLM question (Gemini has a free tier) |
| **2 — Promote it to the cloud** | AWS EKS (the shared platform) | 2A: plain YAML, key in a Kubernetes Secret. 2B: Helm, switch provider with one setting | AWS platform cost while it runs, plus LLM questions |
| **3 — Run it like a Fortune 500 company** | AWS EKS | Keys from AWS Secrets Manager, autoscaling, disruption budget, network rules, public address | AWS platform cost while it runs, plus LLM questions |

## New words

Look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md).

- **LLM (Large Language Model)** — a super-smart pen pal: software that reads and writes text
  and answers questions. Claude, GPT and Gemini are examples.
- **Provider** — the company that runs the LLM and sells access to it (Anthropic, OpenAI,
  Google).
- **Prompt** — the question or instructions you send to the robot.
- **System prompt** — a standing instruction the robot *always* follows, like "you are a polite
  bank helper."
- **Token** — a small piece of a word. The robot measures its work, and its price, in tokens.
- **API key** — a secret password that lets your program use the paid robot service. Keep it in
  an environment variable, never in your code.
- **Environment variable** — a labelled setting that lives in your terminal (or container), like
  `ANTHROPIC_API_KEY`. Programs can read it, but it is not saved in your files.
- **SDK** — a ready-made helper library from the provider (`anthropic`, `openai`,
  `google-genai`) that knows how to phone its robot.

---

## Phase 1 — Build it on your laptop

### The big idea (in plain words)

Imagine a **pen pal** who has read almost every book and article in the world. You can phone this
pen pal over the internet, ask any question in plain words, and they write back a helpful answer.
That pen pal is an **LLM**.

In Phase 1 you'll:

1. Make the **simplest possible phone call** to the robot to prove your API key works.
2. Build a tiny **front desk** (a web door called `/chat`) so other programs can send a banking
   question and get the robot's answer back.
3. **Pack the front desk in a container**, ready for the cloud.

### What you will build

- `verify_api.py` — the "is the phone working?" test.
- `llm_api.py` — a small web service with a `/chat` door (and a `/health` door). Other programs
  send a banking question and get the robot's answer back, with a ticket number and a count of
  tokens used.
- `Dockerfile` — the recipe that packs the front desk into a container.

The files are already in this folder. The `..._openai.py` and `..._gemini.py` files are the
*same* scripts for the other two companies. **Pick one company and use only its pair of files.**

| Company | Test file | Front desk file | Key name |
|---|---|---|---|
| Anthropic (Claude), the book's default | `verify_api.py` | `llm_api.py` | `ANTHROPIC_API_KEY` |
| OpenAI (GPT) | `verify_api_openai.py` | `llm_api_openai.py` | `OPENAI_API_KEY` |
| Google (Gemini), has a free tier | `verify_api_gemini.py` | `llm_api_gemini.py` | `GEMINI_API_KEY` |

> **Heads up: Steps 4 to 6 need TWO terminals.** One terminal *runs* the front desk and stays
> busy listening. The other terminal *sends* it a question. That's normal.

### Step 1 — Go to the folder and check Python

From the top of the repo:

```bash
cd chapter-16-llm
python3 --version
```

**What you should see:** `Python 3.10.x` or newer (for example `Python 3.11.9`).

> **Windows:** use `python` instead of `python3` everywhere in this chapter.

### Step 2 — Make a clean toolbox and install the helpers

From `chapter-16-llm`:

```bash
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*) for this
  project, so its tools don't bump into other projects.
- `source venv/bin/activate` steps *into* that toolbox. Your prompt now starts with `(venv)`.

Now install the helpers for **the one company you picked**:

```bash
# Option A - Anthropic (Claude), the book's default:
pip install anthropic flask python-dotenv

# Option B - OpenAI (GPT):
pip install openai flask

# Option C - Google (Gemini), has a free tier:
pip install google-genai flask
```

**What you should see:** packages downloading, ending with a line like
`Successfully installed anthropic-... flask-...`.

### Step 3 — Get a key and put it in an environment variable

Sign up and create a key on your company's website:

- **Anthropic:** [console.anthropic.com](https://console.anthropic.com)
- **OpenAI:** [platform.openai.com](https://platform.openai.com)
- **Google Gemini:** [aistudio.google.com](https://aistudio.google.com)

Then tell *this terminal* about your key. Use only the line for your company, and paste your real
key between the quotes:

```bash
# Mac / Linux / Git Bash (pick one):
export ANTHROPIC_API_KEY='your-key-here'
export OPENAI_API_KEY='your-key-here'
export GEMINI_API_KEY='your-key-here'
```

```powershell
# Windows PowerShell (pick one):
$env:ANTHROPIC_API_KEY='your-key-here'
$env:OPENAI_API_KEY='your-key-here'
$env:GEMINI_API_KEY='your-key-here'
```

- `export NAME='value'` puts your secret into a labelled slot in this terminal. The code reads it
  from there, so the key never sits inside your files and can never be committed to git by
  accident.
- **It only lasts for this terminal window.** Open a new terminal and you must set it again.
  (That's the most common stumble. See "If something breaks.")

Check it's set, without printing the secret itself:

```bash
python3 -c "import os; print('key is set' if os.environ.get('ANTHROPIC_API_KEY') else 'key is MISSING')"
```

(Change `ANTHROPIC_API_KEY` to your company's key name.) **What you should see:** `key is set`.

> **About model names.** Each file names the robot it calls: `claude-opus-4-7` (Anthropic),
> `gpt-4o` (OpenAI) and `gemini-2.5-flash` (Gemini), exactly as in the book. Providers retire old
> models over time. If you ever get a "model not found" error, open your provider's models page
> and put a current model name in the `model=` line. Want it cheaper? Anthropic's
> `claude-haiku-4-5` is much cheaper than Opus for these small tests.

### Step 4 — Run the "is the phone working?" test

From `chapter-16-llm`, with your toolbox active:

```bash
python verify_api.py          # Anthropic
# python verify_api_openai.py # OpenAI
# python verify_api_gemini.py # Gemini
```

**What you should see:** a one-sentence hello written *by the robot*, then two number lines,
something like:

```
Hello! It's a pleasure to meet you.
Input tokens: 12
Output tokens: 11
```

The exact words change every time. That's normal: the robot writes a fresh answer each time.

**What `verify_api.py` does, in plain words:**

```python
import anthropic, os

client = anthropic.Anthropic(
    api_key=os.environ['ANTHROPIC_API_KEY'])
```

- `import anthropic, os` — bring in the helper that knows how to phone the robot, plus `os`,
  which reads your terminal's settings.
- `os.environ['ANTHROPIC_API_KEY']` — read your secret from the slot you set in Step 3. The key
  is *never typed into the file*.
- `anthropic.Anthropic(api_key=...)` — pick up the phone, using that key to prove it's you.

```python
msg = client.messages.create(
    model='claude-opus-4-7',
    max_tokens=200,
    messages=[
        {'role':'user',
         'content':'Say hello in one sentence.'}
    ])
```

- `model='claude-opus-4-7'` — the robot's name tag: which model to ask.
- `max_tokens=200` — a size limit: "don't write back more than about 200 word-pieces." This also
  caps what one answer can cost.
- `messages=[{'role':'user','content':'Say hello in one sentence.'}]` — your **prompt**.

```python
print(msg.content[0].text)
print('Input tokens:', msg.usage.input_tokens)
print('Output tokens:', msg.usage.output_tokens)
```

- `msg.content[0].text` — the robot's written answer.
- `input_tokens` / `output_tokens` — how many word-pieces went *in* and came *out*. Providers
  charge per token, so this is how you see what the call cost.

### Step 5 — Start the front desk (Terminal 1)

This terminal runs the `/chat` server and keeps running. From `chapter-16-llm`, with your toolbox
active and your key set:

```bash
python llm_api.py             # Anthropic
# python llm_api_openai.py    # OpenAI
# python llm_api_gemini.py    # Gemini
```

**What you should see:**

```
 * Serving Flask app 'llm_api'
 * Debug mode: off
... WARNING: This is a development server. Do not use it in a production deployment. ...
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
... Press CTRL+C to quit
```

The front desk is open on **port 5000**. The warning is normal for a practice app. **Don't close
or type in this terminal.** (If you see `KeyError: 'ANTHROPIC_API_KEY'` instead, the key isn't
set in *this* terminal. Go back to Step 3.)

**What `llm_api.py` does, in plain words:**

- It starts a **Flask** web server (a front desk that listens for visitors).
- It opens the phone line to the robot using your **API key**, just like the test did.
- It sets a **system prompt**, a standing rule the robot always follows: *"You are a helpful
  customer support agent for Zero2AI Bank. Answer in two short paragraphs. If the question is
  outside banking topics, politely decline."*
- It has a `/health` door that just answers `{"status":"healthy"}`. Kubernetes uses it in
  Phase 2 to check each copy is alive.

Here is the heart of it:

```python
@app.route('/chat', methods=['POST'])
def chat():
    rid = str(uuid.uuid4())[:8]
    data = request.get_json(silent=True) or {}
    question = data.get('question','').strip()
    if not question:
        return jsonify({'error':'Missing question','request_id':rid}), 422
```

- `@app.route('/chat', methods=['POST'])` — open a door named `/chat` that accepts data sent
  *to* it.
- `rid = str(uuid.uuid4())[:8]` — give this visit a short **ticket number** so it can be found in
  the logbook later.
- `question = data.get('question','').strip()` — read the question the visitor sent.
- `if not question: ...` — no question? Send back an error *without* phoning (and paying) the
  robot.

```python
    msg = client.messages.create(
        model='claude-opus-4-7',
        max_tokens=512,
        system=SYSTEM_PROMPT,
        messages=[{'role':'user','content':question}])
    answer = msg.content[0].text
```

- It phones the robot with the **system prompt** plus the visitor's **question**.
- `max_tokens=512` — lets the answer be a bit longer than the test.
- Then it sends the answer back with the ticket number, the time, and the token counts, and
  writes a logbook line with the token counts.

### Step 6 — Knock on the door (Terminal 2)

Leave Terminal 1 running. Open a **new** terminal (in VS Code: **Terminal -> New Terminal**).
You don't need the toolbox or the key in this one. First the free checks (they never call the
robot):

```bash
curl http://localhost:5000/health
curl -X POST http://localhost:5000/chat -H 'Content-Type: application/json' -d '{}'
```

**What you should see:**

```
{"status":"healthy"}
{"error":"Missing question","request_id":"1a2b3c4d"}
```

Your ticket number will be different. Now a real banking question (this one costs a fraction of
a cent):

```bash
curl -X POST http://localhost:5000/chat \
  -H 'Content-Type: application/json' \
  -d '{"question":"How do I reset my pin?"}'
```

- `curl` — a tool that knocks on a web door from the terminal.
- `-X POST` — "I'm *sending* you some data."
- `-H 'Content-Type: application/json'` — a note saying "the data is in **JSON**."
- `-d '{"question":"How do I reset my pin?"}'` — the question itself, written as JSON.

**What you should see:** a JSON answer written by the robot, something like:

```
{"answer":"To reset your PIN, log in to ... ","request_id":"a1b2c3d4","tokens_in":48,
 "tokens_out":96,"ts":"2026-06-16T12:00:00.123456"}
```

And in **Terminal 1**, two logbook lines with the same ticket number:
`[a1b2c3d4] Q: How do I reset my pin?` and `[a1b2c3d4] tokens in/out: 48/96`.

> **Windows PowerShell:** the single quotes in these `curl` lines don't work there. Run them in
> **Git Bash**, or use
> `Invoke-RestMethod -Method Post -Uri http://localhost:5000/chat -ContentType 'application/json' -Body '{"question":"How do I reset my pin?"}'`.

When you're done, press **Ctrl+C** in Terminal 1 to stop the front desk.

### Step 7 — Pack it in a container

In Phase 2 the front desk runs on a cloud cluster, and the cloud runs containers. So pack it.

**`Dockerfile`** — the recipe (already in this folder):

```dockerfile
# Dockerfile: Chapter 16's chat API. One image for all three robot companies;
# the command picks which: llm_api.py (Claude), llm_api_openai.py, llm_api_gemini.py.
# API keys are NEVER baked in: Kubernetes passes them in as environment variables.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY llm_api.py llm_api_openai.py llm_api_gemini.py ./

RUN useradd -m -u 1000 appuser
USER 1000

EXPOSE 5000
CMD ["python", "llm_api.py"]
```

- `requirements.txt` lists the helpers for **all three** companies, so one image works with any
  of them.
- It copies only the three front-desk files. The `.dockerignore` file keeps out your `venv/`
  folder and any `.env` file, so no secret can sneak into the image.
- It runs as a plain user (`1000`), not the all-powerful `root`.
- **There is no API key anywhere in this recipe.** You hand the key to the container when you
  start it.

In **Terminal 1**, from `chapter-16-llm`, build the image:

```bash
docker build -t zero2ai-llm-api .
```

**What you should see:** build steps scrolling past, ending with a line like
`naming to docker.io/library/zero2ai-llm-api`. The first build takes a few minutes.

Run it. `-e ANTHROPIC_API_KEY` (with no `=value`) means "copy this setting from my terminal into
the container," so you never type the key on the command line:

```bash
# Anthropic (uses the image's default command):
docker run --rm --name ch16-api -p 5000:5000 -e ANTHROPIC_API_KEY zero2ai-llm-api

# OpenAI:
# docker run --rm --name ch16-api -p 5000:5000 -e OPENAI_API_KEY zero2ai-llm-api python llm_api_openai.py

# Gemini:
# docker run --rm --name ch16-api -p 5000:5000 -e GEMINI_API_KEY zero2ai-llm-api python llm_api_gemini.py
```

**What you should see:** the same `Running on http://127.0.0.1:5000` lines as Step 5, now from
inside the container.

In **Terminal 2**, run the same checks as Step 6:

```bash
curl http://localhost:5000/health
curl -X POST http://localhost:5000/chat -H 'Content-Type: application/json' -d '{"question":"How do I reset my pin?"}'
```

**What you should see:** `{"status":"healthy"}`, then a JSON answer from the robot with
`tokens_in`, `tokens_out` and a `request_id`.

Stop it with **Ctrl+C** in Terminal 1 (or `docker stop ch16-api` in Terminal 2).

### Try it yourself

- **Change the system prompt.** In `llm_api.py`, edit `SYSTEM_PROMPT` to make the robot a helper
  for a *library* ("You are a friendly library assistant..."). Restart Terminal 1 and ask about
  borrowing books.
- **Ask a non-banking question and watch it refuse.** With the original bank prompt, send
  `{"question":"What's a good recipe for soup?"}`. The robot should *politely decline*. That's the
  system prompt doing its job.
- **Shrink the answer.** Lower `max_tokens` from `512` to `60` and ask again. The answer gets cut
  short, and `tokens_out` drops. Fewer tokens = lower cost.
- **Work out the cost.** Look up your model's price per million tokens on your provider's pricing
  page. Cost of one question = `tokens_in x input price / 1,000,000` +
  `tokens_out x output price / 1,000,000`. How many questions would one dollar buy?
- **Read the logbook.** After a few questions, look at **Terminal 1**: each call wrote lines with
  its ticket number and how many tokens went in and out.

### If something breaks

- **`KeyError: 'ANTHROPIC_API_KEY'`** (or `OPENAI_API_KEY` / `GEMINI_API_KEY`) when you start a
  script or the container -> The key isn't set *in this terminal*. Redo Step 3's `export` line
  (it only lasts for one terminal window). For the container, also check you passed
  `-e ANTHROPIC_API_KEY` (or your company's name).
- **Wrong key for the file** (for example you set `GEMINI_API_KEY` but ran `llm_api.py`) -> You
  get the same `KeyError`. Run the file that matches your company (see the table above).
- **`ModuleNotFoundError: No module named 'anthropic'`** (or `openai`, `google`, `flask`) -> You're
  not in the toolbox, or you installed a different company's helpers. Run
  `source venv/bin/activate` (Windows: `venv\Scripts\activate`) and the `pip install` line for
  your company again.
- **Invalid key.** The test script stops with one of these, and the front desk answers
  `500 Internal Server Error` with the same message in Terminal 1:
  - Anthropic: `anthropic.AuthenticationError: Error code: 401 ... 'authentication_error'`
  - OpenAI: `openai.AuthenticationError: Error code: 401 - Incorrect API key provided`
  - Gemini: `google.genai.errors.ClientError: 400 INVALID_ARGUMENT ... API key not valid`

  -> The key is wrong, has a typo, or was copied with extra spaces. Create a fresh key on your
  provider's website and `export` it again.
- **`Internal Server Error` from `curl`** -> The front desk caught a problem while phoning the
  robot. The real reason is always in **Terminal 1** (or `docker logs ch16-api`): read the last
  line. It's usually one of the errors in this list.
- **"Rate limit" or `429`** (`RateLimitError`, `RESOURCE_EXHAUSTED`) -> You asked too fast, or a
  free account hit its limit for the minute or day. Wait a minute and try again, and send fewer
  requests.
- **"Credit balance is too low", "insufficient_quota" or a billing error** -> The account has no
  money or free credit left. Add credit, or switch to Gemini's free tier.
- **"Model not found" or `404`** -> That model name was retired or isn't available to your
  account. Put a current model name from your provider's models page in the `model=` line.
- **`Connection error`, a long hang, or a timeout** -> This chapter needs the **internet**. Check
  you're online (and that a school or work network isn't blocking the provider), then try again.
- **`curl` says `Connection refused`, or `curl` looks stuck** -> The front desk isn't running, or
  you typed `curl` in the *same* terminal as the server. Check Terminal 1 still shows
  `Running on http://127.0.0.1:5000`, and run `curl` in a *second* terminal.
- **`Address already in use`, or `ports are not available` from Docker** -> Something else uses
  port 5000: the Step 5 server or the Step 7 container may still be running (Ctrl+C it, or
  `docker stop ch16-api`). **On a Mac, AirPlay Receiver uses port 5000:** turn it off in
  **System Settings -> General -> AirDrop & Handoff -> AirPlay Receiver**.
- **`curl` answers `403 Forbidden` on a Mac** -> That's AirPlay Receiver, not your app. Turn it
  off as above.
- **`DeprecationWarning: datetime.datetime.utcnow() is deprecated`** (Python 3.12 or newer) ->
  Harmless. It's a heads-up about a future Python version; the app still works.
- **You accidentally pasted a key into a file or a chat** -> Treat it as stolen. Delete that key
  on the provider's website right away and create a new one. If it was committed to git, deleting
  the line is not enough: the old commit still has it, so rotating the key is the only real fix.

### What you learned in Phase 1

- An **LLM** is a very well-read robot you phone over the internet to read and write words.
- An **API key** is a secret password (a credit card for the robot), kept in an environment
  variable, never in your code, your image or git.
- A **prompt** is what you ask; a **system prompt** is a standing rule the robot always follows.
- The robot measures its work, and its price, in **tokens**, and `max_tokens` caps the cost of
  one answer.
- You put an LLM behind your own **Flask** front desk (`/chat`) and packed it in a **container**
  that gets its key only at run time. That's the seed of an AI gateway.

---

## Phase 2 and Phase 3

Ready to put the front desk on a real cloud cluster?

- **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md). The same container
  on AWS EKS, with the key in a Kubernetes Secret made from your terminal.
- **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md).
  Keys from AWS Secrets Manager, key rotation, autoscaling, token budgets, and a runbook.

Build the shared platform first: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
It costs money while it runs, so destroy it when you finish for the day.

## Where to next

[Chapter 17 — Give the robot your own notes to read (RAG)](../chapter-17-rag/README.md). Right
now the robot answers from everything it ever read. Next you'll hand it *your own* notes so it
answers from *your* facts instead of guessing.
