# Chapter 11 — Observability with Prometheus

**Book:** Chapter 11 (Observability and Monitoring) · Lab 11.2
**Layer:** 6 · Observability & Operations · **You build:** An instrumented API + anomaly detector

## What you build

A Flask API instrumented with Prometheus `Counter` and `Histogram` metrics (served on
port 8000), plus a z-score anomaly detector over latency readings.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install flask prometheus-client numpy

python app_with_metrics.py     # API on :5000, metrics on :8000
# In another terminal:
curl http://localhost:8000      # raw Prometheus metrics
python anomaly_detection.py     # flags the 2.50s latency outlier
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we keep an eye on our app like a nurse checking a patient. We write down
numbers (called *metrics*) about how the app is doing, and we look for anything weird.

### `app_with_metrics.py` — a web app that counts its own visits and times them

**In one sentence:** This makes a small web app that, while it answers people, also keeps
a tally of how many visits it got and how long each one took.

**What it does, step by step:**

1. It builds a tiny website (called an *API*) using a helper named Flask. An API is
   just a door that other programs can knock on to ask for an answer.
2. It makes a *counter*. A counter is a tally that only goes up, like clicking a
   clicker each time someone walks through a door. This one counts every request.
3. It makes a *histogram*. A histogram is a chart that shows how long things took —
   like a chart of "this many visits took half a second, this many took two seconds."
4. It opens a special second door on port 8000 just for the numbers. The tool called
   *Prometheus* (think of it as a clipboard collector) can come read that clipboard.
5. It has a `/health` door. When you knock, it says "I'm healthy!" and adds one to the
   counter.
6. It has a `/predict` door. You send it an amount of money. If the amount is more than
   800, it answers `1` (suspicious); otherwise `0` (fine). It also times how long that
   took and writes it on the histogram.

**What you get:** A running app that watches itself and shares its numbers, so a clipboard
tool like Prometheus can keep track of how busy and how fast it is.

### `anomaly_detection.py` — a spotter that finds the one weird number

**In one sentence:** This looks at a list of how-long-things-took numbers and points out
the one that is strange (an *anomaly* means something out of place).

**What it does, step by step:**

1. It takes a list of times. Most are tiny, like 0.10 seconds, but one is a huge 2.50
   seconds — that one is the troublemaker.
2. It finds the *average* (the normal middle) of all the times.
3. It measures how spread out the numbers usually are.
4. For each number it computes a *z-score*. A z-score tells you how surprising a number
   is — how far it sits from normal. A small z-score means "totally normal." A big one
   means "whoa, that's weird."
5. The *threshold* (the pass/fail line) is 2.0. If a number's z-score is bigger than 2.0,
   it gets flagged as an anomaly.
6. It prints out the weird one: the 2.50-second visit, with its z-score.

**What you get:** A simple alarm that automatically points at the one slow, strange
reading hiding in a pile of normal ones.

➡ Next: [chapter-12-aiops](../chapter-12-aiops) — turn metrics into automated response.
