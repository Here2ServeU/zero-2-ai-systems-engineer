# Chapter 15 — Dashboards you can watch (Grafana)

> Matches Chapter 15 in the book.

**Labels:** Phase 1 runs free on your laptop · Phase 2 and 3 need an AWS account that costs money · Easier with a helper the first time

---

## The platform you are building

In this chapter you start building an **SRE dashboards and alerting platform**. That is the
screen of live charts (and, later, the alarms) that a company's engineers look at to know if
their apps are healthy. The charts are saved as files ("dashboards as code"), so nobody has to
rebuild them by hand, and they show the **golden signals**: how busy the app is, how fast it
answers, how often it fails, and how full it is. Companies pay for this because every minute
an app is broken and nobody notices costs them money and customers. The people who build it
are called **Site Reliability Engineers (SREs)**, **Observability Engineers** and **Platform
Engineers**, and they are in high demand.

## How this builds on Chapter 14

In Chapter 14 you released new versions safely (canary, blue/green). But how do you *know* a
new version is healthy? You watch the numbers. This chapter gives you the screen to watch them.

What carries over:

- **The metrics habit from Chapter 11.** You already taught an app to count things with
  `prometheus-client` (a `Counter` and a `Histogram`). This chapter's app does the same and adds a
  `Gauge`.
- **Docker from Chapter 06.** The app is packed in a container, and `docker compose` starts it
  next to Prometheus and Grafana.
- **The shared cloud platform from Chapter 10.** In Phase 2 and 3 you do not install Prometheus
  or Grafana yourself. They already run on the cluster for everyone. You reuse the same Helm
  chart, the same ServiceMonitor idea from Chapter 11, and the same alert rules (PrometheusRule).

What is new: **Grafana** (the chart drawer), **dashboards as code**, and alerts that watch the
golden signals.

```text
Your platform so far

  Ch 10  EKS cluster + shared Helm chart + load balancer (ALB)
  Ch 11  apps count things -> Prometheus collects the numbers
  Ch 12  a watcher reacts to those numbers
  Ch 13  retraining when the model drifts
  Ch 14  safe releases (canary, blue/green)
  Ch 15  Grafana dashboards as code + golden-signal alerts   <-- you are here
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **1 — Build it on your laptop** | Your computer (Python, then Docker) | Run the app, read its numbers, start Prometheus + Grafana with one command, draw a chart by clicking | Free |
| **2 — Promote it to the cloud** | AWS EKS (the shared platform) | 2A: plain YAML. 2B: Helm, and the dashboard ships as code | Costs money while the platform runs |
| **3 — Run it like a Fortune 500 company** | AWS EKS | Alerts on the golden signals, autoscaling, disruption budget, network rules, public address | Costs money while the platform runs |

## New words

Look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md).

- **Metric** — a number you track over time, like "requests per minute" or "errors."
- **Prometheus** — a tool that visits your app every few seconds and writes down its metrics.
  Visiting to collect the numbers is called **scraping**.
- **Grafana** — a tool that turns those metrics into live charts you watch in a web browser.
- **Dashboard** — a screen of charts showing how your system is doing right now, like a car
  dashboard.
- **Counter / Gauge / Histogram** — three kinds of metric: a tally that only goes up, a number
  that goes up and down, and a record of how long things take.
- **Data source** — where Grafana gets its numbers from (here: Prometheus).
- **Container** — a running, packed-up copy of a program (the "lunchbox," opened and in use).
- **Golden signals** — the four numbers SREs watch first: **traffic** (how busy), **latency**
  (how slow), **errors** (how often it fails) and **saturation** (how full).

---

## Phase 1 — Build it on your laptop

### The big idea (in plain words)

A car has a **dashboard**: the speed needle, the fuel gauge, the temperature light. You don't
open the hood to know how the car is doing. You glance at the dashboard. We want the same for
our program: a screen of live charts that shows how busy it is and whether anything looks wrong.

Two free tools work together:

1. **Prometheus** — the *number collector*. Every 15 seconds it visits your app and writes down
   its numbers (how many guesses it made, how long they took, how busy it is).
2. **Grafana** — the *chart drawer*. It takes the numbers Prometheus collected and draws them as
   live charts in your browser.

So: your app produces numbers -> **Prometheus** collects them -> **Grafana** draws them.

You will build it in small steps: first run the app with plain Python, then pack it in a
container, then start all three programs together.

### What you will build

- `monitored_api.py` — a small fraud-checking app that guesses *fraud* or *legit* and quietly
  keeps score.
- `requirements.txt` — the shopping list of Python helpers.
- `Dockerfile` — the recipe for packing the app into a container.
- `prometheus.yml` — a short note telling Prometheus where to find the app's numbers.
- `docker-compose.yml` — one file that starts all three programs (app, Prometheus, Grafana).

All five files are already in this folder. You can read along, or type them yourself.

### Step 1 — Check your tools

You need **Python 3.10 or newer** (Chapter 01) and **Docker Desktop** (Chapter 06). Open Docker
Desktop and wait until it says it is running. Then, in a terminal:

```bash
python3 --version
docker --version
docker compose version
```

**What you should see:** three version lines, something like `Python 3.11.9`,
`Docker version 27.x.x, build ...` and `Docker Compose version v2.x.x`. Your numbers can be
newer. If you see `command not found`, install the missing tool first (Chapter 01 or 06).

> **Windows:** use `python` instead of `python3` everywhere in this chapter.

### Step 2 — Look at the files

Open this chapter's folder (`chapter-15-dashboards`) in VS Code.

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
  - `ACTIVE_REQUESTS` is a **Gauge** — a number that can go up *or* down, like a thermometer.
    It shows how many people the app is helping right this second.
- `start_http_server(8000)` opens a second door, **port 8000**, where Prometheus comes to read
  these numbers. The app itself answers visitors on **port 5000**.
- Inside `/predict`: it adds 1 to the gauge, starts a timer, looks at the `amount` and the
  `hour`, and pretends to think for a tiny moment.
- The rule: if the amount is over 800 dollars **and** it's before 6 in the morning, it's
  `'fraud'`; otherwise `'legit'`. (Big money in the middle of the night looks fishy.) Then it
  records the time, bumps the tally, and lowers the gauge by 1.
- `/health` is a quick "are you okay?" door that just answers `healthy`.

**`requirements.txt`** — the shopping list:

```
flask
prometheus-client
numpy
```

- `flask` lets the app listen for visitors and answer them.
- `prometheus-client` makes the counters and shares the numbers.
- `numpy` is a helper for working with numbers.

### Step 3 — Run the app on your laptop (Terminal 1)

You need **two terminal windows** for this step. Terminal 1 runs the app and stays busy.
Terminal 2 sends it questions.

In **Terminal 1**, from the `chapter-15-dashboards` folder, make a clean toolbox (a *virtual
environment*), step into it, and install the helpers:

```bash
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

**What you should see:** packages downloading, ending with a line like
`Successfully installed flask-... numpy-... prometheus-client-...`. Your prompt now starts
with `(venv)`.

Now start the app:

```bash
python monitored_api.py
```

**What you should see:**

```
 * Serving Flask app 'monitored_api'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. ...
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
Press CTRL+C to quit
```

The warning is normal for a practice app. Leave this terminal alone; it is listening.

### Step 4 — Knock on the doors (Terminal 2)

Open a **second** terminal (in VS Code: **Terminal -> New Terminal**). You don't need the
virtual environment here. Run each line:

```bash
curl http://localhost:5000/health
curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 999, "hour": 3}'
curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 20, "hour": 14}'
```

**What you should see:**

```
{"status":"healthy"}
{"label":"fraud","prediction":1}
{"label":"legit","prediction":0}
```

Big money at 3am is `fraud`; a small payment in the afternoon is `legit`.

Now peek at the numbers the app keeps for Prometheus, on door 8000:

```bash
curl -s http://localhost:8000/metrics | grep -E "^(fraud_predictions_total|active_requests)"
```

**What you should see:**

```
fraud_predictions_total{result="fraud"} 1.0
fraud_predictions_total{result="legit"} 1.0
active_requests 0.0
```

This plain-text page is exactly what Prometheus reads. Send a few more `/predict` requests and
run the `metrics` command again: the counts go up.

> **Windows PowerShell:** `grep` doesn't exist there. Run the command in **Git Bash** instead,
> or just open http://localhost:8000/metrics in your browser and look for those lines.

When you're done, go back to **Terminal 1** and press **Ctrl+C** to stop the app. Type
`deactivate` to leave the virtual environment.

### Step 5 — Pack it in a container

Now pack the same app into a lunchbox (a container image) so it runs the same everywhere: on
your laptop now, on the cloud in Phase 2.

**`Dockerfile`** — the recipe:

```dockerfile
# Dockerfile (follows the Chapter 6 containerization pattern so the
# docker-compose stack in this chapter has an image to build).
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
- For safety it makes a plain user (`appuser`) instead of running as the all-powerful boss
  (`root`). If someone broke in, they would have fewer powers.
- `EXPOSE 5000 8000` names the doors, and `CMD` says "when you start, run the app."

In **Terminal 1**, from the `chapter-15-dashboards` folder, build the image:

```bash
docker build -t zero2ai-monitored-api .
```

**What you should see:** build steps scrolling past, ending with a line like
`naming to docker.io/library/zero2ai-monitored-api` (the exact wording depends on your Docker
version). The first build takes a minute or two.

Run it. `-p 5000:5000 -p 8000:8000` connects your laptop's doors to the container's doors:

```bash
docker run --rm --name ch15-api -p 5000:5000 -p 8000:8000 zero2ai-monitored-api
```

**What you should see:** the same `Running on http://127.0.0.1:5000` lines as Step 3. This time
they come from inside the container.

In **Terminal 2**, run the same checks as before:

```bash
curl http://localhost:5000/health
curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 999, "hour": 3}'
curl -s http://localhost:8000/metrics | grep fraud_predictions_total
```

**What you should see:** `{"status":"healthy"}`, then `{"label":"fraud","prediction":1}`, then
lines starting with `fraud_predictions_total`. Same app, now in a lunchbox.

Stop it: press **Ctrl+C** in Terminal 1 (or run `docker stop ch15-api` in Terminal 2).

### Step 6 — Start the app, Prometheus and Grafana together

One container is easy. Three that talk to each other need a plan. `docker compose` reads one
file and starts them all.

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

- `scrape_interval: 15s` — "go fetch fresh numbers every 15 seconds."
- `targets: ['host.docker.internal:8000']` — the address. `host.docker.internal` is Docker
  Desktop's name for "the computer running Docker." So it means "door 8000 on my laptop," which
  is where the app's numbers come out.

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

- This file lists three containers and starts them together.
- `fraud-api` is our own app. `build: .` means "make this container from the `Dockerfile` in
  this folder" (the same recipe as Step 5). It opens door 5000 (the app) and door 8000 (the
  numbers).
- `prometheus` is the number collector. It reads our `prometheus.yml` note and opens door 9090.
- `grafana` is the chart drawer. It opens door 3000, and we set its login password to
  `zero2ai123`. (A password in a file is fine for a practice app on your laptop. In Phase 2 the
  real password is generated and kept secret.)

In **Terminal 1**, from the `chapter-15-dashboards` folder:

```bash
docker compose up -d --build
```

`-d` runs everything in the background, so you get your terminal back. `--build` rebuilds the
app's image so it always has your latest code. The first time, it also downloads Prometheus and
Grafana, so give it a minute or two.

**What you should see:** several lines ending like this (a tick mark may appear in front of
each):

```
Container chapter-15-dashboards-fraud-api-1   Started
Container chapter-15-dashboards-prometheus-1  Started
Container chapter-15-dashboards-grafana-1     Started
```

You may also see a warning that "the attribute `version` is obsolete." That is harmless; newer
Docker simply ignores that line.

Check all three are running:

```bash
docker compose ps
```

**What you should see:** three rows (`fraud-api`, `prometheus`, `grafana`), each with a status
like `Up 20 seconds`.

### Step 7 — Check that Prometheus can see the app

Open your web browser and go to **http://localhost:9090/targets**.

**What you should see:** one target called `zero2ai-fraud-api` with the state **UP** (green).
That means Prometheus is collecting the app's numbers every 15 seconds. If it says **DOWN**, see
"If something breaks" below.

### Step 8 — Open Grafana and connect it to Prometheus

1. Go to **http://localhost:3000** (`localhost` means "this very computer," and `3000` is
   Grafana's door).
2. Log in with **Username:** `admin` and **Password:** `zero2ai123`. If Grafana offers to
   change the password, you can click **Skip**.
3. In the left menu, open **Connections -> Data sources**.
4. Click **Add data source**, then choose **Prometheus**.
5. In the **Prometheus server URL** box, type exactly:

   ```
   http://prometheus:9090
   ```

   Inside Docker Compose, the containers call each other by their names, so it is
   `prometheus`, not `localhost`.
6. Scroll down and click **Save & test**.

**What you should see:** a green message: "Successfully queried the Prometheus API."

### Step 9 — Make a chart and watch it move

1. In the left menu, click **Dashboards -> New -> New dashboard**, then **Add visualization**.
2. Pick the **Prometheus** data source you just made.
3. In the query box (switch to **Code** mode if you see a button for it), type:

   ```
   rate(fraud_predictions_total[5m])
   ```

   Then click **Run queries**. Other queries to try later:

   ```
   histogram_quantile(0.99, rate(model_inference_seconds_bucket[5m]))
   active_requests
   ```

4. Give the app something to count. In **Terminal 2**, run these a handful of times:

   ```bash
   curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 999, "hour": 3}'
   curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 20, "hour": 14}'
   ```

**What you should see:** after 15-30 seconds, two lines appear on the chart, one for `fraud` and
one for `legit`, and they rise as you send more requests. Click **Save dashboard** (top right)
and give it a name. You're watching your program's life, live.

### Step 10 — Turn everything off

From the `chapter-15-dashboards` folder:

```bash
docker compose down
```

**What you should see:** lines like `Container chapter-15-dashboards-grafana-1  Removed` and
`Network chapter-15-dashboards_default  Removed`. Nothing keeps running in the background.
(Your clicked-together dashboard is gone too. That's one reason Phase 2 saves the dashboard as a
file.)

### Try it yourself

- **Watch the legit count grow.** Send ten `{"amount": 20, "hour": 14}` payments and watch the
  `legit` line climb faster than `fraud`.
- **Find the edge of the rule.** Is `{"amount": 800, "hour": 3}` fraud? What about
  `{"amount": 801, "hour": 6}`? Predict first, then test.
- **Peek at Prometheus directly.** Open **http://localhost:9090**, type `active_requests` in the
  search box, and press **Execute** to see the raw number.
- **Add a second panel.** In your dashboard, add a visualization for
  `sum(fraud_predictions_total)` (total guesses ever) and pick the **Stat** type, so it shows
  one big number.

### If something breaks

- **`docker: command not found`, or `Cannot connect to the Docker daemon`** -> Docker Desktop
  isn't running. Open it, wait until it says "running," then try again.
- **`python3: command not found` (Windows)** -> Use `python` instead of `python3`.
- **`ModuleNotFoundError: No module named 'flask'` (or `prometheus_client`)** -> You're not in
  the virtual environment, or you skipped the install. Run `source venv/bin/activate` (Windows:
  `venv\Scripts\activate`) and `pip install -r requirements.txt` again.
- **`Address already in use`, `port is already allocated` or `ports are not available`** ->
  Another program is using door 3000, 5000, 8000 or 9090. Common causes:
  - The app from Step 3 or the container from Step 5 is still running. Press Ctrl+C in its
    terminal, or run `docker stop ch15-api`.
  - An old Compose run. Run `docker compose down`.
  - **On a Mac, port 5000 is used by AirPlay Receiver.** Turn it off in **System Settings ->
    General -> AirDrop & Handoff -> AirPlay Receiver**, then try again.
- **`curl` to port 5000 answers `403 Forbidden` on a Mac** -> That is AirPlay Receiver
  answering, not your app. Turn it off as above.
- **`curl: (7) Failed to connect`** -> The app isn't running. Check Terminal 1 still shows
  `Running on http://127.0.0.1:5000` (or `docker compose ps` shows `fraud-api` as `Up`).
- **The target at http://localhost:9090/targets is DOWN** -> Prometheus can't reach door 8000.
  Check `docker compose ps` shows `fraud-api` running. On **Linux** (not Docker Desktop),
  `host.docker.internal` doesn't exist by default: change the target in `prometheus.yml` to
  `'fraud-api:8000'` (the container's name) and run `docker compose up -d` again.
- **The browser says "can't reach this page" at localhost:3000** -> Grafana is still starting.
  Wait 30 seconds and reload. Still nothing? Run `docker compose logs grafana` and read the last
  lines.
- **Grafana "Save & test" fails** -> The URL must be exactly `http://prometheus:9090` (not
  `localhost`).
- **Grafana login fails** -> Username `admin`, password `zero2ai123`. If you changed the password
  in an earlier run and forgot it, run `docker compose down` and `docker compose up -d` to start
  fresh.
- **The chart stays empty ("No data")** -> (1) Send some `curl` requests first. (2) Prometheus
  only collects every 15 seconds and `rate(...[5m])` needs at least two collections, so wait 30
  seconds. (3) Set the time range (top right) to **Last 15 minutes**.

### What you learned in Phase 1

- An app can count what it does with **Counters, Gauges and Histograms** and share those numbers
  on a `/metrics` page.
- **Prometheus** collects those numbers; **Grafana** draws them as live charts.
- You packed the app in a **container** with a `Dockerfile`, and started three containers at once
  with **docker compose** (and stopped them cleanly with `docker compose down`).
- A dashboard you click together is easy to lose. Real teams save it as a file, which is what
  you'll do next.

---

## Phase 2 and Phase 3

Ready to put this on a real cloud cluster?

- **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md). Same app on AWS EKS,
  scraped by the cluster's Prometheus, with the dashboard shipped as code in the Helm release.
- **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md).
  Golden-signal alerts, autoscaling, a runbook, and a production checklist.

Build the shared platform first: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
It costs money while it runs, so destroy it when you finish for the day.

## Where to next

[Chapter 16 — Talk to a smart writing robot (LLM)](../chapter-16-llm/README.md). You'll meet
large language models, send your first prompt to one, and put it behind your own API.
