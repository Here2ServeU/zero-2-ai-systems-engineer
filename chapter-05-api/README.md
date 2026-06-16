# Chapter 05 — Serving Models via APIs

**Book:** Chapter 5 (Serving Models Through APIs) · Lab 5.3
**Layer:** 3 · APIs & Containers · **You build:** Production Flask API

## What you build

A production-grade fraud API applying the four principles: validate every input,
return structured responses, handle errors gracefully, log everything. Model logic
(`app/model.py`) is kept separate from API logic (`app/api.py`).

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

cd app && python api.py        # Terminal 1
```

Test (Terminal 2):

```bash
curl http://localhost:5000/health
curl http://localhost:5000/info
curl -X POST http://localhost:5000/predict \
  -H 'Content-Type: application/json' \
  -d '{"amount":950,"hour":3,"is_weekend":0,"amount_vs_avg":4.7,
       "is_large_txn":1,"is_late_night":1,"merch_txn_ct":2}'
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we build an **API** — a waiter who takes your order (a request) and brings back
food (an answer). We build the waiter with **Flask**, a tool that builds waiters. The
waiter answers a few specific questions called **endpoints** — like `/health` ("Are you
okay?"), `/info` ("Who are you?"), and `/predict` ("Is this transaction fraud?").

### `model.py` — the brain that decides fraud or not fraud

**In one sentence:** This file builds and trains the smart guesser, then knows how to ask
it about one transaction at a time.

**What it does, step by step:**

1. It gives the model a name tag, `v1.0.0`, so we always know which version we are using.
2. It writes down the seven clues the model looks at. These are stored in a list called
   `FEATURES`: `amount`, `hour`, `is_weekend`, `amount_vs_avg`, `is_large_txn`,
   `is_late_night`, and `merch_txn_ct`.
3. In `load_model`, it makes up 2,000 pretend transactions to practice on. (It uses a
   fixed "seed" number so the pretend data is the same every time — like shuffling a deck
   the exact same way each game.)
4. It splits those pretend transactions into a big study pile and a small test pile.
5. It builds a decision tree (a guesser that asks yes/no questions) and lets it study the
   big pile.
6. It quizzes itself on the small pile, prints how often it was right, and hands back the
   trained brain.
7. In `predict_one`, it takes one transaction, lines up the seven clues in the right
   order, and asks the brain for a guess.
8. It packs the answer into a neat box: was it fraud (1) or legit (0), a friendly label
   (`FRAUD` or `LEGIT`), how sure it is (confidence), and the model's version name.

**What you get:** A ready-to-use brain plus a simple way to ask it about any single
transaction and get back a tidy answer.

### `api.py` — the waiter who takes orders and brings back answers

**In one sentence:** This file builds the waiter (the API) that listens for questions,
checks that your order makes sense, asks the brain, and hands back the answer.

**What it does, step by step:**

1. It turns on a logbook (logging) so every action gets written down with the time —
   handy for finding out what happened later.
2. It builds the Flask waiter and wakes up the brain from `model.py` so it is ready to
   answer.
3. It makes a rulebook called `REQUIRED` that says which clues must be sent and what kind
   of number each one should be (some can be decimals, the rest must be whole numbers).
4. The `validate` helper checks every order: it complains if a clue is missing, if a clue
   is the wrong kind of number, or if `hour` is not between 0 and 23.
5. The `/health` endpoint is the question "Are you okay?" The waiter answers "healthy"
   and tells you the time.
6. The `/info` endpoint is the question "Who are you?" The waiter tells you the API's
   name, version, author, and program.
7. The `/predict` endpoint is the real order. The waiter gives the order a short ticket
   number (`req_id`), writes it in the logbook, and reads the order.
8. If the order is not proper JSON, it sends back a polite "Body must be JSON" error. If
   the order breaks a rule, it sends back the list of problems. (JSON is just a tidy way
   to write down information so computers can read it.)
9. If the order is good, the waiter asks the brain, adds the ticket number and the time
   to the answer, writes the result in the logbook, and hands the answer back.
10. The last lines tell the waiter to stand at the door (port 5000) and start listening
    for visitors.

**What you get:** A running waiter you can talk to over the web. Ask it `/health`,
`/info`, or send a transaction to `/predict` and it answers safely, even when you make a
mistake.

### `requirements.txt` — the shopping list of helper tools

**In one sentence:** This file is a shopping list of helper tools the computer must
install before the waiter can work.

**What it does, step by step:**

1. `flask` — the tool that builds the waiter (the API).
2. `scikit-learn` — the toolbox that builds and trains the smart guesser (the model).
3. `pandas` — a tool for holding information in neat tables, like a spreadsheet.
4. `numpy` — a tool for doing fast math with lots of numbers, used to make the pretend
   practice data.

**What you get:** With one install command, the computer grabs every helper tool on the
list so all the other files have what they need to run.

➡ Next: [chapter-06-docker](../chapter-06-docker) — containerize this API.
