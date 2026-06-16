# Chapter 15 — Observability Deep Dive & Dashboards

**Book:** Chapter 15 (Observability Deep Dive and Dashboards) · Lab 15.2
**Layer:** 7 · Continuous Delivery · **You build:** The full Prometheus + Grafana stack

## What you build

A business-instrumented API (`monitored_api.py`: fraud-prediction Counter, inference-time
Histogram, active-requests Gauge) scraped by Prometheus and visualized in Grafana — all
started with one `docker compose up`.

> The `Dockerfile` + `requirements.txt` here follow the Chapter 6 containerization
> pattern so `build: .` in `docker-compose.yml` has an image to build. Everything else
> (compose, `prometheus.yml`, the API) is the book's Chapter 15 code verbatim.

## Run

```bash
docker compose up -d

# Grafana:    http://localhost:3000   (admin / nawex123)
# Prometheus: http://localhost:9090
# Add Prometheus data source URL: http://prometheus:9090
# Example panels:
#   rate(fraud_predictions_total[5m])
#   histogram_quantile(0.99, rate(model_inference_seconds_bucket[5m]))
#   active_requests

docker compose down
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we build a *dashboard* — a screen full of charts, like a car's dashboard that
shows your speed and fuel. To make those charts, two tools work together: *Prometheus*,
the tool that collects the numbers, and *Grafana*, the tool that draws the pretty charts.

### `monitored_api.py` — the app that counts what it does and shares the numbers

**In one sentence:** This is a small fraud-checking app that keeps a count of everything it does and hands those numbers over so they can be put on charts.

**What it does, step by step:**

1. It makes three kinds of counters to remember what is happening:
   - `FRAUD_PREDICTIONS` is a *Counter* — a tally that only goes up, like clicking a counter at a door each time someone walks in. It counts how many times we guessed "fraud" or "legit".
   - `MODEL_LATENCY` is a *Histogram* — it remembers how long each guess took, sorting times into little buckets (super fast, fast, slow, and so on).
   - `ACTIVE_REQUESTS` is a *gauge* — a number that can go up or down, like a temperature. It shows how many people the app is helping right this second.
2. `start_http_server(8000)` opens a little window on door number 8000 where Prometheus can come read all these numbers.
3. When someone sends data to `/predict`, the app: adds 1 to the gauge (one more person being helped), starts a timer, peeks at the `amount` of money and the `hour` of day, and pretends to think for a tiny moment.
4. The rule is simple: if the amount is over 800 dollars AND it is before 6 in the morning, it calls it `'fraud'`. Otherwise it is `'legit'`. (Big money in the middle of the night looks fishy.)
5. It writes down how long it took, adds 1 to the fraud-or-legit tally, then lowers the gauge by 1 (that person is done), and sends back the answer.
6. The `/health` door is a quick "are you okay?" check that just answers "healthy".

**What you get:** A working fraud-checker that quietly keeps score of how many guesses it makes, how long they take, and how busy it is right now.

### `prometheus.yml` — the note telling Prometheus where to find the numbers

**In one sentence:** This is a short note that tells Prometheus where to go to collect the numbers and how often to check.

**What it does, step by step:**

1. `scrape_interval: 15s` means "go fetch fresh numbers every 15 seconds." (Fetching the numbers is called "scraping.")
2. `targets: ['host.docker.internal:8000']` is the address. It says "the numbers live at door 8000 on the computer running this." That door is the one our app opened in step 2 above.

**What you get:** A simple set of directions so Prometheus knows where the numbers are and visits them every 15 seconds.

### `docker-compose.yml` — start several lunchbox programs at once

**In one sentence:** *docker-compose* lets you start several little packaged programs (the app, Prometheus, and Grafana) all at the same time with one command.

**What it does, step by step:**

1. Think of each program as its own lunchbox that already has everything it needs inside. This file lists three lunchboxes and starts them together.
2. `fraud-api` is our own app. `build: .` means "make this lunchbox from the recipe in this folder." It opens doors 5000 (the app) and 8000 (the numbers).
3. `prometheus` is the number-collector. It reads our `prometheus.yml` note and opens door 9090.
4. `grafana` is the chart-drawer. It opens door 3000, and we set its password to `nawex123` so you can log in.

**What you get:** One command that turns on all three programs at once, ready to talk to each other.

### `Dockerfile` — the recipe for one lunchbox

**In one sentence:** A *Dockerfile* is the recipe for building one packaged program (our app) so it has everything it needs inside.

**What it does, step by step:**

1. `FROM python:3.11-slim` starts with a small box that already has Python in it.
2. It copies in `requirements.txt` (the shopping list) and installs each helper tool on that list.
3. It copies in our app file, `monitored_api.py`.
4. For safety, it makes a plain user named `appuser` instead of running as the all-powerful boss.
5. `EXPOSE 5000 8000` says which doors this lunchbox will use, and `CMD` says "when you start, run the app."

**What you get:** A neat, self-contained package of our app that will run the same way on any computer.

### `requirements.txt` — a shopping list of helper tools

**In one sentence:** This is a simple shopping list of the extra helper tools our app needs to run.

**What it does, step by step:**

1. `flask` is the helper that lets our app listen for visitors and answer them.
2. `prometheus-client` is the helper that makes the counters and shares the numbers.
3. `numpy` is a helper for working with numbers.
4. When the Dockerfile says "install the shopping list," it grabs these three.

**What you get:** A short list that makes sure all the right helper tools get installed automatically.

➡ Next: [chapter-16-llm](../chapter-16-llm) — add an LLM customer-service endpoint.
