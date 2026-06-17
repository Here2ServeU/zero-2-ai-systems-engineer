# Chapter 16 — Talk to a smart writing robot (LLM)

> Matches **Chapter 16** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

> ### ⚠️ Money & secrets — please read this first
>
> This chapter talks to a paid online robot service. To use it you need an **API key** — think
> of an API key as a **credit card for a robot service**. Each time your program phones the
> robot, it can cost a small amount of money (usually a fraction of a cent for these tiny
> tests, but it is not free).
>
> - **Get permission first** if the account isn't yours. Ask the person who owns it before you
>   run anything that spends money.
> - **Never paste the key directly into your code, and never share it.** Anyone with your key
>   can spend your money. Keep it in an **environment variable** (your computer's settings),
>   exactly as this chapter shows.
> - **You only need ONE robot company.** The book offers three (Anthropic Claude, OpenAI,
>   Google Gemini). Pick whichever you can sign up for. **Google Gemini has a free tier**, which
>   is the cheapest, friendliest way to start.
> - **No key? No problem.** It is completely fine to *read* this whole chapter to understand how
>   it works, even if you never run it. You lose nothing by reading.

---

## The big idea (in plain words)

Imagine a **pen pal** who has read almost every book and article in the world. You can phone
this pen pal over the internet, ask any question in plain words, and they write you back a
helpful answer in plain words. That pen pal is an **LLM** (Large Language Model) — a very
well-read robot that *reads and writes words*. Famous ones are named **Claude**, **GPT**, and
**Gemini**.

In this chapter you'll do two things:

1. Make the **simplest possible phone call** to the robot to prove your secret password (your
   **API key**) works.
2. Build a tiny **front desk** (a web door called `/chat`) so other programs can send a banking
   question and get the robot's answer back.

Small on purpose. By the end you'll have phoned a real LLM and built a little service around it.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **LLM (Large Language Model)** — a super-smart pen pal: software that reads and writes text
  and answers questions. Claude, GPT, and Gemini are examples.
- **Prompt** — the question or instructions you send to the robot.
- **System prompt** — a standing instruction the robot *always* follows, like "you are a polite
  bank helper."
- **Token** — a small piece of a word. The robot measures its work (and its cost) in tokens.
- **API key** — a secret password that lets your program use the paid robot service. Keep it in
  your computer's settings, never in your code.

## What you will build

- `verify_api.py` — the "is the phone working?" test: the simplest call that proves your API
  key works and the robot answers.
- `llm_api.py` — a small web service with a `/chat` door. Other programs knock, hand over a
  banking question, and get the robot's answer back (with a ticket number and a count of how
  many tokens were used).

---

## Let's do it, one small step at a time

> **Heads up: the front desk part needs TWO terminals.** One terminal *runs* the front desk and
> stays busy listening. The other terminal *sends* it a question. This is normal — you just need
> two windows.

### Step 1 — Get the code and open it

Go into the chapter folder that holds the code for this chapter:

```bash
cd chapter-16-llm
```

Inside you'll find several files. The two we use first are:

- **`verify_api.py`** — the simplest test call.
- **`llm_api.py`** — the `/chat` front desk.

> The folder also has `..._openai.py` and `..._gemini.py` twins. Those are the *same* scripts
> for the other two robot companies. **Ignore the ones you don't need** — pick one company and
> use just its pair of files.

### Step 2 — Make a clean toolbox (virtual environment) and install the helpers

```bash
python3 -m venv venv && source venv/bin/activate
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*) just for
  this project, so its tools don't bump into other projects.
- `source venv/bin/activate` steps *into* that toolbox. (On Windows, type
  `venv\Scripts\activate` instead.)

Now install the helpers for **the one company you picked**:

```bash
# Option A — Anthropic (Claude), the book's default:
pip install anthropic flask python-dotenv

# Option B — OpenAI (GPT):
pip install openai flask

# Option C — Google (Gemini), has a free tier — cheapest to start:
pip install google-genai flask
```

**What you should see:** a list of packages downloading, ending with something like
`Successfully installed anthropic-... flask-...`.

### Step 3 — Get a key and set it as an environment variable

First, sign up and create a key at the page for your chosen company:

- **Anthropic:** [console.anthropic.com](https://console.anthropic.com)
- **OpenAI:** [platform.openai.com](https://platform.openai.com)
- **Google Gemini:** [aistudio.google.com](https://aistudio.google.com)

Then tell *this terminal* about your key. Each company uses a differently-named slot:

```bash
# Mac / Linux (pick the line for your company):
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

- `export NAME='value'` puts your secret password into a labeled slot in this terminal's
  settings. The code reads it from there, so the key never sits inside your files.
- **This only lasts for the current terminal window.** If you open a new terminal, you must set
  it again. (That's a common stumble — see "If something breaks.")

> **Important — set the model name to one that exists.** The book's example scripts say
> `model='claude-opus-4-7'`. That id is **just an example**. Open your verify script and the
> api script and set `model` to a model that exists for *your* account:
> - **Anthropic:** `claude-opus-4-8` (smartest) or `claude-sonnet-4-6` (fast, cheaper)
> - **Gemini:** `gemini-2.5-flash` (fast, cheapest)
> - **OpenAI:** `gpt-4o-mini` (fast, cheaper)

### Step 4 — Run the "is the phone working?" test

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

**What `verify_api.py` does, line by line in plain words:**

```python
import anthropic, os

client = anthropic.Anthropic(
    api_key=os.environ['ANTHROPIC_API_KEY'])
```

- `import anthropic, os` — bring in the helper that knows how to phone the robot, plus `os`
  which lets us read your computer's settings.
- `os.environ['ANTHROPIC_API_KEY']` — read your secret password from the slot you set in
  Step 3. (Notice: the password is *never typed into the file*.)
- `anthropic.Anthropic(api_key=...)` — pick up the phone, using that password to prove it's you.

```python
msg = client.messages.create(
    model='claude-opus-4-7',
    max_tokens=200,
    messages=[
        {'role':'user',
         'content':'Say hello in one sentence.'}
    ])
```

- `model='claude-opus-4-7'` — the robot's name tag. **Change this to a real model** (see
  Step 3), like `claude-opus-4-8`.
- `max_tokens=200` — a size limit: "don't write back more than about 200 little word-pieces."
- `messages=[{'role':'user','content':'Say hello in one sentence.'}]` — your **prompt**: the
  thing you're asking the robot to do.

```python
print(msg.content[0].text)
print('Input tokens:', msg.usage.input_tokens)
print('Output tokens:', msg.usage.output_tokens)
```

- `msg.content[0].text` — the robot's written answer.
- `input_tokens` / `output_tokens` — how many word-pieces went *in* and came *out*. This is how
  you see how much the call "cost."

### Step 5 — Start the front desk (TERMINAL 1)

This terminal will run the `/chat` server and keep running. Leave it alone after you start it.

```bash
python llm_api.py             # Anthropic
# python llm_api_openai.py    # OpenAI
# python llm_api_gemini.py    # Gemini
```

**What you should see:** a couple of startup lines, then something like:

```
 * Running on http://0.0.0.0:5000
```

That means the front desk is open and listening at window (**port**) `5000`. **Don't close or
type in this terminal** — it needs to stay busy listening.

**What `llm_api.py` does, in plain words:**

- It starts a **Flask** web server (a front desk that listens for visitors knocking).
- It opens the phone line to the robot using your **API key**, just like the test did.
- It sets a **system prompt** — a standing rule the robot always follows. Here it says: *"You
  are a helpful customer support agent for Zero2AI Bank. Answer in two short paragraphs. If the
  question isn't about banking, politely decline."*

Here is the heart of it, in plain words:

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
- `rid = str(uuid.uuid4())[:8]` — give this visit a short **ticket number** so it can be tracked
  in the logbook.
- `question = data.get('question','').strip()` — read the question the visitor sent.
- `if not question: ...` — if no question was sent, politely send back an error instead of
  bothering (and paying) the robot.

```python
    msg = client.messages.create(
        model='claude-opus-4-7',
        max_tokens=512,
        system=SYSTEM_PROMPT,
        messages=[{'role':'user','content':question}])
    answer = msg.content[0].text
```

- It phones the robot with the **system prompt** plus the visitor's **question**.
- `model='claude-opus-4-7'` — again, **swap for a real model** (Step 3).
- `max_tokens=512` — lets the answer be a bit longer than the test.
- Then it sends the answer back to the visitor along with the ticket number, the time, and the
  token counts.

### Step 6 — Knock on the door (TERMINAL 2)

Leave Terminal 1 running. Open a **brand-new** terminal (in VS Code: **Terminal → New
Terminal**). In this second terminal, send a banking question:

```bash
curl -X POST http://localhost:5000/chat \
  -H 'Content-Type: application/json' \
  -d '{"question":"How do I reset my pin?"}'
```

**What each part means, in plain words:**

- `curl` — a tool that knocks on a web door from the terminal.
- `-X POST` — "I'm *sending* you some data," not just asking.
- `-H 'Content-Type: application/json'` — a note saying "the data I'm sending is in **JSON**."
- `-d '{"question":"How do I reset my pin?"}'` — the actual question, written as JSON.

**What you should see:** a tidy JSON answer written by the robot, something like:

```
{"answer":"To reset your PIN, log in to ... ","tokens_in":48,"tokens_out":96,
 "request_id":"a1b2c3d4","ts":"2026-06-16T12:00:00"}
```

🎉 You just phoned a real smart writing robot and built a little front desk around it — the same
shape real apps use to put an LLM behind a website door.

---

## Try it yourself (mini challenges)

- 🔧 **Change the system prompt.** In `llm_api.py`, edit `SYSTEM_PROMPT` to make the robot a
  helper for a *library* instead of a bank ("You are a friendly library assistant..."). Restart
  Terminal 1 and ask it about borrowing books.
- 🔧 **Ask a non-banking question and watch it refuse.** With the original bank prompt, send
  `{"question":"What's a good recipe for soup?"}`. The robot should *politely decline* because
  the system prompt told it to stay on banking topics. That's the system prompt doing its job.
- 🔧 **Shrink the answer.** Lower `max_tokens` from `512` to `60` and ask again. Notice the
  answer gets cut shorter — and the output token count drops.
- 🔧 **Read the logbook.** After a few questions, peek at **Terminal 1**: each call wrote a line
  with its ticket number and how many tokens went in and out.

## If something breaks

- **`KeyError: 'ANTHROPIC_API_KEY'`** (or `OPENAI_API_KEY` / `GEMINI_API_KEY`) → The key isn't
  set *in this terminal*. Redo Step 3's `export` line. Remember: it only lasts for the current
  terminal window, so if you opened a new one, set it again.
- **An "authentication" / "invalid API key" / 401 error** → The key is wrong, has a typo, or was
  copied with extra spaces. Create a fresh key from your company's website and `export` it again.
- **A "model not found" error** → You're using the example name `claude-opus-4-7`. Change `model`
  to a real one for your account (Step 3), like `claude-opus-4-8`, `gemini-2.5-flash`, or
  `gpt-4o-mini`.
- **`Connection error` / a long hang / timeout** → You need the **internet** for this chapter.
  Check you're online, then try again.
- **A "rate limit" / 429 error** → You asked too fast, or a free account hit its cap. Wait a
  minute and try again, or send fewer requests.
- **`curl` looks stuck / "Connection refused"** → The front desk isn't running, or you typed
  `curl` in the *same* terminal as the server. Make sure Terminal 1 still shows
  `Running on http://0.0.0.0:5000`, and run `curl` in a *second* terminal.

## What you just learned

- An **LLM** is a very well-read robot you phone over the internet to read and write words.
- An **API key** is a secret password (a credit card for the robot) — kept in an environment
  variable, never in your code or shared.
- A **prompt** is what you ask; a **system prompt** is a standing rule the robot always follows.
- The robot measures its work in **tokens**, and you can watch how many each call uses.
- You can put an LLM behind a **Flask** front desk (`/chat`) so other programs can use it.

## Where to next

➡ [Chapter 17 — Give the robot your own notes to read (RAG)](../chapter-17-rag). Right now the
robot answers from everything it ever read. Next you'll hand it *your own* notes so it answers
from *your* facts instead of guessing.
