# Chapter 05 — Let other programs talk to your model

> Matches **Chapter 05** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop · 🌐 Needs the internet

---

## The big idea (in plain words)

So far, your fraud-spotting model only works when *you* run it by hand. But what if another
program — a website, a phone app, a bank's system — wanted to ask it "is this payment fraud?"
It needs a **doorway** to knock on.

Think of a hotel **front desk**. People walk up, ask a question, and the clerk answers. We're
going to build a front desk for your model. Other programs walk up (over the internet), ask a
question, and get an answer back. The fancy name for this front desk is an **API**, and we'll
build it with a small, friendly tool called **Flask**.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **API** — a doorway that lets one program ask another program for something.
- **Endpoint** — one specific door of an API, like `/predict` ("is this fraud?") or `/health`
  ("are you okay?").
- **Flask** — a small Python helper for building the front desk.
- **Request** — a message sent *to* the front desk asking it to do something.
- **Response** — the answer the front desk sends back.
- **JSON** — a simple, tidy text format for sending data between programs.
- **curl** — a command-line tool that lets you knock on an API's door from the terminal.
- **Port** — a numbered "window" on a computer that programs use to talk. We use window `5000`.

## What you will build

A small web service (a "front desk") that other programs can talk to. You'll start it, then
send it a pretend payment and watch it answer **FRAUD** or **LEGIT** — all from your own
laptop.

---

## Let's do it, one small step at a time

> **Heads up: this chapter needs TWO terminals.** One terminal *runs* the front desk and stays
> busy listening. The other terminal *sends* a question to it. If you try to do both in one
> terminal, the second command will look stuck. This is normal — you simply need two windows.

### Step 1 — Get the code and open it

Go into the chapter folder that has the code for this chapter:

```bash
cd chapter-05-api
```

Inside you'll find an `app/` folder with two important files:

- **`model.py`** — the "brain" that learns from pretend payments and guesses fraud or not.
  (This is the same kind of model you met in earlier chapters.)
- **`api.py`** — the **front desk** that listens for questions and asks the brain.

### Step 2 — Make a clean toolbox (virtual environment) and install the helpers

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*) just for
  this project, so its tools don't bump into other projects.
- `source venv/bin/activate` steps *into* that toolbox. (On Windows, type
  `venv\Scripts\activate` instead.)
- `pip install -r requirements.txt` reads the **shopping list** of helpers and installs them:
  `flask` (builds the front desk), `scikit-learn` (builds the brain), plus `pandas` and
  `numpy` (number helpers).

**What you should see:** a list of packages being downloaded, ending with something like
`Successfully installed flask-... scikit-learn-...`.

### Step 3 — Start the front desk (TERMINAL 1)

This is your **first** terminal. It will run the server and keep running.

```bash
cd app && python api.py
```

**What you should see:** a few startup lines, then something like:

```
 * Running on http://0.0.0.0:5000
```

That means the front desk is open and listening at window (**port**) `5000`. **Leave this
terminal alone** — do not close it and do not type in it. It needs to stay busy listening.

**What `api.py` does, in plain words:**

- It turns on a **logbook** (logging) so every question gets written down with the time.
- It builds the Flask front desk and wakes up the brain from `model.py`.
- It sets a **rulebook** that says which clues a payment must include and what kind of number
  each should be.
- `/health` is the door for "Are you okay?" — it answers `healthy`.
- `/info` is the door for "Who are you?" — it gives the API's name and version.
- `/predict` is the real door. It reads the payment you send, checks the rules, asks the brain,
  and hands back the answer plus a short ticket number.
- The last line tells it to stand at the door (`port=5000`) and start listening.

### Step 4 — Open a SECOND terminal

Leave Terminal 1 running. Open a **brand-new** terminal window (in VS Code:
**Terminal → New Terminal**; the old one keeps running in its own tab). This second terminal is
where you'll knock on the door.

### Step 5 — Knock on the easy doors first (TERMINAL 2)

In your **second** terminal, ask the simple questions:

```bash
curl http://localhost:5000/health
curl http://localhost:5000/info
```

- `curl` is a tool that knocks on an API's door from the terminal.
- `http://localhost:5000` means "the front desk on *this* computer, at window 5000."
  (`localhost` always means "this computer.")

**What you should see:** tidy **JSON** answers, something like:

```
{"status":"healthy","ts":"2026-06-16T12:00:00"}
{"name":"Zero2AI Fraud API","version":"1.0.0",...}
```

### Step 6 — Send a payment and get a fraud answer (TERMINAL 2)

Now the real thing. Still in your **second** terminal, send a pretend payment to `/predict`:

```bash
curl -X POST http://localhost:5000/predict \
  -H 'Content-Type: application/json' \
  -d '{"amount":950,"hour":3,"is_weekend":0,"amount_vs_avg":4.7,
       "is_large_txn":1,"is_late_night":1,"merch_txn_ct":2}'
```

**What each part means, in plain words:**

- `-X POST` — "I'm *sending* you some data," not just asking a question.
- `-H 'Content-Type: application/json'` — a note that says "the data I'm sending is in JSON."
- `-d '{...}'` — the actual payment, written as **JSON**. Each clue is a name and a number:
  a big `amount` of 950, at `hour` 3 (3 a.m.), much bigger than usual (`amount_vs_avg` 4.7),
  late at night, and so on. These are exactly the seven clues the brain looks at.

**What you should see:** a JSON answer with a label, something like:

```
{"label":"FRAUD","confidence":0.97,"req_id":"a1b2c3d4",...}
```

🎉 You just let another program (curl) talk to your model over the internet. That same doorway
is how a real website or app would use your fraud detector.

---

## Try it yourself (mini challenges)

- 🔧 **Make it say LEGIT.** Send a different payment: a small `amount` like `20`, at `hour`
  `14` (2 p.m.), `is_late_night` `0`, `is_large_txn` `0`. Watch the label flip to **LEGIT**.
- 🔧 **Break a rule on purpose.** Send a payment with `hour` set to `99`. The front desk should
  refuse it and tell you `hour must be 0-23`. (That's the rulebook protecting your model.)
- 🔧 **Leave out a clue.** Remove `amount` from the JSON and send it. Read how the front desk
  politely lists what's missing instead of crashing.
- 🔧 **Visit `/info` again** after a few `/predict` calls, and peek at **Terminal 1**: every
  request you sent was written in the logbook with its ticket number.

## If something breaks

- **"Address already in use" / "port 5000 in use"** → Something is already using window 5000.
  Stop the old server (go to the terminal running it and press **Ctrl+C**), or close any other
  copy of `api.py` you started, then run Step 3 again.
- **`curl: (7) Failed to connect ... Connection refused`** → The front desk isn't running.
  Check that **Terminal 1** still shows `Running on http://0.0.0.0:5000`. If it stopped or you
  closed it, start it again with Step 3.
- **Your `curl` command looks stuck / nothing happens** → You probably typed `curl` in the
  *same* terminal that's running the server. Open a **second** terminal (Step 4) and run `curl`
  there.
- **`command not found: curl`** → Most Macs and Linux have curl already. On Windows, use
  **PowerShell** (it includes curl), or install Git which also brings it along.
- **`ModuleNotFoundError: No module named 'flask'`** → You skipped the toolbox or the install.
  Run `source venv/bin/activate` then `pip install -r requirements.txt` again (Step 2).

## What you just learned

- An **API** is a front desk that lets other programs talk to your model over the internet.
- **Flask** builds that front desk; each door it answers is an **endpoint** (`/health`,
  `/info`, `/predict`).
- Programs send a **request** and get a **response** back, both written in **JSON**.
- **curl** lets you knock on those doors from the terminal.
- A running server needs **one terminal to itself**; you talk to it from a **second** terminal.
- A good front desk **checks every request** and answers politely even when something's wrong.

## Where to next

➡ [Chapter 06 — Pack your program into a box (Docker)](../chapter-06-docker). You'll wrap this
exact front desk into a "lunchbox" so it runs the same on any computer.
