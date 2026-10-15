# Chapter 12 — Teach the system to fix itself (AIOps)

> Matches **Chapter 12** in the book. This is the gentle on-ramp version.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

In Chapter 11 your program got a fitness watch — it could *count* and *notice* things. But a
watch just shows numbers; *you* still have to look at it.

**AIOps** is the next step: a **smart helper that notices trouble and reacts on its own** —
like a robot night guard who doesn't just spot a problem but also calls for help, turns on more
lights, and writes it all down, without waking you up.

To do that, the helper looks at the computer's vital signs over time — its **CPU** (how hard
the brain is working) and its **memory** (how full its short-term notepad is) — and watches for
two kinds of trouble:

1. A sudden **spike** — one weird reading that jumps way out of line (an **anomaly**).
2. A slow **climb** — the numbers creeping steadily uphill toward danger (a **trend**).

If it sees either, it returns a **WARNING** and a recommended action, and a second part of the
program *acts* on that warning automatically — sending an alert, adding more computers, and
opening a trouble ticket. All hands-free.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **AIOps** — Using AI to help run systems: spotting problems and even fixing them
  automatically.
- **Anomaly** — Something that doesn't fit the normal pattern; an oddity worth a closer look.
- **Trend** — Which way the numbers are heading over time, up or down.
- **CPU / memory** — Two "vital signs" of a computer: how hard its brain is working, and how
  full its short-term notepad is.

## What you will build

- `aiops_engine.py` — a robot guard that reads CPU and memory numbers, spots both spikes and
  uphill climbs, and returns either `WARNING` (with what's wrong and what to do) or `STABLE`.
- `automated_response.py` — the part that takes a `WARNING` and *acts* on it: sends an alert,
  scales up, and opens a ticket (all printed as a demo).

---

## Let's do it, one small step at a time

### Step 1 — Make a folder and go into it

In your **terminal**, type these one at a time:

```bash
mkdir chapter-12-aiops
cd chapter-12-aiops
```

- `mkdir chapter-12-aiops` makes a new **folder**.
- `cd chapter-12-aiops` moves you *into* it.

### Step 2 — Make a clean toolbox (virtual environment)

A **virtual environment** is a clean, private toolbox just for this project. Make one and switch
it on:

```bash
python3 -m venv venv && source venv/bin/activate
```

**What you should see:** your terminal line now starts with `(venv)`.

> **Windows note:** if `source venv/bin/activate` doesn't work, use
> `venv\Scripts\activate` instead.

### Step 3 — Install the helpers

```bash
pip install numpy flask prometheus-client
```

- `pip` **installs** helpers into your toolbox.
- `numpy` does the math (averages and drawing a straight line through the dots). The other two
  are carried over from Chapter 11 so this chapter matches the book.

**What you should see:** lines ending with `Successfully installed ...`.

### Step 4 — Write the robot guard

Make a new file called **`aiops_engine.py`** and type this in:

```python
# aiops_engine.py
import numpy as np

def detect_anomaly(metrics, threshold=2.0):
    mean = np.mean(metrics)
    std = np.std(metrics) or 0.001
    return [
        (i, v, abs(v-mean)/std)
        for i, v in enumerate(metrics)
        if abs(v-mean)/std > threshold
    ]

def analyze_trend(metrics):
    if len(metrics) < 3:
        return 0.0
    x = np.arange(len(metrics))
    slope = np.polyfit(x, metrics, 1)[0]
    return slope

def predict_failure(cpu, mem):
    cpu_anom = detect_anomaly(cpu)
    mem_anom = detect_anomaly(mem)
    cpu_trend = analyze_trend(cpu)
    mem_trend = analyze_trend(mem)

    warnings = []
    if cpu_anom:
        warnings.append(
            f'CPU spike: {cpu_anom[-1][1]:.1f}%'
        )
    if mem_anom:
        warnings.append(
            f'Memory spike: {mem_anom[-1][1]:.1f}%'
        )
    if cpu_trend > 1.5:
        warnings.append(
            f'CPU trend up: {cpu_trend:.1f}%/reading'
        )
    if mem_trend > 1.5:
        warnings.append(
            f'Mem trend up: {mem_trend:.1f}%/reading'
        )

    if warnings:
        return {'status':'WARNING',
            'warnings': warnings,
            'action':'Scale up now'}
    return {'status':'STABLE','warnings':[],
        'action':'No action needed'}

# Simulate system metrics over time:
cpu = [45,47,46,48,50,52,55,60,65,
       70,72,75,80,85,91]
mem = [60,61,60,62,63,64,65,66,68,
       70,72,75,80,85,92]

result = predict_failure(cpu, mem)
print(f'Status: {result["status"]}')
for w in result['warnings']:
    print(f'  WARNING: {w}')
print(f'Action: {result["action"]}')
```

**What the key lines say, in plain words:**

- `detect_anomaly(...)` — The **spike** spotter. For each reading it works out a **z-score**
  (how surprising the number is — how far it sits from normal). If the z-score is bigger than
  the **threshold** of `2.0`, that reading is a spike. (`std ... or 0.001` is a tiny safety
  trick so the math never divides by zero.)
- `analyze_trend(...)` — The **climb** reader. It draws the straightest possible line through
  all the dots (this is called *linear regression*) and reports the **slope** — how steep that
  line is. A positive slope means the numbers are heading *uphill*.
- `predict_failure(cpu, mem)` — The brain. It runs both checks on the CPU numbers and the
  memory numbers. It collects a list of `warnings`:
  - if there's a spike, add a "spike" warning;
  - if the slope is steeper than `1.5` (climbing more than 1.5 each reading), add a "trend up"
    warning.
- If there are any warnings at all, it returns `WARNING` and the action `'Scale up now'`
  (meaning: add more computers to share the load). If everything is calm, it returns `STABLE`
  and `'No action needed'`.
- The `cpu = [...]` and `mem = [...]` lists are pretend readings that creep up into the 90s, so
  the guard *will* notice trouble.

Run it:

```bash
python aiops_engine.py
```

(On Mac/Linux you can also type `python3`.)

**What you should see:** something like:

```
Status: WARNING
  WARNING: CPU trend up: 3.3%/reading
  WARNING: Mem trend up: 2.3%/reading
Action: Scale up now
```

The guard noticed the numbers climbing and said "Scale up now" all by itself. 🎉

### Step 5 — Write the part that acts on the warning

Spotting trouble is half the job. Now the helper should *do* something. Make a new file called
**`automated_response.py`**:

```python
# automated_response.py
from aiops_engine import predict_failure

def automated_response(cpu, mem):
    result = predict_failure(cpu, mem)
    if result['status'] == 'WARNING':
        print('=== AIOps ALERT ===')
        for w in result['warnings']:
            print(f'  {w}')
        print('Triggering automated response:')
        print('  - Alert sent to Slack')
        print('  - Kubernetes pods scaled up')
        print('  - Incident ticket opened')
    else:
        print('All systems stable.')

cpu_now = [45,47,48,52,60,72,85,91,95,98]
mem_now = [60,62,63,66,72,80,88,92,95,97]
automated_response(cpu_now, mem_now)
```

**What the key lines say, in plain words:**

- `from aiops_engine import predict_failure` — Borrow the brain from the other file, so we don't
  have to rewrite the thinking. (This is why both files must sit in the *same folder*.)
- `automated_response(cpu, mem)` — Run the brain on fresh readings. If the answer is `WARNING`:
  - print a big `=== AIOps ALERT ===`,
  - list exactly what's wrong,
  - then print the automatic fixes it would do: send an alert to **Slack** (a chat app), scale
    up the **Kubernetes** pods (add more app copies), and open an **incident ticket** (so humans
    have a record). These are printed as a demo, not really sent.
- If everything is calm, it just prints `All systems stable.`
- `cpu_now = [...]` and `mem_now = [...]` are fresh pretend readings that climb up high, so the
  alert fires.

Run it (make sure you're in the same folder as `aiops_engine.py`):

```bash
python automated_response.py
```

**What you should see:** something like:

```
=== AIOps ALERT ===
  CPU trend up: 6.1%/reading
  Mem trend up: 4.3%/reading
Triggering automated response:
  - Alert sent to Slack
  - Kubernetes pods scaled up
  - Incident ticket opened
```

That's a program reacting to its own trouble, hands-free. 🎉

---

## Try it yourself (mini challenges)

- 🔧 **Make it calm down.** In `aiops_engine.py`, change the `cpu` and `mem` lists to numbers
  that stay flat (for example, all `50`s). Run it again — now it should say `Status: STABLE`.
- 🔧 **Change the line so it triggers (or doesn't).** The trend warning fires when the slope is
  above `1.5`. Change `if cpu_trend > 1.5` to `if cpu_trend > 0.1` and watch even a gentle climb
  set off a warning. Then try `> 10.0` and watch the warning disappear.
- 🔧 **Force a spike.** In the `cpu` list, change one middle number to something huge like `200`.
  Run it and watch a `CPU spike` warning appear (that's the anomaly spotter at work).
- 🔧 **Read the response only.** In `automated_response.py`, change `cpu_now` and `mem_now` to
  flat, low numbers. Run it and confirm it prints `All systems stable.` instead of the alert.

## If something breaks

- **`(venv)` is missing from your terminal line** → The toolbox isn't on. Run
  `source venv/bin/activate` (or `venv\Scripts\activate` on Windows), inside the
  `chapter-12-aiops` folder.
- **`ModuleNotFoundError: No module named 'numpy'`** → The helper isn't installed in this
  toolbox. Redo Step 3: `pip install numpy flask prometheus-client`.
- **`ModuleNotFoundError: No module named 'aiops_engine'`** → `automated_response.py` can't find
  the brain. Both files must be in the *same folder*, and you must run the command from inside
  that folder.
- **It always says `STABLE` even though you expect a warning** → Your numbers may not be
  climbing fast enough to pass the `1.5` slope line, and none are weird enough to be a spike.
  Use bigger jumps, or lower the `1.5` threshold to test.
- **`SyntaxError`** → A typo. Most often a missing comma, quote `'`, or parenthesis `)`. Compare
  your file to the example line by line.

## What you just learned

- **AIOps** means a program that *notices* trouble and *reacts* on its own, not just shows you
  numbers.
- Two kinds of trouble: a sudden **spike** (an anomaly, caught with a z-score and threshold) and
  a slow **climb** (a trend, caught by drawing a line and reading its slope).
- One file can **borrow** functions from another (`import`) so the thinking is written once and
  reused.
- The reaction (alert, scale up, open a ticket) can be **automatic** — no human pressing
  buttons.

## Where to next

➡ [Chapter 13 — Notice when the world changes (Drift & retraining)](../chapter-13-retraining).
Your system can watch its machines now; next it learns to notice when the *data* itself has
quietly changed.
