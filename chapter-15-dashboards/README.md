# Chapter 15 — Dashboards you can watch (Grafana)

> Matches **Chapter 15** in the book. This chapter turns your program's numbers into live
> charts you can watch on a screen.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop · 🧑‍🤝‍🧑 Easier with a helper the first time

---

## The big idea (in plain words)

A car has a **dashboard**: the speed needle, the fuel gauge, the temperature light. You don't
have to open the hood to know how the car is doing — you just glance at the dashboard. We want
the same thing for our program: a screen of live charts that shows how busy it is and whether
anything looks wrong.

Two free tools work together to make this happen:

1. **Prometheus** — the *number collector*. Every few seconds it visits your app and writes
   down its numbers (how many guesses it made, how long they took, how busy it is).
2. **Grafana** — the *chart drawer*. It takes the numbers Prometheus collected and draws them
   as live charts you can watch in your web browser, like a car dashboard.

So: your app produces numbers → **Prometheus** collects them → **Grafana** draws them.

> **You'll need Docker Desktop** (the "lunchbox" tool you installed back in Chapter 06). This
> chapter starts three programs at once inside lunchboxes, which is a few moving parts — that's
> why having a helper nearby the first time makes it smoother.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Prometheus** — a tool that collects and stores **metrics** (numbers tracked over time).
- **Grafana** — a tool that turns those metrics into pretty, watchable charts.
- **Dashboard** — a screen of charts showing how your system is doing right now.
- **Metric** — a number you track over time, like "requests per minute" or "errors."
- **Container** — a running, packed-up copy of a program (the "lunchbox," opened and in use).

## What you will build

A fraud-checking **API** that counts what it does, plus the two tools that watch it:

- `monitored_api.py` — a small app that guesses *fraud* or *legit* and quietly keeps score.
- `prometheus.yml` — a short note telling Prometheus where to find the app's numbers.
- `docker-compose.yml` — one file that starts all three programs (app, Prometheus, Grafana) at
  once.
- `Dockerfile` + `requirements.txt` — the recipe and shopping list for packing the app into a
  lunchbox.

By the end you'll open **Grafana** in your browser and watch a chart move as you use the app.

---

## Let's do it, one small step at a time

### Step 1 — Make sure Docker Desktop is running

Open the **Docker Desktop** app (you installed it in Chapter 06). Wait until its whale icon
stops animating and says it's running. Check it in your terminal:

```bash
docker --version
```

**What you should see:** something like `Docker version 24.0.6, build ...`. If you get
`command not found`, install Docker Desktop first (see Chapter 06).

### Step 2 — Create the files

In VS Code, open this chapter's folder and create these files exactly.

**`monitored_api.py`** — the app that counts what it does:

```python
# monitored_api.py
from flask import Flask, request, jsonify
from prometheus_client import (
    Counter, Histogram, Gauge,
    start_http_server
)
import time, random

app = Flask(__name__)

FRAUD_PREDICTIONS = Counter(
    'fraud_predictions_total',
    'Total fraud predictions',
    ['result']
)
MODEL_LATENCY = Histogram(
    'model_inference_seconds',
    'Model inference time',
    buckets=[.001,.005,.01,.05,.1,.25,.5,1,2]
)
ACTIVE_REQUESTS = Gauge(
    'active_requests',
    'Number of requests being processed'
)

start_http_server(8000)

@app.route('/predict', methods=['POST'])
def predict():
    ACTIVE_REQUESTS.inc()
    start = time.time()
    data = request.get_json() or {}
    amount = data.get('amount', 0)
    hour = data.get('hour', 12)
    time.sleep(random.uniform(0.001, 0.01))
    is_fraud = (amount > 800 and hour < 6)
    label = 'fraud' if is_fraud else 'legit'
    MODEL_LATENCY.observe(time.time() - start)
    FRAUD_PREDICTIONS.labels(result=label).inc()
    ACTIVE_REQUESTS.dec()
    return jsonify({'prediction':int(is_fraud),
        'label':label})

@app.route('/health')
def health():
    return jsonify({'status':'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**What the key parts say, in plain words:**

- The app makes three kinds of counters to remember what's happening:
  - `FRAUD_PREDICTIONS` is a **Counter** — a tally that only goes up, like a clicker by a door
    counting people walking in. It counts how often we guessed `fraud` vs `legit`.
  - `MODEL_LATENCY` is a **Histogram** — it remembers how long each guess took, sorting times
    into little buckets (super fast, fast, slow...).
  - `ACTIVE_REQUESTS` is a **Gauge** — a number that can go up *or* down, like a temperature.
    It shows how many people the app is helping right this second.
- `start_http_server(8000)` opens a little window on **door (port) 8000** where Prometheus can
  come read these numbers.
- Inside `/predict`: it adds 1 to the gauge (one more person being helped), starts a timer,
  looks at the `amount` and the `hour`, and pretends to think for a tiny moment.
- The rule: if the amount is over 800 dollars **and** it's before 6 in the morning, it's
  `'fraud'`; otherwise `'legit'`. (Big money in the middle of the night looks fishy.) Then it
  records the time, bumps the tally, and lowers the gauge by 1.
- `/health` is a quick "are you okay?" door that just answers `healthy`.

**`prometheus.yml`** — the note telling Prometheus where the numbers live:

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'zero2ai-fraud-api'
    static_configs:
      - targets: ['host.docker.internal:8000']
```

**What each line says, in plain words:**

- `scrape_interval: 15s` — "go fetch fresh numbers every 15 seconds." (Fetching the numbers is
  called *scraping*.)
- `targets: ['host.docker.internal:8000']` — the address. It says "the numbers live at door
  8000 on the computer running this." That's the door the app opened above.

**`docker-compose.yml`** — start all three programs at once:

```yaml
# docker-compose.yml
version: '3.8'
services:
  fraud-api:
    build: .
    ports: ['5000:5000', '8000:8000']

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports: ['9090:9090']

  grafana:
    image: grafana/grafana:latest
    ports: ['3000:3000']
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=zero2ai123
```

**What each part says, in plain words:**

- This file lists three lunchboxes (containers) and starts them together.
- `fraud-api` is our own app. `build: .` means "make this lunchbox from the recipe in this
  folder." It opens door 5000 (the app) and door 8000 (the numbers).
- `prometheus` is the number-collector. It reads our `prometheus.yml` note and opens door 9090.
- `grafana` is the chart-drawer. It opens door 3000, and we set its login password to
  `zero2ai123`.

**`requirements.txt`** — the shopping list:

```
flask
prometheus-client
numpy
```

- `flask` lets the app listen for visitors and answer them.
- `prometheus-client` makes the counters and shares the numbers.
- `numpy` is a helper for working with numbers.

**`Dockerfile`** — the recipe for the app's lunchbox:

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY monitored_api.py .

RUN useradd -m appuser
USER appuser

EXPOSE 5000 8000
CMD ["python", "monitored_api.py"]
```

- `FROM python:3.11-slim` starts with a small box that already has Python in it.
- It copies in the shopping list and installs each helper, then copies in the app file.
- For safety it makes a plain user (`appuser`) instead of running as the all-powerful boss.
- `EXPOSE 5000 8000` names the doors, and `CMD` says "when you start, run the app."

Save every file.

### Step 3 — Start all three programs with one command

In the terminal, in this chapter's folder, type:

```bash
docker compose up -d
```

This builds the app's lunchbox and starts all three programs in the background. The first time,
it downloads Prometheus and Grafana, so give it a minute or two.

**What you should see:** several lines ending with something like:

```
✔ Container ...-fraud-api-1    Started
✔ Container ...-prometheus-1   Started
✔ Container ...-grafana-1      Started
```

You can also open Docker Desktop and see three running containers in the list.

### Step 4 — Open Grafana in your web browser

1. Open your web browser (Chrome, Safari, Edge — any is fine).
2. In the address bar, type **http://localhost:3000** and press Enter.

   (`localhost` means "this very computer," and `3000` is the door Grafana opened.)

3. A login page appears. Type:
   - **Username:** `admin`
   - **Password:** `zero2ai123`

**What you should see:** the Grafana welcome page after you log in. You're now inside the
chart-drawer.

> If you'd like, also open **http://localhost:9090** in another tab — that's Prometheus, the
> number-collector, where you can peek at the raw numbers.

### Step 5 — Connect Grafana to Prometheus

Grafana needs to know *where* the numbers are. Tell it once:

1. In Grafana, find **Connections → Data sources** (a gear or plug icon in the left menu).
2. Click **Add data source**, then choose **Prometheus**.
3. In the **URL** box, type exactly:

   ```
   http://prometheus:9090
   ```

   (Inside Docker, the programs call each other by name, so it's `prometheus`, not `localhost`.)
4. Scroll down and click **Save & test**.

**What you should see:** a green message like "Successfully queried the Prometheus API" or
"Data source is working."

### Step 6 — Make a chart and watch it move

1. In Grafana's left menu, click **Dashboards → New → New dashboard**, then **Add visualization**.
2. Pick the Prometheus data source you just made.
3. In the query box, type one of these (these are the names our app counts):

   ```
   rate(fraud_predictions_total[5m])
   histogram_quantile(0.99, rate(model_inference_seconds_bucket[5m]))
   active_requests
   ```

   Start with `active_requests` — it's the easiest to see move.
4. Now give the app something to count. Open a **new terminal** and knock on its door a few
   times:

   ```bash
   curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 999, "hour": 3}'
   curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 20, "hour": 14}'
   ```

   Run them a handful of times. The first should answer `fraud` (big money at 3am), the second
   `legit`.

**What you should see:** in Grafana, your chart starts showing data. The `fraud_predictions`
chart climbs as you send more requests. You're watching your program's life, live.

### Step 7 — Turn everything off when you're done

```bash
docker compose down
```

**What you should see:** lines like `✔ Container ...-grafana-1  Removed`. This cleanly stops
and removes the three lunchboxes so nothing keeps running in the background.

---

## Try it yourself (mini challenges)

- 🔧 **Open Grafana in the browser.** Just getting to **http://localhost:3000** and logging in
  with `admin` / `zero2ai123` is a real win. Look around the menus.
- 🔧 **Refresh the API a few times and watch a chart move.** Run the `curl` command from Step 6
  five or ten times, then watch the `fraud_predictions_total` chart climb.
- 🔧 **Send a "legit" payment.** Change the `curl` to `{"amount": 20, "hour": 14}` and send it.
  Watch the `legit` count grow instead of the `fraud` one.
- 🔧 **Peek at Prometheus directly.** Open **http://localhost:9090**, type `active_requests`
  into its search box, and press Execute to see the raw number.

## If something breaks

- **`docker: command not found` or the command hangs** → Docker Desktop isn't running. Open the
  Docker Desktop app and wait for it to say "running," then try again.
- **The browser says "can't reach this page" at localhost:3000** → The containers may still be
  starting (give it a minute), or they didn't start. Run `docker compose ps` to see if all
  three are up; if not, re-run `docker compose up -d` and read any error.
- **Grafana "Save & test" fails** → Make sure the URL is exactly `http://prometheus:9090`
  (not `localhost`). Inside Docker the programs find each other by name.
- **The chart stays empty** → Two things to check: (1) you actually sent some `curl` requests,
  and (2) Prometheus only scrapes every 15 seconds, so wait a few seconds and let the chart
  refresh.
- **`port is already allocated`** → Another program is using one of these doors (3000, 5000,
  8000, or 9090). Close that program, or run `docker compose down` to clear old containers,
  then try again.

## What you just learned

- **Prometheus** collects your program's numbers; **Grafana** draws them as live charts.
- A **dashboard** lets you glance at your system's health like a car dashboard — no opening the
  hood.
- **docker compose up** can start several programs (app, collector, chart-drawer) with one
  command, and **docker compose down** cleanly turns them off.
- Counters, gauges, and histograms are different kinds of **metrics**: a tally that only rises,
  a number that goes up and down, and a record of how long things take.

## Where to next

➡ [Chapter 16 — Talk to a smart writing robot (LLM)](../chapter-16-llm). You'll meet large
language models and send your first prompt to one.
