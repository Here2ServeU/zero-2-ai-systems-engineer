# Chapter 12 — AIOps: AI for Operations

**Book:** Chapter 12 (AIOps, AI for Operations) · Lab 12.2
**Layer:** 6 · Observability & Operations · **You build:** A detect → predict → respond engine

## What you build

An AIOps engine combining **anomaly detection** (z-score) and **trend analysis** (linear
regression slope) into actionable warnings, plus an automated-response module that acts
on them (alert, scale up, open a ticket).

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install numpy flask prometheus-client

python aiops_engine.py         # prints WARNING/STABLE + recommended action
python automated_response.py   # demonstrates the automated reaction
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. *AIOps* means
using a computer to watch the app and fix problems by itself — like a robot night guard
who not only spots trouble but also calls for help without waking you up.

### `aiops_engine.py` — a robot guard that spots trouble and guesses what's coming

**In one sentence:** This watches the computer's busy-ness numbers (CPU and memory) and
warns you when something looks weird or is climbing toward trouble.

**What it does, step by step:**

1. It has a spotter that finds weird numbers. For each reading it works out a *z-score*
   (how surprising a number is — how far it sits from normal). If a z-score is bigger
   than the *threshold* of 2.0, that reading is a spike.
2. It has a trend-reader. A *trend* is which way the numbers are heading — up or down.
   To find it, the code does *linear regression*, which is a fancy way of saying "draw
   the straightest line through the dots and see if it points uphill or downhill." The
   *slope* is how steep that line is.
3. The `predict_failure` part means "guess a problem before it happens." It checks the
   CPU numbers and the memory numbers for both spikes and uphill trends.
4. If the uphill slope is steeper than 1.5 (climbing more than 1.5 each reading), it
   adds a warning that things are heading up fast.
5. If there are any warnings, it returns `WARNING` and says "Scale up now" (meaning: add
   more computers to share the load). If everything is calm, it returns `STABLE` and
   says no action is needed.
6. In the example, the CPU and memory numbers keep creeping up to the 90s, so it prints
   warnings and the action.

**What you get:** A little brain that reads the app's vital signs, notices both sudden
spikes and slow climbs, and tells you whether to relax or to add more power.

### `automated_response.py` — the part that actually pushes the buttons

**In one sentence:** This takes the robot guard's warning and pretends to do the real
fixes — sending an alert, adding more computers, and opening a trouble ticket.

**What it does, step by step:**

1. It borrows the `predict_failure` brain from the other file so it doesn't have to
   redo the thinking.
2. It feeds in fresh CPU and memory numbers that climb up high.
3. If the answer is `WARNING`, it prints a big "AIOps ALERT" and lists what's wrong.
4. Then it shows the automatic fixes it would do by itself: send an alert to Slack
   (a chat app), scale up the Kubernetes pods (add more app copies), and open an
   incident ticket (a help request so humans know).
5. If everything is calm, it simply says "All systems stable."

**What you get:** A demo of the app fixing its own problems hands-free — spotting the
trouble and then doing the standard response steps without a human pressing anything.

➡ Next: [chapter-13-retraining](../chapter-13-retraining) — retrain automatically on drift.
