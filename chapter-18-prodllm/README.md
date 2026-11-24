# Chapter 18 — Run the smart robot for real (Production LLM)

> Matches Chapter 18 in the book.

**Labels:** Needs an account that may cost money · Needs the internet · Capstone chapter

---

> ### Money and secrets: please read this first
>
> Like Chapters 16 and 17, this chapter phones a paid online robot (an LLM). You need an
> **API key**: think of it as a **credit card for a robot service**. Each question costs a
> small amount of money, usually a fraction of a cent. (This whole chapter is *about* keeping
> that cost under control.)
>
> - **Get permission first** if the account isn't yours.
> - **Never paste the key into your code, never commit it to git, and never share it.** Keep it
>   in an **environment variable** (a setting in your terminal), exactly as this chapter shows.
> - **You only need ONE robot company.** The book offers three (Anthropic Claude, OpenAI, Google
>   Gemini). This chapter's code is written for **Anthropic Claude**.
> - **No key? You can still do most of this chapter.** Step 3 tests every guardrail for free,
>   with a pretend robot. Only the "real question" steps need a key.

---

## The platform you are building

You are building a **production GenAI platform**, the kind of system an **LLMOps** team runs.
LLMOps means "operating LLM services": it wraps the robot in the grown-up care a real business
needs: a **cache** so you never pay twice for the same question, **per-user spending limits**,
**retries** when the network hiccups, **guardrails** that stop private data leaking out, and
**metrics and alerts** so you see problems (and big bills) before your customers do.
Every company that puts an AI assistant in front of real users needs this layer, because a
raw LLM call is slow, costs money every time, and can fail. This is the **capstone**: it pulls
together the cluster, Helm, autoscaling, secrets, metrics and alerts from Chapters 10 to 17
into one finished platform. People who build it are called **LLMOps Engineers**,
**AI Platform Engineers**, **AI Engineers** and **ML Engineers**.

## How this builds on Chapter 17

**What carries over:**

- From **Chapter 16**: the same Anthropic Python library, the same `export ANTHROPIC_API_KEY`
  habit, and the same Flask "front desk" pattern with a `/health` door and a ticket number
  (`request_id`) on every answer.
- From **Chapter 17**: you learned to make answers *good* (grounded in your notes). Now you make
  the service *safe, cheap and reliable* for many people at once.
- From **Chapters 11 and 15**: the same Prometheus counters (`Counter`, `Histogram`) on a
  separate metrics door (port 8000) that dashboards and alerts read.
- From **Chapters 10 to 16 (cloud)**: in Phases 2 and 3 this app reuses *everything*: the EKS
  cluster, the shared Helm chart, ECR, the platform load balancer (ALB), the autoscaler (HPA),
  the disruption budget (PDB), the NetworkPolicy, Prometheus scraping (ServiceMonitor), alert
  rules (PrometheusRule), and API keys from AWS Secrets Manager.

**What's new:** a cache, a per-user token budget, a safety filter, automatic retry with
backoff, and LLM-specific metrics (calls by status, tokens in and out, latency). In the cloud:
five alerts made for an LLM service, including a **cost alarm**.

```text
Your platform so far (Chapter 18 = everything joined up)

 user --> ALB (Ch 10) --> prod-llm copies (HPA, PDB, zones: Ch 10)
                            |
                            |  1. safety filter   (new)
                            |  2. token budget    (new)
                            |  3. cache           (new)
                            |  4. retry + backoff (new)
                            v
                       LLM provider (Ch 16) <-- API key from Secrets Manager (Ch 16)
                            |
                     /metrics :8000 --> Prometheus (Ch 11) --> alerts (Ch 11)
                                                        \--> Grafana dashboards (Ch 15)
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **1 — Build it on your laptop** | Your computer | Run the service, test every guardrail, pack it in a container | Free, except each real robot question (a fraction of a cent) |
| **2 — Promote it to the cloud** | AWS EKS | 2A: plain YAML. 2B: the Helm chart, scraped by Prometheus | Money while the cluster runs (about $0.15 to $0.30 an hour for dev) |
| **3 — Run it like a Fortune 500 company** | AWS EKS + ALB | Autoscaling, vault secrets, public address, alerts on errors, latency and spend | Same as Phase 2, a little more for extra copies |

## New words

Look up anything else in the [GLOSSARY](../GLOSSARY.md).

- **Production** — Ready for real, everyday use by many people, not just a demo.
- **LLMOps** — The job of running LLM services well: cost, speed, safety, reliability.
- **Cache** — A small memory box that saves answers, so you don't pay to ask the same thing twice.
- **Token budget** — A per-person spending cap, counted in **tokens** (small word-pieces, the
  unit LLM companies charge by).
- **Guardrail / safety filter** — A rule that blocks risky or private input before it reaches
  the robot.
- **Retry with backoff** — Trying a failed call again after a short wait, and waiting a bit
  longer each time, so you don't hammer a struggling service.
- **Metrics** — Numbers you track over time (calls, tokens, seconds per call). You met these in
  Chapter 11.
- **HTTP status code** — The number a web service sends back with each answer: `200` = OK,
  `422` = "I won't accept that input", `429` = "too much, slow down", `503` = "I couldn't do it
  right now".
- **API key** — A secret password for the paid robot service. Keep it in an environment
  variable, never in your code. (Same as Chapters 16 and 17.)

---

## Phase 1 — Build it on your laptop

You build `production_llm.py`: one web service with an `/llm` door that talks to the robot,
wrapped in all the guardrails above. It also opens a second door on port `8000` (`/metrics`)
where it publishes live counters.

> **Heads up: Steps 5 to 8 need TWO terminals.** One terminal *runs* the service; the other
> *sends* it requests. That's normal.

### Step 1 — Go to the chapter folder

From the top of the course repo:

```bash
cd chapter-18-prodllm
ls
```

**What you should see:** `Dockerfile`, `offline_check.py`, `production_llm.py`,
`requirements.txt` and this `README.md` (plus a `cloud` folder for Phases 2 and 3).

- **`production_llm.py`** — the book's code: the robot, dressed up for the real world.
- **`offline_check.py`** — a free self-test that checks every guardrail with a *pretend*
  robot (no key, no money).
- **`Dockerfile`** — the recipe to pack the service into a container (Step 9).

### Step 2 — Make a clean toolbox and install the helpers

Run from `chapter-18-prodllm`:

```bash
python3 -m venv venv
source venv/bin/activate          # Windows PowerShell: venv\Scripts\Activate.ps1
pip install anthropic flask tenacity prometheus-client
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*) in a
  folder called `venv`.
- `source venv/bin/activate` steps into it. Your prompt now starts with `(venv)`.
- The install brings `anthropic` (to phone the robot), `flask` (the front desk), `tenacity`
  (the retry helper) and `prometheus-client` (the live counters).

**What you should see:** packages downloading, ending with a line that starts
`Successfully installed ...` and lists `anthropic-...`, `flask-...`, `tenacity-...` and
`prometheus_client-...`.

### Step 3 — Prove the guardrails work, for free

Before spending a cent, check every safety net with a pretend robot. Run from
`chapter-18-prodllm`, in the same terminal:

```bash
python offline_check.py
```

**What you should see** (it pauses about 4 seconds in the middle, on purpose, to test the
retry):

```text
[OK]    cache: 1st answer is fresh, 2nd and 3rd come from the memory box
[OK]    safety filter blocks "My SSN: ..." with HTTP 422
[OK]    safety filter blocks "password: ..." (any capital letters)
[OK]    blocked messages were never sent to the robot
[OK]    an empty prompt is refused with HTTP 422
[OK]    alice has been charged 42 tokens
[OK]    a new question is still allowed (42 is under 50)
[OK]    now alice is over her cap: HTTP 429 "Daily token budget exceeded"
[OK]    bob has his own budget, so he is still allowed
        (testing retry: this waits a few seconds on purpose)
[OK]    retry: 2 failures then a success still answers
[OK]    after 3 failed tries the service gives up with HTTP 503
[OK]    metrics count the cache hits

  llm_calls_total{status="success"} 4.0
  llm_calls_total{status="cache_hit"} 2.0
  llm_calls_total{status="blocked"} 2.0
  llm_calls_total{status="budget_exceeded"} 1.0
  llm_calls_total{status="error"} 1.0
  llm_tokens_total{type="input"} 48.0
  llm_tokens_total{type="output"} 120.0

All offline checks passed. No API key was used and nothing was spent.
```

This is how real teams test: they swap the paid service for a pretend one (a **mock**) so
tests are free, fast and always give the same answer.

> No key? You can stop here and read the rest. You have already seen every guardrail work.

### Step 4 — Set your API key

Get a key from [console.anthropic.com](https://console.anthropic.com), then in the terminal
you'll use for the service:

```bash
export ANTHROPIC_API_KEY='paste-your-key-here'     # Windows PowerShell: $env:ANTHROPIC_API_KEY='paste-your-key-here'
```

- This puts your secret password in *this terminal's* settings, so the code never holds it.
  It lasts only for this terminal window: open a new one and you must set it again.
- Check it's set without showing it on screen: `test -n "$ANTHROPIC_API_KEY" && echo key is set`.
- Never put the key in a file you commit. If you ever paste it somewhere public, delete it in
  the console and make a new one.

> **About the model name.** The book's code uses `model='claude-opus-4-7'`. If your account
> reports "model not found", open `production_llm.py` and change that one line to a model your
> account offers (the console's model list shows them; a smaller model such as
> `claude-sonnet-4-6` is cheaper for testing).

### Step 5 — Start the service (TERMINAL 1)

Run from `chapter-18-prodllm`, with the toolbox active and the key set:

```bash
python production_llm.py
```

**What you should see:** a few startup lines, including:

```text
 * Serving Flask app 'production_llm'
 * Running on http://127.0.0.1:5000
```

(Flask also prints a red "WARNING: This is a development server". That's fine on a laptop;
Phase 3 explains what production uses.) The service now listens for questions on **port
5000** and publishes counters on **port 8000**. **Leave this terminal running.** Don't close it
or type in it.

**What `production_llm.py` sets up, in plain words:**

```python
CACHE = {}
USER_BUDGETS = {}
DAILY_TOKEN_LIMIT = 50000
BLOCKED_PATTERNS = ['ssn:', 'credit card:', 'password:', 'api key:']
```

- `CACHE` — the memory box for questions already answered.
- `USER_BUDGETS` and `DAILY_TOKEN_LIMIT = 50000` — each person gets 50,000 tokens before being
  politely cut off.
- `BLOCKED_PATTERNS` — the words the safety filter refuses to send to the robot.

```python
@retry(stop=stop_after_attempt(3),
       wait=wait_exponential(multiplier=1, min=2, max=30))
def call_anthropic(prompt):
    return client.messages.create(model='claude-opus-4-7', max_tokens=512, ...)
```

- `@retry(...)` — if the call fails, try again, up to 3 tries in total, waiting longer each
  time (**backoff**): at least 2 seconds, at most 30.
- `max_tokens=512` — the longest answer the robot may write. This also caps the cost of one call.

And the `/llm` door itself, in plain words:

```python
if not prompt: ...                       # 1. is there a real question?          -> 422
if not is_safe_input(prompt): ...        # 2. safety filter                      -> 422
if used >= DAILY_TOKEN_LIMIT: ...        # 3. budget check                       -> 429
if key in CACHE: ...                     # 4. already answered? hand back the saved one
msg = call_anthropic(prompt)             # 5. otherwise phone the robot (with retry) -> 503 if it fails
CACHE[key] = {...}                       # 6. save the answer for next time
USER_BUDGETS[user_id] = used + in_t + out_t   # 7. charge the tokens to that user
```

- The checks run **in order**, cheapest first. Each one saves money or keeps things safe
  *before* the expensive robot call.
- `rid = str(uuid.uuid4())[:8]` gives each request a **ticket number** that appears in the
  answer and in Terminal 1's log, so you can match a user's complaint to a log line.

### Step 6 — Test the cache: ask the same thing three times (TERMINAL 2)

Open a **second** terminal. You don't need the toolbox or the key in this one. Run:

```bash
for i in 1 2 3; do
  curl -s -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
    -d '{"user_id":"alice","prompt":"What is RAG?"}'; echo
done
```

**What you should see:** three JSON answers with the same `answer` text. The **first** says
`"cached":false` (it really phoned the robot, after a few seconds). The **next two** come back
instantly with `"cached":true`: they came free from the memory box. Each one has its own
`request_id`. In Terminal 1 you see `Success: <in>/<out> tokens` once, then `Cache hit` twice.

### Step 7 — Test the safety filter (TERMINAL 2)

```bash
curl -s -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
  -d '{"user_id":"alice","prompt":"My SSN: 123-45-6789"}'; echo
```

**What you should see:**

```text
{"error":"Input rejected by safety filter","request_id":"a1b2c3d4"}
```

(Your `request_id` will be different.) The private number was **never sent to the robot**.
Terminal 1 logs `Blocked input`.

### Step 8 — Look at the live counters (TERMINAL 2)

```bash
curl -s http://localhost:8000/metrics | grep -E '^llm_(calls|tokens)_total'
```

**What you should see** (your token numbers will differ):

```text
llm_calls_total{status="success"} 1.0
llm_calls_total{status="cache_hit"} 2.0
llm_calls_total{status="blocked"} 1.0
llm_tokens_total{type="input"} 11.0
llm_tokens_total{type="output"} 320.0
```

- `llm_calls_total{status="..."}` — how many calls of each kind: a real `success`, a free
  `cache_hit`, `blocked` by the filter, and later `budget_exceeded` or `error`.
- `llm_tokens_total{type="..."}` — total tokens in and out. Tokens are money, so this is your
  live **cost meter**.
- Try `curl -s http://localhost:8000/metrics | grep llm_` to see everything, including the
  `llm_latency_seconds` histogram (how long robot calls take). Phase 3 turns these numbers
  into alerts.

When you're done, go to Terminal 1 and press **Ctrl+C** to stop the service.

### Step 9 — Pack it in a container

In Phase 2 the cloud runs your service from a container image, so build and test that image
on your laptop first. Make sure Docker Desktop (or Docker Engine) is running, and that the
service from Step 5 is stopped (the container needs ports 5000 and 8000).

Run from `chapter-18-prodllm`:

```bash
docker build -t zero2ai-prodllm .
```

**What you should see:** Docker works through the steps in the `Dockerfile` (install the
helpers, copy `production_llm.py`, switch to a normal user) and ends with a line like
`naming to docker.io/library/zero2ai-prodllm:latest`. The first build takes a minute or two.

Now run it (TERMINAL 1). `-e ANTHROPIC_API_KEY` with no `=value` copies the key from your
terminal into the container, so the key never appears in the command or your shell history:

```bash
docker run --rm --name prodllm -p 5000:5000 -p 8000:8000 -e ANTHROPIC_API_KEY zero2ai-prodllm
```

**What you should see:** the same startup lines as Step 5, ending with
`Running on http://127.0.0.1:5000` and `Press CTRL+C to quit`.

Check it from TERMINAL 2:

```bash
curl -s http://localhost:5000/health; echo
curl -s -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
  -d '{"user_id":"alice","prompt":"My SSN: 123-45-6789"}'; echo
curl -s -X POST http://localhost:5000/llm -H 'Content-Type: application/json' \
  -d '{"user_id":"alice","prompt":"In one sentence, what is KYC?"}'; echo
curl -s http://localhost:8000/metrics | grep -E '^llm_(calls|tokens)_total'
docker exec prodllm id
```

**What you should see:**

1. `{"status":"healthy"}`
2. `{"error":"Input rejected by safety filter","request_id":"..."}`
3. A one-sentence answer with `"cached":false` (this one costs a fraction of a cent)
4. Counter lines including `llm_calls_total{status="blocked"} 1.0` and
   `llm_calls_total{status="success"} 1.0`
5. `uid=1000(appuser) ...`: the container runs as a normal user, not the all-powerful `root`
   user. Production clusters insist on that.

Press **Ctrl+C** in Terminal 1 to stop the container (`--rm` deletes it).

### Try it yourself

- **Hit the budget cap.** In `production_llm.py` change `DAILY_TOKEN_LIMIT = 50000` to `50`.
  Restart Terminal 1 (Ctrl+C, then `python production_llm.py`) and send two *different*
  questions as `alice`. The first is answered (the check happens *before* the call, so one
  call may go over); the second gets `{"error":"Daily token budget exceeded",...}` with HTTP 429.
- **Each person has their own budget.** Now send a question as `"user_id":"bob"`. Bob is still
  allowed.
- **Add your own blocked words.** Add `'secret code:'` to `BLOCKED_PATTERNS`, restart, and send
  `"prompt":"My secret code: 1234"`. The safety filter refuses it.
- **Prove the cache saves money.** Ask one question twice and compare the
  `llm_tokens_total` lines before and after the second ask. They don't move: a cache hit costs
  zero tokens.
- **Find the weak spot.** Send `"prompt":"my ssn is 123-45-6789"` (no colon). It gets through!
  Simple word lists are a first line of defense, not the last. Phase 3 explains what companies
  add on top.
- Put the numbers back (`50000`, original list) when you're done.

### If something breaks

- **`KeyError: 'ANTHROPIC_API_KEY'`** when starting the service or the container → The key
  isn't set in *this* terminal. Redo Step 4, then start again. The service reads the key when it
  starts, so set it first.
- **`{"error":"LLM call failed",...}` after about 4 seconds** → The service tried 3 times and
  gave up. Look in Terminal 1 just above the `Failed:` line:
  - `401 Unauthorized` or `AuthenticationError` → the key is wrong, mistyped or deleted. Make a
    fresh key, `export` it again, restart the service.
  - `404 Not Found` or `NotFoundError` → the model name isn't available to your account. See
    "About the model name" in Step 4.
  - `429 Too Many Requests` or `RateLimitError` → you sent too much too fast, or hit a free-tier
    or spending limit. Wait a minute; check your plan's limits and credit in the console.
  - `400` with "credit balance is too low" → add credit in the console's billing page.
  - `Connection error` / `APIConnectionError` → no internet, or a firewall blocks
    `api.anthropic.com`. Check you're online.
- **`{"error":"Daily token budget exceeded",...}`** → That `user_id` used its allowance. Use a
  different `user_id`, or restart the service (budgets live in memory and reset on restart).
- **`{"error":"Missing prompt",...}`** → Your JSON didn't have a `"prompt"`, or the quotes got
  mangled. Copy the `curl` command exactly; on Windows use Git Bash or WSL for these commands.
- **`curl: (7) Failed to connect` / "Connection refused"** → The service isn't running. Check
  Terminal 1 still shows `Running on ...:5000` and use the *second* terminal for `curl`.
- **`Address already in use` / "Port 5000 is in use"** → Something else has the port. On a Mac,
  the AirPlay Receiver uses port 5000: turn it off in System Settings → General → AirDrop &
  Handoff, or stop the other program. For Step 9 you can map a different laptop port instead:
  `-p 5050:5000`, then use `http://localhost:5050`. Also make sure the Step 5 service and the
  Step 9 container aren't both running.
- **`OSError: [Errno 48] Address already in use` when running `offline_check.py`** → The service
  from Step 5 is still running and holding port 8000. Stop it with Ctrl+C first.
- **`ModuleNotFoundError: No module named 'flask'`** (or `anthropic`) → The toolbox isn't active
  in this terminal. Run `source venv/bin/activate` again.
- **`Cannot connect to the Docker daemon`** → Start Docker Desktop and wait for "Engine running".

### What you learned in Phase 1

- **Production** means getting the robot ready for real, everyday use by many people.
- A **cache** saves answers so you don't pay twice for the same question.
- A per-user **token budget** caps spending so costs can't run wild.
- A **safety filter** blocks private details before they ever reach the robot, and simple word
  lists have gaps.
- **Retry with backoff** keeps the service working through short network hiccups.
- **Logging** with ticket numbers and **metrics** (live counters) let you watch the service, and
  tokens are your cost meter.
- A **mock** lets you test all of this for free, and a **container** makes it ready for the
  cloud.

---

## Phase 2 and Phase 3

- **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md). The same container
  on AWS EKS, first with plain YAML, then with the shared Helm chart and Prometheus scraping.
- **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md).
  Autoscaling, vault secrets, a public address, and alerts on errors, latency and spend.

Build the shared platform first: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
It costs money while it runs, so destroy it when you finish.

## Where to next

You've finished all 18 chapters. Congratulations! Look back at the
[course index](../README.md) to see the whole platform you built, one chapter at a time.

**What to build next:**

- **Join Chapters 17 and 18.** Put the RAG pipeline from
  [Chapter 17](../chapter-17-rag/README.md) behind this chapter's guardrails: cache, budget,
  safety filter, metrics. That is an enterprise knowledge assistant with LLMOps built in.
- **Share the memory.** Move `CACHE` and `USER_BUDGETS` into Redis so every copy in the cloud
  shares them (see "Honest limits" in [cloud/PRODUCTION.md](cloud/PRODUCTION.md)).
- **Add a second provider.** Use the OpenAI or Gemini code from
  [Chapter 16](../chapter-16-llm/README.md) as a fallback when Anthropic is down.

**Show it in your portfolio:**

- Push your copy of the repo to GitHub (without keys: check with `git status` that no `.env`
  file or key is included).
- Write a short README of your own with the "Your platform so far" diagram, a screenshot of
  `offline_check.py` passing, the metrics output, and the Phase 3 `test.sh 3` output.
- Be ready to explain *why* each guardrail exists and what it costs or saves. The interview
  questions in [cloud/PRODUCTION.md](cloud/PRODUCTION.md) are a good rehearsal.
