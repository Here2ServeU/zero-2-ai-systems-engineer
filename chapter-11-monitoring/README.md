# Chapter 11 — Watch your program's health (Monitoring)

> Matches **Chapter 11** in the book. This is the gentle on-ramp version.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

Imagine your program wears a **fitness watch**. The watch doesn't *do* the running — it just
quietly counts things while you run: your heartbeats, your steps, how fast you went. Later you
glance at the watch and instantly know how you're doing.

We want the same thing for a running program. While our program answers visitors, we want it to
quietly keep a few numbers on the side:

- How many times was I visited?
- How long did each visit take?

Those numbers are called **metrics** (numbers you track over time). Watching them is called
**monitoring** (also "observability"). Once you can see the numbers, you can spot trouble early
— like noticing your heart rate is way too high *before* you collapse.

In this chapter you'll do two small things:

1. Run a little web program that **counts its own visits and times them**.
2. Run a tiny **spotter** that looks at a list of timing numbers and points out the one weird,
   slow one (an **anomaly**).

Small on purpose, like always.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Metric** — A number you track over time, like "requests per minute" or "errors."
- **Monitoring / observability** — Watching your running program's health so you notice
  problems early.
- **Prometheus** — A tool that collects and stores those metrics (think of it as a clipboard
  collector that comes by and copies down your numbers).
- **Anomaly** — Something that doesn't fit the normal pattern; an oddity worth a closer look.

## What you will build

- `app_with_metrics.py` — a small web program (an **API**) that, while it answers people, also
  keeps a tally of how many visits it got and how long each one took. It shares those numbers
  on a separate door so a clipboard tool can read them.
- `anomaly_detection.py` — a spotter that reads a list of timing numbers and prints out the one
  that is strangely slow.

---

## Let's do it, one small step at a time

### Step 1 — Make a folder and go into it

In your **terminal** (the text window from Chapter 01), type these one at a time:

```bash
mkdir chapter-11-monitoring
cd chapter-11-monitoring
```

- `mkdir chapter-11-monitoring` makes a new **folder**.
- `cd chapter-11-monitoring` moves you *into* that folder, so your work lands there.

### Step 2 — Make a clean toolbox (virtual environment)

A **virtual environment** is a clean, private toolbox just for this project, so its tools don't
bump into anything else on your computer. Make one and switch it on:

```bash
python3 -m venv venv && source venv/bin/activate
```

- `python3 -m venv venv` builds the toolbox in a folder called `venv`.
- `source venv/bin/activate` switches it on.

**What you should see:** your terminal line now starts with `(venv)`. That means the toolbox is
on.

> **Windows note:** if `source venv/bin/activate` doesn't work, use
> `venv\Scripts\activate` instead.

### Step 3 — Install the helpers

```bash
pip install flask prometheus-client numpy
```

- `pip` is the tool that **installs** helpers into your toolbox.
- `flask` builds tiny web programs. `prometheus-client` keeps the metrics. `numpy` does the
  math for the spotter.

**What you should see:** several lines ending with `Successfully installed ...`.

### Step 4 — Write the web program that watches itself

Make a new file called **`app_with_metrics.py`** and type this in:

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
- `REQUEST_COUNT = Counter(...)` — Make a **counter**: a tally that only goes *up*, like a
  clicker you press each time someone walks through a door. This one counts every visit.
- `REQUEST_LATENCY = Histogram(...)` — Make a **histogram**: a chart that records *how long*
  things took (this many visits took half a second, this many took two seconds).
- `start_http_server(8000)` — Open a **second door** on **port** 8000 just for the numbers. A
  port is a numbered window programs use to talk. This is the door Prometheus reads from.
- `@app.route('/health')` — Make a `/health` door. When you knock, it replies "I'm healthy!"
  and adds one to the counter.
- `@app.route('/predict', ...)` — Make a `/predict` door. You send it an amount of money. If
  it's over 800 it answers `1` (suspicious), otherwise `0` (fine). `time.time()` before and
  after measures how long that took, and `.observe(latency)` writes that time onto the
  histogram.
- `app.run(... port=5000)` — Open the main door (the website itself) on **port** 5000.

So your program has **two doors**: port 5000 for visitors, and port 8000 just for its own
health numbers.

### Step 5 — Start the program (Terminal 1)

In your terminal (the one with `(venv)`), run:

```bash
python app_with_metrics.py
```

(On Mac/Linux you can also type `python3`.)

**What you should see:** a couple of lines ending with something like
`Running on http://0.0.0.0:5000`. The program is now awake and listening. **Leave this terminal
running** — do not close it. This is **Terminal 1**.

### Step 6 — Open a second terminal and read the numbers (Terminal 2)

Your program is busy holding both doors open in Terminal 1, so you need a *second* terminal to
talk to it.

- In VS Code, click **Terminal → New Terminal** again. A fresh panel opens. This is
  **Terminal 2**.
- Move into the same folder and switch the toolbox on again:

  ```bash
  cd chapter-11-monitoring
  source venv/bin/activate
  ```

Now knock on the numbers door (port 8000):

```bash
curl http://localhost:8000
```

- `curl` is a tool that knocks on a web door from the terminal.
- Port 8000 is the door we opened just for the health numbers.

**What you should see:** a long block of plain text — the raw metrics. Look for the line
`api_requests_total`. That's your counter. Right now it may be small or `0.0` because nobody
has visited the real doors yet. That's fine.

### Step 7 — Make the counter go up

Still in **Terminal 2**, knock on the `/health` door a few times:

```bash
curl http://localhost:5000/health
```

**What you should see:** `{"status":"healthy"}` each time. Run it three or four times. Then read
the numbers again:

```bash
curl http://localhost:8000
```

**What you should see:** the number next to `api_requests_total` is now **bigger**. You just
watched a metric climb. That is monitoring.

### Step 8 — Run the anomaly spotter

The counter is great, but we also want to *notice* a weird, slow visit hiding in a pile of
normal ones. Make a new file called **`anomaly_detection.py`**:

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

- `latencies = [...]` — A list of timing numbers (how long visits took). Most are tiny, around
  0.10 seconds, but one is a huge **2.50** — the troublemaker.
- `mean = np.mean(data)` — Find the **average**, the normal middle of all the numbers.
- `std = np.std(data)` — Measure how *spread out* the numbers usually are.
- `if abs(value - mean) > threshold * std` — For each number, ask: is it surprisingly far from
  normal? The amount of surprise is called a **z-score**. The **threshold** (the pass/fail
  line) is `2.0`. A z-score above 2.0 means "whoa, that's weird" — flag it.
- The `print(...)` line shows the weird one: the 2.50-second visit, with its z-score.

Run it (Terminal 2 is fine):

```bash
python anomaly_detection.py
```

**What you should see:**

```
Anomaly at index 6: 2.5s (z=2.83)
```

The spotter found the one slow visit all by itself. 🎉

### Step 9 — Stop the program when you're done

Go back to **Terminal 1** and press **Ctrl+C**. That stops the web program and frees up the two
doors.

---

## Try it yourself (mini challenges)

- 🔧 **Watch a metric climb.** With the program running (Terminal 1), knock on
  `curl http://localhost:5000/health` ten times in Terminal 2, then read
  `curl http://localhost:8000` and find the new, bigger `api_requests_total` number.
- 🔧 **Time a real prediction.** In Terminal 2, send the `/predict` door an amount:
  `curl -X POST http://localhost:5000/predict -H "Content-Type: application/json" -d '{"amount": 900}'`.
  You should get `{"prediction":1}`. Then read the metrics and look for
  `api_request_duration_seconds`.
- 🔧 **Make a second anomaly.** In `anomaly_detection.py`, change one of the `0.10` numbers to
  `3.00` and run it again. Now *two* readings get flagged.
- 🔧 **Move the line.** Change `threshold=2.0` to `threshold=3.0` and run it. The 2.50 reading
  may no longer be flagged, because you raised the bar for "weird."

## If something breaks

- **`(venv)` is missing from your terminal line** → The toolbox isn't on. Run
  `source venv/bin/activate` (or `venv\Scripts\activate` on Windows) again, and make sure
  you're inside the `chapter-11-monitoring` folder.
- **`ModuleNotFoundError: No module named 'flask'` (or `numpy`)** → The helpers aren't
  installed in this toolbox. Redo Step 3: `pip install flask prometheus-client numpy`.
- **`Address already in use` on port 5000 or 8000** → A program is already using that door.
  Close any old run of `app_with_metrics.py` (press Ctrl+C in its terminal), then start again.
- **`curl: command not found`** → `curl` isn't installed. On Windows, use PowerShell's
  `curl.exe`, or open the address `http://localhost:8000` in your web browser instead.
- **`curl` says "Connection refused"** → The program isn't running. Check Terminal 1 — it
  should still show `Running on http://0.0.0.0:5000`. If you closed it, start it again.

## What you just learned

- A running program can keep its own health **metrics** — numbers it tracks over time.
- A **counter** only goes up (a tally of visits); a **histogram** records how long things took.
- You can open a **separate door** (a port) just for those numbers, so a tool like
  **Prometheus** can read them.
- You used **two terminals**: one to run the program, one to talk to it and read its numbers.
- A simple **anomaly** spotter can automatically point at the one strange reading using a
  **z-score** and a **threshold**.

## Where to next

➡ [Chapter 12 — Teach the system to fix itself (AIOps)](../chapter-12-aiops). Now that your
program can *notice* trouble, you'll teach it to *react* on its own.
