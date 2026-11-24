# Chapter 13 — Notice when the world changes (Drift & retraining)

> Matches Chapter 13 in the book.

**Labels:** Phase 1 runs free on your laptop · Phases 2 and 3 need an account that may cost money · Needs the internet (Phases 2 and 3)

---

## The big idea (in plain words)

A **model** (the pattern-spotter you trained back in Chapter 03) learns from examples it sees
*today*. But the world keeps moving. Prices go up. People's habits change. Yesterday's "normal"
slowly becomes today's "unusual."

When the world changes so much that the model's old lessons stop fitting, we call it **drift**,
like a **paper map going out of date**. The roads on the map were correct once, but new roads
got built and old ones closed, so the map now leads you astray. The map didn't get *worse*; the
world moved on without it.

The fix is **retraining**: teaching the model again on **fresh examples**, the same way you'd
buy an updated map. But a new map could have mistakes too, so we **quiz** every new model
before we trust it.

## The platform you are building

In this chapter you build an **MLOps continuous-training platform**: a system that keeps
checking whether the world has drifted, retrains the model on a schedule, quizzes the new model,
and keeps every approved model on a numbered shelf called a **model registry**. Companies that
use AI for money decisions (banks, shops, insurers, delivery apps) pay for this because a model
that quietly goes stale can lose millions before anyone notices. The people who build these
platforms are called **MLOps Engineers**, **ML Platform Engineers** and **Machine Learning
Engineers**.

## How this builds on Chapter 12

In Chapters 11 and 12 you taught the platform to watch an app's health numbers and react when
they looked wrong. This chapter watches something different: **the data itself**. An app can be
perfectly healthy (fast, no errors) and still give bad answers, because its model is out of
date.

What carries over:

- **Chapter 04's MLflow:** the same "tidy notebook" for experiments, now also used as a
  **registry** of approved models.
- **Chapter 09's GitHub Actions:** this folder's [`retrain.yml`](retrain.yml) is a workflow that
  would run retraining every Monday at 2 a.m. The cloud track uses the same schedule.
- **Chapter 12's scheduled job idea:** in the cloud, retraining runs as a Kubernetes **CronJob**
  (a task on a timetable), from the same shared Helm chart Chapter 12's guard uses.
- **Chapter 11's alert rules:** in Phase 3, Prometheus warns a human when a new model fails its
  quiz.
- **Chapter 10's platform:** the EKS cluster, the shared Helm chart, and two things its
  Terraform made just for this chapter: an **S3 bucket** for model files, and **Pod Identity**
  permissions for the `mlflow` and `retrain` service accounts (no AWS keys anywhere).

What is new:

- A **drift detector** that compares old data with new data, using math.
- A **quality gate**: a new model is only kept if it catches enough fraud.
- A **model registry** with numbered versions (`FraudDetectionModel` v1, v2, ...).

```text
Your platform so far

  Chapter 10 (platform)        Chapters 11-12 (watch + act)    Chapter 13 (new: keep models fresh)
  +-------------------------+  +--------------------------+    +-------------------------------+
  | EKS cluster, Helm chart |  | metrics, alert rules     |    | drift check                   |
  | Prometheus, ALB         |  | a guard on a schedule    |    |   -> retrain                  |
  | S3 bucket for MLflow  <-|--|--------------------------|----|   -> quiz (recall >= 0.70)    |
  | Pod Identity roles      |  +--------------------------+    |   -> MLflow model registry    |
  +-------------------------+                                  +-------------------------------+
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **Phase 1 — Build it on your laptop** (this page) | Your computer | Write the drift detector and the retraining helper, look inside the model registry, then pack it all in a container | Free |
| **Phase 2 — Promote it to the cloud** ([cloud/README.md](cloud/README.md)) | AWS EKS | **2A:** run the laptop routine once as a Job. **2B:** a shared MLflow server plus retraining every Monday, with Helm | Costs money while the platform runs. Destroy it when done. |
| **Phase 3 — Run it like a Fortune 500 company** ([cloud/PRODUCTION.md](cloud/PRODUCTION.md)) | AWS EKS | Model files in S3 with no keys, automatic rollback, alerts when a model is rejected, a runbook | Costs money while the platform runs. Destroy it when done. |

You can stop after Phase 1 and still have learned the whole idea.

## New words

Look up anything else in the [GLOSSARY](../GLOSSARY.md).

- **Drift** — When the real world slowly changes so your model's old training no longer fits.
- **Baseline** — The "old normal" data the model learned from. We compare new data against it.
- **KS-test** — A math test that checks whether two piles of numbers look different.
- **p-value** — A number from 0 to 1 that the test gives back. A *tiny* p-value means "these two
  piles really are different."
- **Retraining** — Teaching the model again on fresh data when drift shows up.
- **Recall** — Out of all the real fraud, how much the model caught. (Higher is better.)
- **Quality gate** — A pass/fail line a new model must clear before it is kept.
- **MLflow** — A tool that keeps a tidy notebook of every experiment and model.
- **Model registry** — MLflow's shelf of *approved* models, each with a version number.
- **Exit code** — A number a program leaves behind when it ends: `0` means "all good", anything
  else means "something failed".

## What you will build

- `drift_detector.py` — compares a **baseline** (old, normal data) with **current** (fresh)
  data and prints whether drift was detected.
- `retrain_pipeline.py` — retrains a model on fresh data, scores it on **recall**, and only
  registers ("promotes") it if recall clears a quality line. Otherwise it rejects it and exits
  with a failure code, so an automatic build system would stop.
- A **container** that runs both, the same way the cloud will run them.

---

## Phase 1 — Build it on your laptop

Everything in Phase 1 is free and runs on your own computer.

**You need:** Python 3.11, 3.12 or 3.13 (check with `python3 --version`), and for the last step,
Docker Desktop (from Chapter 06).

### Step 1 — Make a practice folder and go into it

In your **terminal**, type these one at a time:

```bash
mkdir my-retraining
cd my-retraining
```

- `mkdir my-retraining` makes a new, empty **folder** for your own practice files.
- `cd my-retraining` moves you *into* it.

**What you should see:** no message at all. That's normal; silence means it worked.

> This repo's `chapter-13-retraining` folder already has finished copies of every file. Typing
> them yourself in a practice folder is how you really learn them. If you get stuck, compare
> with the finished copies.

### Step 2 — Make a clean toolbox (virtual environment)

A **virtual environment** is a clean, private toolbox just for this project. Run this from your
`my-retraining` folder:

```bash
python3 -m venv venv && source venv/bin/activate
```

**What you should see:** your terminal line now starts with `(venv)`.

> **Windows note:** if `source venv/bin/activate` doesn't work, use
> `venv\Scripts\activate` instead. On Windows, type `python` wherever this page says `python3`.

### Step 3 — Install the helpers

From your `my-retraining` folder, with `(venv)` showing:

```bash
pip install scikit-learn pandas numpy scipy mlflow==2.22.0
```

- `pip` **installs** helpers into your toolbox.
- `scikit-learn` builds and trains the model. `pandas` and `numpy` handle the data. `scipy` does
  the drift math. `mlflow` keeps the tidy notebook of results.
- `mlflow==2.22.0` asks for one exact version of MLflow. The newest MLflow (version 3) changed
  how it saves models, and the book's code stops with an error on it. Version 2.22.0 is the one
  this chapter was tested with, and it is the same version the container and the cloud use.

**What you should see:** lines ending with `Successfully installed ...`. This one installs a few
big helpers, so it may take a minute or two. That's normal.

### Step 4 — Write the drift detector

In your `my-retraining` folder, make a new file called **`drift_detector.py`** and type this in:

```python
# drift_detector.py
import numpy as np
from scipy import stats

def detect_drift(baseline, current, threshold=0.05):
    stat, pvalue = stats.ks_2samp(baseline, current)
    drift_detected = pvalue < threshold
    return {
        'drift_detected': drift_detected,
        'ks_statistic': round(stat, 4),
        'p_value': round(pvalue, 4),
        'interpretation': (
            'DRIFT DETECTED: retrain required'
            if drift_detected else
            'No significant drift'
        )
    }

# Simulate: baseline vs new data
baseline = np.random.normal(200, 50, 1000)
new_data = np.random.normal(300, 70, 500)
result   = detect_drift(baseline, new_data)
print(result)
```

**What the key lines say, in plain words:**

- `detect_drift(baseline, current, ...)` — Take two piles of numbers: the **baseline** (the old,
  normal data the model learned from) and the **current** (fresh data coming in now).
- `stats.ks_2samp(...)` — Run a **KS-test**. This is a math way to check if two piles of numbers
  look different. Picture laying two stacks of cards side by side to see if they match.
- `pvalue` — The test gives back a **p-value**, a number between 0 and 1. A *tiny* p-value means
  "these two piles are really different."
- `pvalue < threshold` — The **threshold** (the pass/fail line) is `0.05`. If the p-value is
  smaller than 0.05, that's drift, so it returns `'DRIFT DETECTED: retrain required'`. Otherwise
  `'No significant drift'`.
- `baseline = np.random.normal(200, 50, 1000)` — Make 1000 pretend old payment amounts centered
  around **200**.
- `new_data = np.random.normal(300, 70, 500)` — Make 500 pretend new amounts centered around
  **300**. Because 200 and 300 are clearly different, the test *should* flag drift.

Run it from your `my-retraining` folder:

```bash
python drift_detector.py
```

(On Mac/Linux you can also type `python3`.)

**What you should see:** a single line like:

```
{'drift_detected': np.True_, 'ks_statistic': np.float64(0.608), 'p_value': np.float64(0.0), 'interpretation': 'DRIFT DETECTED: retrain required'}
```

- `np.True_` is simply numpy's way of writing `True`, and `np.float64(0.608)` is numpy's way of
  writing the number `0.608`. (numpy is the number helper doing the math.)
- `drift_detected` is true: the detector noticed the world moved.
- The exact `ks_statistic` wiggles a little each run, because the data is randomly generated.
  That's fine. What matters is the true/false answer.

### Step 5 — Write the retraining helper

When drift shows up, we retrain. But we don't blindly trust the new model. We *test* it first.
In the same folder, make a new file called **`retrain_pipeline.py`**:

```python
# retrain_pipeline.py
import pandas as pd, numpy as np, mlflow
import mlflow.sklearn
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import recall_score, f1_score

RECALL_THRESHOLD = 0.70

def retrain_and_validate():
    np.random.seed(99)
    n = 2000
    amounts = np.random.exponential(220, n)
    times = np.random.uniform(0, 24, n)
    fraud = ((amounts>650)&(times<5)).astype(int)
    df = pd.DataFrame({
        'amount':amounts.round(2),
        'time':times.round(2),
        'is_fraud':fraud})
    X = df[['amount','time']]
    y = df['is_fraud']
    X_tr,X_te,y_tr,y_te = train_test_split(
        X,y,test_size=0.2,random_state=42)

    mlflow.set_experiment('fraud-auto-retrain')
    with mlflow.start_run() as run:
        clf = DecisionTreeClassifier(
            max_depth=6, random_state=42)
        clf.fit(X_tr, y_tr)
        y_pred = clf.predict(X_te)
        recall = recall_score(
            y_te, y_pred, zero_division=0)
        f1 = f1_score(
            y_te, y_pred, zero_division=0)
        mlflow.log_metric('recall', recall)
        mlflow.log_metric('f1', f1)
        mlflow.sklearn.log_model(clf,'model')

        if recall >= RECALL_THRESHOLD:
            uri = f'runs:/{run.info.run_id}/model'
            mlflow.register_model(
                uri, 'FraudDetectionModel')
            print(f'PROMOTED: recall={recall:.3f}')
            return True
        else:
            print(f'REJECTED: recall={recall:.3f}')
            print(f'Required: {RECALL_THRESHOLD}')
            return False

success = retrain_and_validate()
exit(0 if success else 1)
```

**What the key lines say, in plain words:**

- `amounts = ...`, `times = ...`, `fraud = ...` — Make a pile of pretend bank data: how much
  money, what time of day, and a label saying whether each one was **fraud** (a sneaky payment)
  or not. Here, "fraud" means a big payment (over 650) in the middle of the night (before 5 a.m.).
- `train_test_split(...)` — Split the data into two piles: a **study set** to learn from, and a
  hidden **test set** to quiz on later. Quizzing on examples it never studied is the only fair
  way to grade it.
- `DecisionTreeClassifier(...)` and `clf.fit(...)` — Train a **decision tree**, a model that
  learns yes/no questions to sort the data, like a game of "20 questions."
- `recall = recall_score(...)` — Grade the model on **recall**: of all the *real* fraud cases,
  how many did it catch? Higher is better.
- `RECALL_THRESHOLD = 0.70` — The pass/fail line (the **quality gate**). The new model must
  catch at least 70 out of every 100 fraud cases.
- `mlflow.log_metric(...)` and `mlflow.sklearn.log_model(...)` — Record the scores and the model
  itself in **MLflow** (a logbook for models), so there's a saved history.
- `if recall >= RECALL_THRESHOLD:` — If it passes, print `PROMOTED` and **register** the new
  model in the **model registry** as the next version of `FraudDetectionModel`. If not, print
  `REJECTED` and do *not* register it.
- `exit(0 if success else 1)` — End with an **exit code**: `0` means "all good," `1` means
  "something failed." A failing model exits `1`, which makes an automatic build system stop and
  complain instead of shipping a weak model.

Run it from your `my-retraining` folder:

```bash
python retrain_pipeline.py
```

**What you should see:** a few MLflow chat lines (including a yellow or red `WARNING` about a
missing "signature", which is harmless), then:

```
Successfully registered model 'FraudDetectionModel'.
Created version '1' of model 'FraudDetectionModel'.
PROMOTED: recall=1.000
```

That means the fresh model passed its quiz (it caught every fraud case in the test set) and was
kept as **version 1**. You'll also notice a new folder called `mlruns` appear: that's MLflow's
saved notebook. Run the script again and you'll see `Created version '2'`: every approved model
gets the next number on the shelf.

### Step 6 — Check the exit code

The script quietly ends with an exit code. Right after running it, from the same terminal, ask
what that code was:

```bash
echo $?
```

(On Windows PowerShell, use `echo $LASTEXITCODE` instead.)

**What you should see:** `0`, meaning success. If the model had been rejected, you'd see `1`.
This little number is how robots (automatic build systems) tell "good" from "bad" without
reading any words. Run `echo $?` *straight after* the script: any other command in between
replaces the number.

### Step 7 — Look inside the model registry

MLflow comes with a small website for its notebook. From your `my-retraining` folder (the one
that now has `mlruns` in it), run:

```bash
mlflow ui --port 5050
```

**What you should see:** a few lines ending with something like
`Listening at: http://127.0.0.1:5050`. The terminal stays busy; that's the website running.

Now open **http://localhost:5050** in your web browser:

- Click the **fraud-auto-retrain** experiment on the left. Each row is one run of
  `retrain_pipeline.py`, with its `recall` and `f1` scores.
- Click **Models** at the top. You'll see `FraudDetectionModel` with its latest version number.
  This is the **model registry**: the shelf of approved models.

When you're done, go back to the terminal and press **Ctrl+C** to stop the website.

> We use door (port) 5050 because on many Macs door 5000 is already taken by AirPlay.

### Step 8 — Pack it in a container

In the cloud, the drift check and retraining run inside a **container** (the sealed lunchbox from
Chapter 06). Let's build that exact lunchbox on your laptop first.

In your `my-retraining` folder, make three more files.

**`requirements.txt`** — the shopping list of helpers, with MLflow pinned like in Step 3:

```text
scikit-learn
pandas
numpy
scipy
mlflow==2.22.0
```

**`.dockerignore`** — things Docker should *not* copy into the box (the file name starts with a
dot):

```text
cloud/
mlflow-server/
venv/
mlruns/
__pycache__/
*.md
```

This keeps your big `venv` toolbox and your laptop's `mlruns` notebook out of the box.

**`Dockerfile`** — the recipe for the box:

```dockerfile
# Dockerfile: Chapter 13's drift check + retraining as one container.
# Runs drift_detector.py, then retrain_pipeline.py (which fails the job if
# the new model's recall is too low: a weak model never gets promoted).
# GIT_PYTHON_REFRESH=quiet: the slim image has no git, so MLflow would
# otherwise print a long (harmless) warning about it on every run.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp \
    MLFLOW_TRACKING_URI=file:///tmp/mlruns \
    GIT_PYTHON_REFRESH=quiet

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY drift_detector.py retrain_pipeline.py ./

RUN useradd -m -u 1000 appuser
USER 1000

CMD ["sh", "-c", "python drift_detector.py && python retrain_pipeline.py"]
```

**What the key lines say, in plain words:**

- `FROM python:3.11-slim` — Start from a small, ready-made box that already has Python.
- `MLFLOW_TRACKING_URI=file:///tmp/mlruns` — Tell MLflow to keep its notebook in `/tmp/mlruns`
  inside the box.
- `RUN pip install ... -r requirements.txt` — Install the shopping list inside the box.
- `RUN useradd ... appuser` and `USER 1000` — Run as an ordinary user, not the all-powerful
  "root" user. Safer, and the cloud insists on it.
- `CMD [... "python drift_detector.py && python retrain_pipeline.py"]` — When the box starts,
  run the drift check, then retraining. `&&` means "only run the second one if the first one
  didn't crash."

Make sure **Docker Desktop** is running, then build the box from your `my-retraining` folder
(note the dot `.` at the end, which means "this folder"):

```bash
docker build -t zero2ai-retrain:v1 .
```

**What you should see:** Docker works through the recipe step by step (the `pip install` step
takes a minute or two the first time) and finishes with a line like
`naming to docker.io/library/zero2ai-retrain:v1`.

Now run the box. `--rm` means "throw the box away when it finishes":

```bash
docker run --rm zero2ai-retrain:v1
```

**What you should see:** the same two results as Steps 4 and 5, now from inside the box:

```
{'drift_detected': np.True_, 'ks_statistic': np.float64(0.623), 'p_value': np.float64(0.0), 'interpretation': 'DRIFT DETECTED: retrain required'}
...
Successfully registered model 'FraudDetectionModel'.
Created version '1' of model 'FraudDetectionModel'.
PROMOTED: recall=1.000
```

Check the box's exit code straight away:

```bash
echo $?
```

**What you should see:** `0`. Docker passes the program's exit code back to you, so a rejected
model would make this `1`, and a robot would know.

Two more checks, from the same folder:

```bash
docker images zero2ai-retrain
docker run --rm zero2ai-retrain:v1 python drift_detector.py
```

**What you should see:** the first command lists your image with the tag `v1` (about 1.3 GB:
the helpers are big). The second one runs *only* the drift check, because anything you type
after the image name replaces the box's usual command.

**Notice something?** Run the box again and it says `Created version '1'` again, never `2`. The
notebook lived inside the box, and `--rm` threw it away. One run, one forgotten notebook. In
Phase 2 you'll fix that with a shared **MLflow server** that every run writes to.

### Try it yourself

All of these are done in your `my-retraining` folder, with `(venv)` showing.

- **Feed it data that has not drifted.** In `drift_detector.py`, change `new_data` to
  `np.random.normal(200, 50, 500)` (the same as the baseline). Run it a few times. Most runs
  print `No significant drift`. About 1 run in 20 still says drift, purely by bad luck. That's
  exactly what a threshold of `0.05` means: a 5% chance of a false alarm. Change it back to
  `300, 70` afterwards.
- **Move the drift line.** Change `threshold=0.05` to `threshold=0.5`. A bigger threshold is
  more suspicious and flags drift more easily, so false alarms happen far more often.
- **Make the model fail its quiz.** In `retrain_pipeline.py`, raise the bar to an impossible
  `RECALL_THRESHOLD = 0.999`. It still passes, because this model catches every case! Now
  instead change `max_depth=6` to `max_depth=1`. A tree that can only ask one yes/no question
  can't learn "big *and* late at night", so you'll see `REJECTED: recall=0.000` and
  `Required: 0.7`. Run `echo $?` and see `1`. Then change it back to `max_depth=6`.
- **Watch the registry grow.** Run `python retrain_pipeline.py` a few times (include one run
  with `max_depth=1`), then open `mlflow ui --port 5050`. The rejected run shows up in the
  experiment list (it was recorded, with its low recall) but never gets a model version on the
  **Models** page (it was not approved). That record of "what was tried and why it was refused"
  is exactly what auditors ask big companies for.

### If something breaks

- **`(venv)` is missing from your terminal line** → The toolbox isn't on. Run
  `source venv/bin/activate` (or `venv\Scripts\activate` on Windows) from inside your
  `my-retraining` folder.
- **`ModuleNotFoundError: No module named 'sklearn'` (or `scipy`, `mlflow`)** → The helpers
  aren't installed in this toolbox. Turn on `(venv)`, then redo Step 3. (The install name is
  `scikit-learn`, but the code says `import sklearn`.)
- **`MlflowException: The saved sklearn model references untrusted types`** (or a warning that
  `artifact_path` is deprecated) → You have MLflow 3 instead of 2.22.0. Run
  `pip install mlflow==2.22.0` and try again.
- **The install in Step 3 fails with errors about building wheels or `pyarrow`** → Your Python
  is probably too new. Check `python3 --version`; use Python 3.11, 3.12 or 3.13.
- **The install takes a long time or seems stuck** → These are big helpers. Give it a few
  minutes. As long as you don't see `ERROR`, it's working.
- **A long warning that starts `Failed to import Git` or mentions `GIT_PYTHON_REFRESH`** →
  Harmless: MLflow likes to note which git version of your code ran, and git isn't installed.
  Install git (Chapter 01), or hide it with `export GIT_PYTHON_REFRESH=quiet`.
- **The output shows `np.True_` and `np.float64(...)`, not plain `True` and numbers** → That's
  just how newer numpy prints its values. `np.True_` means `True`.
- **The drift numbers are slightly different each run** → Expected. The data is randomly
  generated. What matters is whether `drift_detected` is true or false.
- **The model version number keeps going up (3, 4, 5, ...)** → Normal: every approved run is a
  new version. To start again from version 1, delete the `mlruns` folder.
- **`mlflow ui` says the address or port is already in use** → Something else is using door
  5050. Use another one: `mlflow ui --port 5051`, then open http://localhost:5051.
- **The MLflow website shows no experiments** → You started `mlflow ui` from a different folder.
  Stop it (Ctrl+C), `cd` into the folder that has `mlruns`, and start it again.
- **`Cannot connect to the Docker daemon`** → Docker Desktop isn't running. Start it, wait for
  the whale icon to settle, and try again.
- **`failed to read dockerfile` or `COPY failed: ... not found`** → You're in the wrong folder,
  or a file name is different. The Dockerfile must be called exactly `Dockerfile` (capital D, no
  ending), and `requirements.txt`, `drift_detector.py` and `retrain_pipeline.py` must sit next to
  it. Check with `ls`.
- **`docker run` says `Unable to find image 'zero2ai-retrain:v1'`** → The build didn't finish, or
  the name is different. Run the `docker build` command again and watch for errors.

### What you learned in Phase 1

- **Drift** is when the world changes so a model's old lessons stop fitting, like a map going
  out of date.
- A **KS-test** and a **p-value** can tell you, with math, whether new data looks too different
  from old data, and a threshold decides how easily you raise the alarm.
- **Retraining** means teaching the model again on fresh examples.
- A safe pipeline **quizzes** the new model (on **recall**) and only **promotes** it if it
  passes, and **rejects** it (with an exit code of `1`) if it doesn't, so a weak model never
  ships.
- **MLflow** keeps a saved notebook of every run, and its **model registry** keeps numbered
  versions of approved models.
- A **container** runs the same routine anywhere, but its notebook disappears with it, which is
  why real teams use a shared MLflow server.

## Phase 2 and Phase 3

You just built a continuous-training routine on your laptop. Next, run the *same* container on
**AWS EKS**:

1. Build the shared cloud platform once: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
2. **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md). Run the routine
   once as a Job, then on a weekly schedule with a shared MLflow server.
3. **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md).
   Model files in S3 with no keys, automatic rollback, alerts and a runbook.

> **Costs money.** The cloud platform costs roughly **$0.10/hour** plus servers. Get permission
> if the AWS account isn't yours, and **destroy everything when you finish** (every guide ends
> with a one-line teardown).

## Where to next

[Chapter 14 — Release changes without scary surprises](../chapter-14-deployment/README.md). You
now know *when* a new model is ready; next you'll learn *how* to ship it safely, without scaring
your users.
