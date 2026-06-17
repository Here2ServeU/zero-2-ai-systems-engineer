# Chapter 18 — Run the smart robot for real (Production LLM)

> Matches **Chapter 18** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

> ### ⚠️ Money & secrets — please read this first
>
> Like Chapters 16 and 17, this chapter phones a paid online robot. You need an **API key** —
> think of it as a **credit card for a robot service**. Each call can cost a small amount of
> money. (This whole chapter is *about* keeping that cost under control.)
>
> - **Get permission first** if the account isn't yours.
> - **Never paste the key into your code, and never share it.** Keep it in an **environment
>   variable** (your computer's settings), as this chapter shows.
> - **You only need ONE robot company.** The book offers three (Anthropic Claude, OpenAI,
>   Google Gemini). This chapter's code is written for **Anthropic Claude**, but **Google Gemini
>   has a free tier** that's the cheapest way to start if you adapt the call.
> - **No key? No problem.** It is completely fine to *read* this chapter to understand how a
>   real-world robot service is built, even if you never run it.

---

## The big idea (in plain words)

In Chapter 16 you phoned the robot. In Chapter 17 you handed it your notes. But letting *real
people* use a robot service all day is a different job — like the difference between cooking for
yourself and running a restaurant. A restaurant needs limits, records, safety checks, and a plan
for when something goes wrong.

This chapter does all that **grown-up care** so the pen pal can serve real people reliably:

- **A memory box (cache).** If someone asks the *same* question twice, hand back the saved answer
  instead of paying to ask the robot again.
- **A spending cap (budget) per person.** Once someone uses up their daily allowance of
  word-pieces, they're politely cut off so costs don't run wild.
- **A safety filter (guardrail).** Block messages that contain private secrets (like a Social
  Security number) so they never get sent to the robot.
- **Retry when the network hiccups.** If a call fails, wait a moment and try again, a few times,
  waiting a little longer each time.
- **Logging and metrics.** Keep a logbook (with ticket numbers) and live counters so you can
  watch how the service is doing.

The fancy word for "ready for real, everyday use by many people" is **production**.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **API key** — a secret password for the paid robot service. Keep it in your computer's
  settings, never in your code. (Same as Chapters 16–17.)
- **Cache** — a small memory box that saves answers so you don't pay to ask the same thing twice.
- **Token budget** — a per-person spending cap, measured in **tokens** (small word-pieces).
- **Safety filter / guardrail** — a rule that blocks risky or private input before it reaches the
  robot.
- **Retry / backoff** — trying a failed call again after a short wait, waiting a bit longer each
  time.
- **Metrics** — numbers you track over time (calls, tokens, how long each call takes). You met
  these in the monitoring chapters.

## What you will build

`production_llm.py` — one web service with an `/llm` door that talks to the robot, wrapped in all
the guardrails above. It also opens a second door (`/metrics`) where live counters are published.

---

## Let's do it, one small step at a time

> **Heads up: this needs TWO terminals.** One *runs* the service; the other *sends* it requests.

### Step 1 — Get the code and open it

```bash
cd chapter-18-prodllm
```

Inside is one file: **`production_llm.py`** — the robot, all dressed up for the real world.

### Step 2 — Make a clean toolbox and install the helpers

```bash
python3 -m venv venv && source venv/bin/activate
pip install anthropic flask tenacity prometheus-client
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*).
- `source venv/bin/activate` steps into it. (Windows: `venv\Scripts\activate`.)
- The install brings: `anthropic` (to phone the robot), `flask` (the front desk), `tenacity` (the
  retry helper), and `prometheus-client` (the live counters / **metrics**).

**What you should see:** packages downloading, ending with `Successfully installed anthropic-...`.

### Step 3 — Set your API key

```bash
export ANTHROPIC_API_KEY='your-key-here'    # PowerShell: $env:ANTHROPIC_API_KEY='your-key-here'
```

- Puts your secret password in *this terminal's* settings, so the code never holds it. It only
  lasts for this terminal window — open a new one and you must set it again.
- Get a key from [console.anthropic.com](https://console.anthropic.com).

> **Set the model to one that exists.** `production_llm.py` says `model='claude-opus-4-7'`, which
> is **just an example**. Change it to a real model for your account, like `claude-opus-4-8`
> (smartest) or `claude-sonnet-4-6` (fast, cheaper).

### Step 4 — Start the service (TERMINAL 1)

```bash
python production_llm.py
```

**What you should see:** startup lines, then something like:

```
 * Running on http://0.0.0.0:5000
```

The service now listens for questions at window (**port**) `5000`, and publishes its live
counters at port `8000`. **Leave this terminal running** — don't close it or type in it.

**What `production_llm.py` sets up, in plain words:**

```python
CACHE = {}
USER_BUDGETS = {}
DAILY_TOKEN_LIMIT = 50000
BLOCKED_PATTERNS = ['ssn:', 'credit card:', 'password:', 'api key:']
```

- `CACHE` — the memory box for already-answered questions.
- `USER_BUDGETS` and `DAILY_TOKEN_LIMIT = 50000` — each person gets about 50,000 word-pieces per
  day before being politely cut off.
- `BLOCKED_PATTERNS` — the list of risky things the safety filter refuses to send to the robot.

```python
@retry(stop=stop_after_attempt(3),
       wait=wait_exponential(multiplier=1, min=2, max=30))
def call_anthropic(prompt):
    return client.messages.create(model='claude-opus-4-7', max_tokens=512,
        messages=[{'role':'user','content':prompt}])
```

- `@retry(stop=stop_after_attempt(3), ...)` — if the call fails, try again, up to 3 times,
  waiting a little longer each time (**backoff**) so it doesn't hammer the robot.
- `model='claude-opus-4-7'` — **swap for a real model** (Step 3).

And the door itself, in plain words:

```python
@app.route('/llm', methods=['POST'])
def llm():
    rid = str(uuid.uuid4())[:8]
    ...
    if not prompt: ...                       # 1. is there a real question?
    if not is_safe_input(prompt): ...        # 2. safety filter
    if used >= DAILY_TOKEN_LIMIT: ...        # 3. budget check
    if key in CACHE: ...                     # 4. already answered? hand back the saved one
    msg = call_anthropic(prompt)             # 5. otherwise, phone the robot (with retry)
    ...
    CACHE[key] = {...}                        # 6. save the answer for next time
    USER_BUDGETS[user_id] = used + in_t + out_t   # 7. charge the tokens to the user
```

- `rid = str(uuid.uuid4())[:8]` — a **ticket number** for the logbook.
- The checks run *in order*: empty question → safety filter → budget → cache → robot. Each guard
  saves money or keeps things safe.
- After a real call, it saves the answer in the cache and adds the tokens to that user's daily
  total.

### Step 5 — Test the cache: ask the same thing three times (TERMINAL 2)

Open a **second** terminal and run:

```bash
for i in 1 2 3; do
  curl -s -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
    -d '{"user_id":"alice","prompt":"What is RAG?"}'; echo
done
```

**What you should see:** three JSON answers. The **first** says `"cached":false` (it really
phoned the robot). The **next two** say `"cached":true` — they came free from the memory box. The
answer text is the same all three times.

### Step 6 — Test the safety filter (TERMINAL 2)

```bash
curl -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
  -d '{"user_id":"alice","prompt":"My SSN: 123-45-6789"}'
```

**What you should see:** a refusal, because the message contains `ssn:` — something like:

```
{"error":"Input rejected by safety filter","request_id":"a1b2c3d4"}
```

The private secret was **never sent to the robot**. That's the guardrail doing its job.

### Step 7 — Look at the live counters (TERMINAL 2)

```bash
curl http://localhost:8000/metrics | grep llm_
```

**What you should see:** lines of numbers the service is keeping, something like:

```
llm_calls_total{status="success"} 1.0
llm_calls_total{status="cache_hit"} 2.0
llm_calls_total{status="blocked"} 1.0
llm_tokens_total{type="input"} 14.0
```

- `llm_calls_total{status="..."}` — how many calls of each kind (real success, cache hit,
  blocked, and so on).
- `llm_tokens_total{type="..."}` — total word-pieces in and out.
- These are the same kind of **metrics** a dashboard (Grafana) would chart.

🎉 You just ran the robot the way a real product does: it won't leak secrets, won't overspend,
won't pay twice for the same question, and keeps trying when the network hiccups.

---

## Try it yourself (mini challenges)

- 🔧 **Lower the budget and hit the cap.** Change `DAILY_TOKEN_LIMIT = 50000` to a tiny number
  like `50`, restart Terminal 1, and send a couple of *different* questions for the same
  `user_id`. After the first, you should get `Daily token budget exceeded`.
- 🔧 **Add your own blocked word.** Add `'secret code:'` to `BLOCKED_PATTERNS`, restart, and send
  a prompt containing it. The safety filter should refuse it.
- 🔧 **Prove the cache saves money.** Ask one question, note its token counts in Terminal 1's
  logbook, then ask the *exact same* question again. The second time the service shouldn't phone
  the robot at all — watch the metrics' `cache_hit` count go up.
- 🔧 **Switch users.** Send the same big question as `"user_id":"bob"` after `alice` hit her cap.
  Notice each person has their *own* separate budget.

## If something breaks

- **`KeyError: 'ANTHROPIC_API_KEY'`** → The key isn't set in this terminal. Redo Step 3's
  `export`. It only lasts for the current terminal window.
- **An "authentication" / "invalid API key" / 401 error** → The key is wrong or mistyped. Create
  a fresh key and `export` it again.
- **A "model not found" error** → You're using the example name `claude-opus-4-7`. Change `model`
  in `production_llm.py` to a real one like `claude-opus-4-8` or `claude-sonnet-4-6`.
- **`{"error":"LLM call failed"}` after a pause** → The service tried 3 times and gave up,
  usually because there's no **internet** or the robot is briefly unavailable. Check you're
  online and try again.
- **A "rate limit" / 429 error from the robot** → You called too fast or hit a free-tier cap.
  Wait a minute. (The built-in retry already helps with short hiccups.)
- **`curl` looks stuck / "Connection refused"** → The service isn't running, or you typed `curl`
  in the same terminal as the server. Make sure Terminal 1 shows `Running on ...:5000`, and use a
  *second* terminal for `curl`.

## What you just learned

- **Production** means getting the robot ready for real, everyday use by many people.
- A **cache** saves answers so you don't pay twice for the same question.
- A per-user **token budget** caps spending so costs can't run wild.
- A **safety filter** blocks private secrets before they ever reach the robot.
- **Retry with backoff** keeps the service working through network hiccups.
- **Logging** (ticket numbers) and **metrics** (live counters) let you watch the service's
  health.

## Where to next

You've finished all 18 chapters — congratulations! 🎉 Head back to the
[book index](../README.md) to see the whole journey you completed.

Your next big challenge is the **graduation projects** described there: **NexaGuard** (a full
system for catching bank fraud) and **ClarityAI** (helping in healthcare). They are advanced and
bring together everything from these chapters — come back to them whenever you feel ready. You've
built every piece you need to start.
