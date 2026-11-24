# Chapter 12 — Teach the system to fix itself (AIOps)

> Matches Chapter 12 in the book.

**Labels:** Phase 1 runs free on your laptop · Phases 2 and 3 need an account that may cost money · Needs the internet (Phases 2 and 3)

---

## The platform you are building

In this chapter you build an **AIOps / self-healing operations platform**: a robot guard that
reads a system's health numbers, spots trouble early, and fixes the simple problems by itself,
within strict limits. Big companies run thousands of programs, far too many for people to watch
by hand, so they pay for systems that notice problems and react in seconds instead of waiting for
a human to wake up. That means fewer outages, smaller cloud bills and calmer on-call nights. The
people who build these systems are called **Site Reliability Engineers (SREs)**, **AIOps
Engineers**, **Platform Engineers** and **MLOps Engineers**.

## How this builds on Chapter 11

In Chapter 11 your app got a fitness watch: it kept its own metrics, Prometheus collected them,
and alert rules told a *human* when something looked wrong. But an alert still needs a person to
read it and act. This chapter adds the part that acts.

What carries over:

- **Chapter 11's idea of a z-score:** the guard's spike spotter is the same math as
  `anomaly_detection.py`.
- **Chapter 11's `metrics-api` app:** in the cloud it is the "patient" the guard watches.
  `deploy.sh 2b` and `deploy.sh 3` check it is running, and deploy Chapter 11's Phase 2B for you
  if it is not.
- **Chapter 10's cluster, Helm chart and Prometheus:** the guard asks the platform's Prometheus
  for `metrics-api`'s CPU and memory over the last 15 minutes. (These numbers come from the
  cluster's built-in collectors, not from the app's own `api_` counters.)

What is new:

- A **trend** reader: it draws a straight line through the numbers and asks "are they climbing?"
- A **decision**: `WARNING` plus an action, or `STABLE`.
- An **automatic response**: on your laptop it prints what it would do; in Phase 3 it really adds
  copies of `metrics-api`, with tightly limited permissions.

```text
Your platform so far

  Chapter 10 (platform)          Chapter 11 (watched)          Chapter 12 (new: acts)
  +------------------------+     +----------------------+
  | EKS cluster, Helm chart|     | metrics-api          |
  | Prometheus  <----------|-----| (CPU, memory, api_*) |
  |   |                    |     | alert rules          |
  |   +--------------------|-----|----------------------|--->  aiops guard (CronJob)
  | platform ALB           |     +----------^-----------+       reads CPU and memory,
  +------------------------+                |                   decides WARNING / STABLE,
                                            +-------------------adds a copy (Phase 3 only)
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **Phase 1 — Build it on your laptop** | Your computer | Write the robot guard and the automatic response, then pack them in a container | Free |
| **Phase 2 — Promote it to the cloud** | AWS EKS | 2A: run the laptop demo once as a Job. 2B: a guard on a schedule that reads real Prometheus numbers, report only | Costs money while the platform runs. Destroy it when done. |
| **Phase 3 — Run it like a Fortune 500 company** | AWS EKS | Let the guard really scale `metrics-api`, with least-privilege permissions, a hard cap, and an alert that watches the watcher | Costs money while the platform runs. Destroy it when done. |

## New words

Look up anything else in the [GLOSSARY](../GLOSSARY.md).

- **AIOps** — Using data and AI to help run computer systems: spotting problems and even fixing
  them automatically. Short for "AI for IT operations".
- **Self-healing** — A system that repairs simple problems by itself, like adding a copy when it is busy.
- **Anomaly / spike** — One reading that jumps far out of line with the others.
- **Trend** — Which way the numbers are heading over time, up or down.
- **Slope** — How steep a line is. A slope of 3 means "goes up by 3 for every step to the right".
- **Linear regression** — Drawing the straightest line you can through a cloud of dots.
- **CPU / memory** — Two vital signs of a computer: how hard its brain is working, and how full
  its short-term notepad is.
- **Scale up** — Add more copies of a program so they can share the work.
- **Import** — Borrowing code from another Python file, so you write it once and reuse it.

---

## Phase 1 — Build it on your laptop

**The big idea, in plain words.** A fitness watch just shows numbers; *you* still have to look
at it. **AIOps** is the next step: a helper that notices trouble and reacts on its own, like a
robot night guard who does not just spot a problem but also calls for help, turns on more
lights, and writes it all down, without waking you up.

The guard watches a computer's **CPU** and **memory** readings over time and looks for two kinds
of trouble:

1. A sudden **spike**: one weird reading that jumps out of line (an **anomaly**).
2. A slow **climb**: the numbers creeping steadily uphill toward danger (a **trend**).

If it sees either, it returns a **WARNING** and a recommended action, and a second program
*acts* on that warning: sending an alert, adding more computers, and opening a trouble ticket.

You will build:

- `aiops_engine.py` — the robot guard: reads CPU and memory numbers, spots spikes and climbs, and
  returns `WARNING` (with what is wrong and what to do) or `STABLE`.
- `automated_response.py` — the part that takes a `WARNING` and acts on it (printed as a demo).

The course repo already has finished copies in this `chapter-12-aiops` folder. You will type your
own in a practice folder.

### Step 1 — Make a practice folder and go into it

Open your **terminal** in the **top folder of the course repo** (the one that holds
`chapter-01-setup`, `chapter-02-data` and the others), then type:

```bash
mkdir my-chapter-12
cd my-chapter-12
```

- `mkdir my-chapter-12` makes a new, empty **folder** for your typing.
- `cd my-chapter-12` moves you *into* it.

**What you should see:** no message at all. That is normal.

### Step 2 — Make a clean toolbox (virtual environment)

```bash
python3 -m venv venv
source venv/bin/activate
```

- `python3 -m venv venv` builds a clean, private toolbox in a folder called `venv`.
- `source venv/bin/activate` switches it on.

**What you should see:** your terminal line now starts with `(venv)`.

> **Windows note:** use `python -m venv venv`, then `venv\Scripts\activate` in PowerShell (or
> `source venv/Scripts/activate` in Git Bash).

### Step 3 — Install the helpers

```bash
pip install numpy flask prometheus-client
```

- `numpy` does the math (averages, and drawing a straight line through the dots).
- `flask` and `prometheus-client` are not used by this chapter's two files. They are carried
  over from Chapter 11 so your toolbox matches the book.

**What you should see:** some download lines, then a line starting with `Successfully installed`.

### Step 4 — Write the robot guard

Make a new file called **`aiops_engine.py`** in `my-chapter-12` and type this in:

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

- `detect_anomaly(...)` — The **spike** spotter, the same idea as Chapter 11. For each reading it
  works out a **z-score** (how many "normal spreads" it sits from the average). Above the
  **threshold** of `2.0` means "spike". (`np.std(metrics) or 0.001` is a safety trick: if every
  number is the same, the spread is 0, and dividing by 0 would crash, so it uses 0.001 instead.)
- `analyze_trend(...)` — The **climb** reader. `np.polyfit(x, metrics, 1)` draws the straightest
  possible line through the dots (**linear regression**) and `[0]` takes its **slope**. A
  positive slope means the numbers are heading uphill. With fewer than 3 readings it does not
  guess and returns `0.0`.
- `predict_failure(cpu, mem)` — The brain. It runs both checks on the CPU numbers and on the
  memory numbers and collects a list of `warnings`:
  - a spike adds a "spike" warning (`[-1][1]` picks the value of the *last* spike found);
  - a slope steeper than `1.5` (climbing more than 1.5 points per reading) adds a "trend up" warning.
- Any warnings at all -> `WARNING` and the action `'Scale up now'` (add more copies to share the
  load). Otherwise -> `STABLE` and `'No action needed'`.
- `cpu = [...]` and `mem = [...]` are pretend readings that creep up into the 90s, so the guard
  *will* notice trouble.

Run it:

```bash
python aiops_engine.py
```

**What you should see:**

```text
Status: WARNING
  WARNING: Memory spike: 92.0%
  WARNING: CPU trend up: 3.4%/reading
  WARNING: Mem trend up: 2.0%/reading
Action: Scale up now
```

The guard noticed both climbs, and that the last memory reading (92) jumped further than usual,
and said "Scale up now" by itself. (If a printed book shows slightly different numbers, trust
what your computer prints for this exact code.)

### Step 5 — Write the part that acts on the warning

Spotting trouble is half the job. Now the helper should *do* something. Make a new file called
**`automated_response.py`** in the **same folder**:

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

- `from aiops_engine import predict_failure` — Borrow the brain from the other file, so the
  thinking is written once. Python looks for `aiops_engine.py` in the same folder as this file.
- `automated_response(cpu, mem)` — Run the brain on fresh readings. If the answer is `WARNING`:
  print a big `=== AIOps ALERT ===`, list what is wrong, then print the automatic fixes: an alert
  to **Slack** (a team chat app), scale up the **Kubernetes** pods (add app copies), and open an
  **incident ticket** (a written record for humans). These are printed as a demo, not really sent.
- If everything is calm, it prints `All systems stable.`
- `cpu_now` and `mem_now` are fresh pretend readings that climb fast, so the alert fires.

Run it (from `my-chapter-12`, where both files are):

```bash
python automated_response.py
```

**What you should see:**

```text
Status: WARNING
  WARNING: Memory spike: 92.0%
  WARNING: CPU trend up: 3.4%/reading
  WARNING: Mem trend up: 2.0%/reading
Action: Scale up now
=== AIOps ALERT ===
  CPU trend up: 6.9%/reading
  Mem trend up: 4.7%/reading
Triggering automated response:
  - Alert sent to Slack
  - Kubernetes pods scaled up
  - Incident ticket opened
```

**Why are the first five lines there?** When Python *imports* a file, it runs every line in it
that is not inside a function, including the demo at the bottom of `aiops_engine.py`. So you
first see the engine's own demo report, then the alert for the fresh `cpu_now` and `mem_now`
readings. That is a real lesson: code at the bottom of a file runs whenever someone imports it.
(The cloud version of the guard, `aiops_watcher.py`, hides those demo lines for this reason.)

That is a program reacting to its own trouble, hands-free.

### Step 6 — Pack it in a container

In the cloud, the guard runs as a container, so let's check the box works on your laptop first.
This program is not a web server: it starts, prints its report and stops. So there are no ports
to open and nothing to `curl`; you just run the box and read what it prints.

The finished chapter folder has the recipe (`Dockerfile`), the shopping list
(`requirements.txt`), your two files, and one more file the cloud needs, `aiops_watcher.py`
(you meet it in Phase 2). Make sure **Docker Desktop is open and running**, then go there (from
your `my-chapter-12` folder):

```bash
cd ../chapter-12-aiops
ls
```

**What you should see:** a list that includes `Dockerfile`, `requirements.txt`,
`aiops_engine.py`, `automated_response.py`, `aiops_watcher.py`, `README.md` and a `cloud` folder.

**What the `Dockerfile` says, in plain words:** start from a small box with Python 3.11; install
`numpy` (the only helper these files need); copy in the three Python files; switch to a plain,
non-boss user (`appuser`); and when the box starts, run `python automated_response.py`.

Build the image:

```bash
docker build -t aiops:local .
```

**What you should see:** steps scrolling by, ending with a line like
`naming to docker.io/library/aiops:local` and no errors.

Run it:

```bash
docker run --rm aiops:local
```

- `--rm` deletes the container as soon as it finishes, so nothing is left lying around.

**What you should see:** exactly the same 12 lines as Step 5, starting with `Status: WARNING`
and ending with `- Incident ticket opened`. Then you get your terminal back, because the program
finished.

You can tell the box to run a different command instead of its default one:

```bash
docker run --rm aiops:local python aiops_engine.py
```

**What you should see:** only the engine's 5-line report from Step 4.

### Try it yourself

Do these in your `my-chapter-12` folder (with `(venv)` on).

- **Make it calm down.** In `aiops_engine.py`, change both lists to flat numbers, for example
  `cpu = [50,50,50,50,50,50,50,50,50,50]` and the same for `mem`. Run it: now it says
  `Status: STABLE` and `Action: No action needed`. (This is when the `or 0.001` trick saves you:
  the spread of identical numbers is 0.)
- **Move the trend line.** Put the lists back. Change `if cpu_trend > 1.5` to
  `if cpu_trend > 10.0` and run it. The `CPU trend up` line disappears, but the status is still
  `WARNING`, because memory is still complaining. One warning is enough to act.
- **Force a spike.** In the `cpu` list, change the seventh number (`55`) to `200`. Run it: a new
  line `WARNING: CPU spike: 200.0%` appears. That is the anomaly spotter at work.
- **Make the response calm.** In `automated_response.py`, change `cpu_now` and `mem_now` to flat,
  low numbers, like ten `20`s and ten `30`s. Run it: after the engine's own demo report, the last
  line is `All systems stable.`
- **Box challenge.** Change a number in the course folder's `automated_response.py`, run
  `docker run --rm aiops:local` and notice nothing changed. Now run `docker build -t aiops:local .`
  again and rerun. The box only contains what was copied in when it was built. Put the number back
  afterwards.

### If something breaks

- **`(venv)` is missing from your terminal line** → The toolbox is not on. Go into
  `my-chapter-12` and run `source venv/bin/activate` (Windows: `venv\Scripts\activate`).
- **`mkdir: my-chapter-12: File exists`** → You made it earlier. Just run `cd my-chapter-12`.
- **`error: externally-managed-environment` from `pip install`** → The toolbox is not on.
  Switch it on (Step 2), then redo Step 3.
- **`pip: command not found`** → Use `python -m pip install numpy flask prometheus-client`.
- **`ModuleNotFoundError: No module named 'numpy'`** → numpy is not installed in this toolbox,
  or the toolbox is off. Switch it on, then redo Step 3.
- **`ModuleNotFoundError: No module named 'aiops_engine'`** → `automated_response.py` cannot find
  the brain. Both files must be in the *same folder*, and the engine must be saved as exactly
  `aiops_engine.py` (not `aiops-engine.py` or `aiops_engine.py.txt`). Run `ls` to check.
- **`python: can't open file ... No such file or directory`** → You are in a different folder from
  the file. `cd` into `my-chapter-12` and run `ls`.
- **`ImportError: cannot import name 'predict_failure'`** → The name is misspelled in one of the
  two files. It must be `predict_failure` in both.
- **It always says `STABLE` when you expect a warning** → Your numbers may not climb fast enough
  to pass the `1.5` slope line, and none is weird enough to be a spike. Use bigger jumps.
- **`SyntaxError` or `IndentationError`** → A typo, often a missing comma, quote, bracket, or
  spaces at the start of a line. Compare with the finished copy in `chapter-12-aiops`.
- **`Cannot connect to the Docker daemon`** or **`docker: command not found`** → Docker Desktop
  is not running (or not installed). Open it, wait until it is running, try again.
- **`failed to read dockerfile: open Dockerfile: no such file or directory`** → You are not in
  `chapter-12-aiops`. Run `ls`; you must see `Dockerfile` first.
- **`COPY failed: ... aiops_watcher.py: not found`** → You tried to build from your practice
  folder, which does not have `aiops_watcher.py`. Build from `chapter-12-aiops`.
- **`Unable to find image 'aiops:local' locally`** → The build did not finish. Run
  `docker build -t aiops:local .` again and check it ends with no errors.

### What you learned in Phase 1

- **AIOps** means a program that *notices* trouble and *reacts* on its own, instead of only
  showing you numbers.
- Two kinds of trouble: a sudden **spike** (caught with a z-score and a threshold) and a slow
  **climb** (caught by drawing a line and reading its slope).
- One file can **import** another, so the thinking is written once and reused, and importing
  runs the other file's top-level code.
- The reaction (alert, scale up, open a ticket) can be **automatic**.
- You packed the guard in a **container**. A program that runs and stops (a batch job) is boxed
  the same way as a web app, it just has no ports.

---

## Phase 2 and Phase 3

On your laptop the guard read made-up numbers and only *printed* what it would do. In the cloud
it reads **real** CPU and memory numbers for Chapter 11's `metrics-api` from Prometheus, on a
schedule, and in Phase 3 it really adds copies, with permission to touch only that one app.

- **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md)
- **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md)

Build the shared platform first: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
Phases 2 and 3 cost money while the platform runs, so destroy it when you finish.

## Where to next

[Chapter 13 — Notice when the world changes (Drift and retraining)](../chapter-13-retraining/README.md).
Your system can watch and heal its machines now; next it learns to notice when the *data* itself
has quietly changed.
