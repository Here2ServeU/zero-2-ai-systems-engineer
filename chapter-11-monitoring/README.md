# Chapter 11 — Watch your program's health (Monitoring)

> Matches Chapter 11 in the book.

**Labels:** Phase 1 runs free on your laptop · Phases 2 and 3 need an account that may cost money · Needs the internet (Phases 2 and 3)

---

## The platform you are building

In this chapter you start building an **observability platform**: the system that lets a
company *see* how every one of its programs is doing, all day and all night. Without it, a team
only finds out something is broken when an angry customer calls. With it, a dashboard turns red
and an alert goes off minutes before most customers notice. Companies pay for this because every
minute a shopping site, bank app or AI service is down or slow costs real money and trust. The
people who build it are called **Site Reliability Engineers (SREs)**, **Platform Engineers**,
**Observability Engineers** and **DevOps Engineers**, and these are some of the most in-demand
jobs in tech.

## How this builds on Chapter 10

In Chapter 10 you built a Kubernetes platform on AWS: a cluster (EKS), one shared Helm chart
that every chapter installs, a shared load balancer (the platform ALB), and the add-ons, which
already installed **Prometheus**, **Grafana** and **Alertmanager** in the `monitoring` namespace.
Until now, nothing was feeding them your own app's numbers.

What carries over:

- **Chapter 05 and 06 skills:** a small Flask web app, packed into a Docker container.
- **Chapter 10's cluster, Helm chart and platform ALB:** Chapter 11's cloud scripts reuse them
  as they are. You do not build a new cluster.
- **Chapter 10's Prometheus:** it is already running. This chapter tells it to collect your app.

What is new:

- An app that keeps its **own health numbers** (metrics) and shows them on a second door, port 8000.
- A **ServiceMonitor** that tells Prometheus "collect this app every 15 seconds".
- **Alert rules** that raise the alarm when the app is down or slow (Phase 3).
- A tiny **anomaly spotter** that finds the one strange number in a list.

The app in this chapter is a new, smaller one called `metrics-api`. Its `/predict` door uses a
simple rule (amount over 800 is suspicious) instead of Chapter 10's trained model, so you can
focus on watching it.

```text
Your platform so far

  Chapter 10 (already built)                    Chapter 11 (new)
  +------------------------------------+
  | AWS EKS cluster  (Terraform)       |
  |   shared Helm chart: zero2ai-app   | -----> metrics-api (2+ copies)
  |   monitoring namespace:            |          port 5000: the app
  |     Prometheus  <------------------|--------  port 8000: its metrics
  |     Grafana, Alertmanager          |        ServiceMonitor ("collect me")
  |   platform ALB (one front door)    | -----> :8011 -> metrics-api (Phase 3)
  +------------------------------------+        alert rules (Phase 3)
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **Phase 1 — Build it on your laptop** | Your computer | Write the metrics app and the anomaly spotter, then pack the app in a container | Free |
| **Phase 2 — Promote it to the cloud** | AWS EKS | 2A: plain YAML + ServiceMonitor. 2B: the same app with the Helm chart. Prometheus collects it. | Costs money while the platform runs. Destroy it when done. |
| **Phase 3 — Run it like a Fortune 500 company** | AWS EKS | Alert rules, autoscaling, disruption budget, network rules, public address, a runbook | Costs money while the platform runs. Destroy it when done. |

## New words

Look up anything else in the [GLOSSARY](../GLOSSARY.md).

- **Metric** — A number you track over time, like "requests so far" or "how long a request took".
- **Monitoring / observability** — Watching a running program's health so you notice problems
  early. Observability is the bigger idea: being able to ask "why is it slow?" and get an answer
  from the numbers.
- **Counter** — A metric that only goes up, like a clicker you press each time someone walks in.
- **Histogram** — A metric that sorts measurements into buckets ("this many took under 0.1
  seconds, this many took under 0.5 seconds"), so you can see how long things usually take.
- **Port** — A numbered door on a computer that programs use to talk. This app has two: 5000 and 8000.
- **Prometheus** — A tool that visits your app's metrics door every few seconds, copies down the
  numbers and keeps the history. Think of a person with a clipboard who comes by on a schedule.
- **Scrape** — What Prometheus does when it visits a metrics door and copies the numbers.
- **Anomaly** — Something that does not fit the normal pattern; an oddity worth a closer look.
- **Z-score** — How many "normal spreads" a number sits away from the average. Bigger means weirder.
- **Container** — Your program and everything it needs, sealed in a box that runs the same on
  any computer (Chapter 06).

---

## Phase 1 — Build it on your laptop

**The big idea, in plain words.** Imagine your program wears a **fitness watch**. The watch
does not do the running. It just quietly counts things while you run: heartbeats, steps, speed.
Later you glance at it and instantly know how you are doing.

We want the same for a running program. While it answers visitors, it keeps a few numbers on the
side: *How many times was I visited? How long did each visit take?* Once you can see those
numbers, you can spot trouble early, like noticing your heart rate is far too high before you
collapse.

You will build two small things:

- `app_with_metrics.py` — a small web program (an **API**) that counts its own visits and times
  them, and shows those numbers on a separate door.
- `anomaly_detection.py` — a spotter that reads a list of timing numbers and points out the one
  that is strangely slow.

The course repo already has finished copies of both files in this `chapter-11-monitoring`
folder. You will type your own copies in a practice folder, so you learn by doing.

### Step 1 — Make a practice folder and go into it

Open your **terminal** (the text window from Chapter 01) in the **top folder of the course
repo**, the folder that holds `chapter-01-setup`, `chapter-02-data` and the others. Then type:

```bash
mkdir my-chapter-11
cd my-chapter-11
```

- `mkdir my-chapter-11` makes a new, empty **folder** for your typing.
- `cd my-chapter-11` moves you *into* that folder, so your work lands there.

We use the name `my-chapter-11` so your files never get mixed up with the finished copies in
`chapter-11-monitoring`.

**What you should see:** no message at all. That is normal. Type `pwd` (Mac/Linux/Git Bash) and
the last part of the answer is `my-chapter-11`.

### Step 2 — Make a clean toolbox (virtual environment)

A **virtual environment** is a clean, private toolbox just for this project, so its helpers do
not bump into anything else on your computer. Make one and switch it on:

```bash
python3 -m venv venv
source venv/bin/activate
```

- `python3 -m venv venv` builds the toolbox in a folder called `venv`.
- `source venv/bin/activate` switches it on.

**What you should see:** your terminal line now starts with `(venv)`. That means the toolbox is on.

> **Windows note:** use `python -m venv venv`, then `venv\Scripts\activate` in PowerShell (or
> `source venv/Scripts/activate` in Git Bash).

### Step 3 — Install the helpers

```bash
pip install flask prometheus-client numpy
```

- `pip` is the tool that **installs** helpers into your toolbox.
- `flask` builds tiny web programs. `prometheus-client` keeps the metrics. `numpy` does the math
  for the spotter.

**What you should see:** some download lines, then a line starting with
`Successfully installed` that names `flask`, `numpy` and `prometheus_client` (plus a few helpers
they need).

### Step 4 — Write the web program that watches itself

Make a new file called **`app_with_metrics.py`** in your `my-chapter-11` folder and type this in:

```python
# app_with_metrics.py
from flask import Flask, request, jsonify
from prometheus_client import (
    Counter, Histogram, start_http_server
)
import time

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'api_requests_total',
    'Total API requests',
    ['method','endpoint','status']
)
REQUEST_LATENCY = Histogram(
    'api_request_duration_seconds',
    'Request duration in seconds'
)

start_http_server(8000)

@app.route('/health')
def health():
    REQUEST_COUNT.labels(
        method='GET',endpoint='/health',
        status='200').inc()
    return jsonify({'status':'healthy'})

@app.route('/predict', methods=['POST'])
def predict():
    start = time.time()
    data = request.get_json()
    result = 1 if data.get('amount',0) > 800 else 0
    latency = time.time() - start
    REQUEST_LATENCY.observe(latency)
    REQUEST_COUNT.labels(
        method='POST',endpoint='/predict',
        status='200').inc()
    return jsonify({'prediction':result})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**What the key lines say, in plain words:**

- `app = Flask(__name__)` — Start a tiny web program. Flask is the helper that builds it.
- `REQUEST_COUNT = Counter(...)` — Make a **counter**: a tally that only goes up. This one counts
  every visit. The list `['method','endpoint','status']` are **labels**: little name tags, so you
  can count `/health` visits and `/predict` visits separately.
- `REQUEST_LATENCY = Histogram(...)` — Make a **histogram** that records *how long* each
  prediction took. **Latency** is the word engineers use for "how long it took".
- `start_http_server(8000)` — Open a **second door** on **port** 8000, just for the numbers. This
  is the door Prometheus reads from.
- `@app.route('/health')` — Make a `/health` door. When you knock, it replies "healthy" and adds
  one to the counter.
- `@app.route('/predict', ...)` — Make a `/predict` door. You send it an amount of money. Over
  800, it answers `1` (suspicious); otherwise `0` (fine). `time.time()` before and after measures
  how long that took, and `.observe(latency)` writes that time into the histogram.
- `app.run(... port=5000)` — Open the main door (the app itself) on **port** 5000.

So your program has **two doors**: port 5000 for visitors, and port 8000 for its own health numbers.

### Step 5 — Start the program (Terminal 1)

In your terminal (the one with `(venv)`, inside `my-chapter-11`), run:

```bash
python app_with_metrics.py
```

**What you should see:** a few lines like these (yours may have a different second address):

```text
 * Serving Flask app 'app_with_metrics'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://192.168.1.20:5000
Press CTRL+C to quit
```

The `WARNING` line is normal: Flask reminds you its built-in server is for practice. The
program is now awake and listening. **Leave this terminal running.** This is **Terminal 1**.

### Step 6 — Open a second terminal and read the numbers (Terminal 2)

Your program is busy holding both doors open in Terminal 1, so you need a *second* terminal to
talk to it.

- In VS Code, click **Terminal -> New Terminal**. A fresh panel opens. This is **Terminal 2**.
- Move into the same folder and switch the toolbox on again (from the top folder of the course repo):

  ```bash
  cd my-chapter-11
  source venv/bin/activate
  ```

Now knock on the numbers door (port 8000):

```bash
curl http://localhost:8000
```

- `curl` is a tool that knocks on a web door from the terminal.
- `localhost` means "this same computer".

**What you should see:** a long block of plain text: the raw metrics. Most lines start with
`python_` or `process_` (numbers the helper keeps about Python itself). Scroll and find:

```text
# HELP api_requests_total Total API requests
# TYPE api_requests_total counter
```

There is no number under it yet, because nobody has visited the app. The first visit creates it.

> **Windows note:** in PowerShell type `curl.exe` instead of `curl`, or use Git Bash, where
> every command in this chapter works as written. You can also open `http://localhost:8000` in
> your web browser.

### Step 7 — Make the counter go up

Still in **Terminal 2**, knock on the `/health` door. Run this line four times:

```bash
curl http://localhost:5000/health
```

**What you should see:** `{"status":"healthy"}` each time. Now read only your app's lines from
the numbers door:

```bash
curl -s http://localhost:8000 | grep api_requests_total
```

- `-s` means "silent": no progress bar.
- `| grep api_requests_total` keeps only the lines that contain `api_requests_total`.

**What you should see:**

```text
# HELP api_requests_total Total API requests
# TYPE api_requests_total counter
api_requests_total{endpoint="/health",method="GET",status="200"} 4.0
```

The last number is how many times you knocked. Knock again and read again: it goes up. You just
watched a metric climb. That is monitoring.

Now ask for a prediction and time it:

```bash
curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 900}'
```

- `-X POST` means "I am sending something", not just asking.
- `-H "Content-Type: application/json"` tells the app "what I send is JSON" (a simple text format
  for data).
- `-d '{"amount": 900}'` is the data: an amount of 900.

**What you should see:** `{"prediction":1}` (900 is over 800, so it is flagged). Try
`'{"amount": 100}'` and you get `{"prediction":0}`. Then read the timing numbers:

```bash
curl -s http://localhost:8000 | grep api_request_duration_seconds_count
```

**What you should see:** `api_request_duration_seconds_count 2.0` if you made two predictions.
That counts how many timings went into the histogram.

### Step 8 — Write and run the anomaly spotter

The counter is great, but we also want to *notice* one weird, slow visit hiding in a pile of
normal ones. Make a new file called **`anomaly_detection.py`** in `my-chapter-11`:

```python
# anomaly_detection.py
import numpy as np

def detect_anomaly(data, threshold=2.0):
    mean = np.mean(data)
    std = np.std(data)
    anomalies = []
    for i, value in enumerate(data):
        if abs(value - mean) > threshold * std:
            anomalies.append({
                'index': i,
                'value': value,
                'zscore': abs(value-mean)/std
            })
    return anomalies

# Simulate API latency readings:
latencies = [0.10, 0.09, 0.11, 0.10, 0.12,
             0.09, 2.50, 0.11, 0.10, 0.09]
anomalies = detect_anomaly(latencies)
for a in anomalies:
    print(f'Anomaly at index {a["index"]}: '
          f'{a["value"]}s (z={a["zscore"]:.2f})')
```

**What the key lines say, in plain words:**

- `latencies = [...]` — A list of timings (how long visits took, in seconds). Most are about 0.10
  seconds, but one is a huge **2.50**: the troublemaker.
- `mean = np.mean(data)` — Find the **average**, the normal middle of all the numbers.
- `std = np.std(data)` — The **standard deviation**: how spread out the numbers usually are.
- `if abs(value - mean) > threshold * std` — For each number, ask: is it surprisingly far from
  normal? How far, counted in "spreads", is the **z-score**. The **threshold** (the pass/fail
  line) is `2.0`. A z-score above 2.0 means "that is weird", so it is flagged.
- `enumerate(data)` gives each number together with its position (its **index**). Python counts
  positions from 0, so the 7th number is index 6.

Run it in Terminal 2:

```bash
python anomaly_detection.py
```

**What you should see:**

```text
Anomaly at index 6: 2.5s (z=3.00)
```

The spotter found the one slow visit all by itself. (If a printed book shows a slightly
different `z=` number, trust what your computer prints. The math above gives exactly 3.00.)

### Step 9 — Stop the program

Go back to **Terminal 1** and press **Ctrl+C**. That stops the web program and frees both doors
(5000 and 8000). You need them free for the next step.

**What you should see:** you get your normal terminal line back.

### Step 10 — Pack it in a container

At work, nobody runs an app by typing `python app_with_metrics.py` on a server. They ship a
**container**, the sealed lunchbox from Chapter 06. Phase 2 sends exactly this container to the
cloud, so let's check it works on your laptop first.

The finished chapter folder already has the recipe (`Dockerfile`) and the shopping list
(`requirements.txt`) next to the same two Python files you typed. Make sure **Docker Desktop is
open and running**, then go there (from your `my-chapter-11` folder):

```bash
cd ../chapter-11-monitoring
ls
```

**What you should see:** a list that includes `Dockerfile`, `requirements.txt`,
`app_with_metrics.py`, `anomaly_detection.py`, `README.md` and a `cloud` folder.

**What the `Dockerfile` says, in plain words:** start from a small box that already has Python
3.11; install `flask`, `prometheus-client` and `numpy`; copy in the two Python files; switch to
a plain, non-boss user (`appuser`) for safety; open doors 5000 and 8000; and when the box starts,
run `python app_with_metrics.py`.

Build the image (the lunchbox):

```bash
docker build -t metrics-api:local .
```

- `-t metrics-api:local` names the image `metrics-api` with the tag `local`.
- The `.` at the end means "the recipe is in this folder".

**What you should see:** steps scrolling by, ending with a line like
`naming to docker.io/library/metrics-api:local` and no errors. The first build takes a minute or two.

Start a container from it, with both doors connected to your laptop:

```bash
docker run -d -p 5000:5000 -p 8000:8000 --name metrics-api metrics-api:local
```

- `-d` runs it in the background, so your terminal stays free.
- `-p 5000:5000` connects door 5000 on your laptop to door 5000 inside the box. `-p 8000:8000`
  does the same for the metrics door.
- `--name metrics-api` gives the running container a friendly name.

**What you should see:** one long line of letters and numbers (the container's ID). Check it is running:

```bash
docker ps
```

**What you should see:** a line with `metrics-api:local`, `Up ...` and
`0.0.0.0:5000->5000/tcp, 0.0.0.0:8000->8000/tcp`.

Now knock on the boxed app, exactly like before (wait about 3 seconds after starting it):

```bash
curl http://localhost:5000/health
curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 900}'
curl -s http://localhost:8000 | grep api_requests_total
```

**What you should see:**

```text
{"status":"healthy"}
{"prediction":1}
# HELP api_requests_total Total API requests
# TYPE api_requests_total counter
api_requests_total{endpoint="/health",method="GET",status="200"} 1.0
api_requests_total{endpoint="/predict",method="POST",status="200"} 1.0
```

The spotter is inside the box too. Run it there:

```bash
docker exec metrics-api python anomaly_detection.py
```

**What you should see:** `Anomaly at index 6: 2.5s (z=3.00)`.

Peek at the app's logbook, then stop and remove the container:

```bash
docker logs metrics-api
docker stop metrics-api
docker rm metrics-api
```

**What you should see:** the logs show the same `Running on ...` lines as Step 5, plus one line
per visit, such as `"GET /health HTTP/1.1" 200 -`. `docker stop` and `docker rm` each print
`metrics-api`.

### Try it yourself

- **Watch a metric climb.** Start the app again (Step 5), knock on `/health` ten times, then run
  `curl -s http://localhost:8000 | grep api_requests_total`. The `/health` number is now 10.0
  (or more).
- **Count predictions separately.** Send three `/predict` requests with different amounts. The
  counter keeps a separate line for `endpoint="/predict"`. That is what the labels are for.
- **Make the weirdos hide each other.** In `anomaly_detection.py`, change the fourth number
  (index 3, a `0.10`) to `3.00` and run it again. You will see only
  `Anomaly at index 3: 3.0s (z=2.22)`. The 2.50 reading is no longer flagged: two big numbers
  stretch the "normal spread", so each looks less weird. Real monitoring tools face this
  problem too, which is why engineers combine several kinds of checks.
- **Move the line.** Put the list back, then change `threshold=2.0` to `threshold=3.0` and run
  it. Now nothing prints, because the 2.50 reading's z-score (3.00) is not *above* 3.0.
- **Box challenge.** Run the container with a different laptop door:
  `docker run -d -p 5050:5000 -p 8000:8000 --name metrics-api metrics-api:local`, then
  `curl http://localhost:5050/health`. The app inside still uses 5000; only the outside door
  changed. Clean up with `docker rm -f metrics-api`.

### If something breaks

- **`(venv)` is missing from your terminal line** → The toolbox is not on. Go into
  `my-chapter-11` and run `source venv/bin/activate` (Windows: `venv\Scripts\activate`).
- **`mkdir: my-chapter-11: File exists`** → You already made it earlier. Just run `cd my-chapter-11`.
- **`error: externally-managed-environment` when you run `pip install`** → The toolbox is not
  on, so pip tried to change your computer's main Python. Switch on the toolbox (Step 2) and run
  Step 3 again.
- **`pip: command not found`** → Use `python -m pip install flask prometheus-client numpy`
  (with the toolbox on).
- **`ModuleNotFoundError: No module named 'flask'` (or `numpy`, or `prometheus_client`)** → The
  helpers are not installed in this toolbox, or the toolbox is off. Switch it on, then redo Step 3.
- **`python: can't open file '.../app_with_metrics.py': [Errno 2] No such file or directory`** →
  You are in a different folder from the file. Run `ls`; if you do not see the file, `cd` into
  `my-chapter-11`, or check you saved the file with exactly that name (not `.py.txt`).
- **`OSError: [Errno 48] Address already in use`** (or `[Errno 98]`, as the program starts) →
  Something already uses door 8000. Usually it is an older run of this app: press Ctrl+C in its
  terminal, or stop the container with `docker rm -f metrics-api`. To see who uses the door on
  Mac/Linux: `lsof -i :8000`.
- **`Address already in use. Port 5000 is in use by another program`** → On a Mac this is
  usually **AirPlay Receiver**, which uses port 5000. Open **System Settings -> General ->
  AirDrop & Handoff** and turn off **AirPlay Receiver**, then start the app again. Otherwise,
  stop the old run of the app (Ctrl+C) or the container (`docker rm -f metrics-api`).
- **`curl: (7) Failed to connect to localhost port 5000` / `Connection refused`** → The app is
  not running. Check Terminal 1 still shows `Running on http://127.0.0.1:5000`. If you closed it,
  start it again (Step 5). For the container, run `docker ps` to check it is `Up`.
- **`curl: command not found`** → On Windows, use `curl.exe` in PowerShell, or Git Bash. You can
  also open the address in your web browser (for the `GET` doors).
- **`415 Unsupported Media Type`** from `/predict` → You left out
  `-H "Content-Type: application/json"`. Copy the whole command again.
- **`400 Bad Request`** from `/predict` → The JSON was mangled, often by Windows quotes. Run the
  command in Git Bash, exactly as written.
- **`grep: command not found`** (Windows PowerShell) → Use Git Bash, or replace `| grep` with
  `| findstr`, e.g. `curl.exe -s http://localhost:8000 | findstr api_requests_total`.
- **The spotter prints nothing** → Check the list still has `2.50` in it and that
  `threshold=2.0`. A typo like `0.250` makes the slow reading look normal.
- **`SyntaxError` or `IndentationError`** → A typo, often a missing comma, quote, bracket, or
  spaces at the start of a line. Compare your file line by line with the finished copy in
  `chapter-11-monitoring`.
- **`Cannot connect to the Docker daemon`** or **`docker: command not found`** → Docker Desktop is
  not running (or not installed). Open it, wait until it says it is running, and try again.
- **`failed to read dockerfile: open Dockerfile: no such file or directory`** → You are not in
  `chapter-11-monitoring`. Run `ls`; you must see `Dockerfile` before `docker build`.
- **`Bind for 0.0.0.0:5000 failed: port is already allocated`** or **`ports are not available`**
  → Door 5000 or 8000 is already used on your laptop: the app from Step 5 is still running
  (press Ctrl+C in Terminal 1), an older container is running (`docker rm -f metrics-api`), or on
  a Mac AirPlay Receiver has port 5000 (see above). Then run `docker run` again.
- **`Conflict. The container name "/metrics-api" is already in use`** → An old container has the
  same name. Remove it with `docker rm -f metrics-api` and run `docker run` again.
- **`curl: (52) Empty reply from server` right after `docker run`** → The app is still starting.
  Wait 3 seconds and try again.

### What you learned in Phase 1

- A running program can keep its own health **metrics**: numbers it tracks over time.
- A **counter** only goes up (a tally of visits); a **histogram** records how long things took.
  **Labels** let one metric keep separate tallies.
- A **separate door** (port 8000) shows those numbers, so a tool like **Prometheus** can read them.
- You used **two terminals**: one to run the program, one to talk to it.
- A simple **anomaly** spotter uses a **z-score** and a **threshold** to point at the strange
  reading, and two weird readings can hide each other.
- You packed the app in a **container** and checked both doors still work. That exact box is what
  goes to the cloud next.

---

## Phase 2 and Phase 3

On your laptop, *you* visited the metrics door. In the cloud, Prometheus visits every copy of
your app every 15 seconds, forever, and in Phase 3 it raises an alert when something looks wrong.

- **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md)
- **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md)

Build the shared platform first: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
Phases 2 and 3 cost money while the platform runs, so destroy it when you finish.

## Where to next

[Chapter 12 — Teach the system to fix itself (AIOps)](../chapter-12-aiops/README.md). Now that
your program can be *watched*, you will build a robot guard that reads these numbers and
*reacts* on its own.
