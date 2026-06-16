# Chapter 13 — Advanced CI/CD & Retraining Pipelines

**Book:** Chapter 13 (Advanced CI/CD and Retraining Pipelines) · Lab 13.2
**Layer:** 7 · Continuous Delivery · **You build:** Drift detection + gated auto-retraining

## What you build

- `drift_detector.py` — a Kolmogorov–Smirnov test comparing baseline vs. current data.
- `retrain_pipeline.py` — retrains, validates against a recall quality gate, and only
  registers the model in MLflow if it passes (`exit(1)` on failure so CI fails).
- A scheduled GitHub Actions workflow: **[`.github/workflows/retrain.yml`](../.github/workflows/retrain.yml)**
  (cron every Monday 02:00 + manual `workflow_dispatch`).

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install scikit-learn pandas numpy mlflow scipy

python drift_detector.py
python retrain_pipeline.py     # PROMOTED if recall >= 0.70, else REJECTED (exit 1)
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we watch for *drift* — that's when the world changes so the old model's guesses
get worse, like outgrowing your shoes. When that happens, we *retrain* the model, which
just means teaching it again with fresh examples.

### `drift_detector.py` — a checker that asks "has the world changed?"

**In one sentence:** This compares old data with new data and tells you if the new stuff
looks too different, which would mean the model needs to learn again.

**What it does, step by step:**

1. It takes two piles of numbers: the *baseline* (the old, normal data the model learned
   from) and the *current* (fresh new data coming in now).
2. It runs a *KS-test*. This is a math way to check if new data looks different from old
   data. Think of it as laying two stacks of cards side by side to see if they match.
3. The test gives back a *p-value*, a number between 0 and 1. A tiny p-value means "these
   two piles are really different."
4. The *threshold* (the pass/fail line) is 0.05. If the p-value is smaller than 0.05, it
   says "DRIFT DETECTED: retrain required." If not, it says "No significant drift."
5. In the example, the old data is centered around 200 and the new data around 300, so
   they are clearly different and drift gets flagged.

**What you get:** A simple "did things change?" alarm that tells you when your model is
working with out-of-date assumptions and needs a refresh.

### `retrain_pipeline.py` — a teacher that retrains the model but only keeps it if it's good

**In one sentence:** This teaches the model again with fresh data, gives it a test, and
only saves the new model if it passes — otherwise it throws the new one away and fails on
purpose so the robots know.

**What it does, step by step:**

1. It makes a pile of pretend bank data: how much money and what time of day, plus a
   label saying whether each one was fraud (cheating) or not.
2. It splits the data into a study set and a test set, so it can teach with one part and
   quiz with the other part it has never seen.
3. It trains a *decision tree* — a model that learns yes/no questions to sort the data,
   like a game of "20 questions."
4. It scores the model on *recall*, which means "of all the real fraud cases, how many
   did it catch?" Higher is better.
5. The `RECALL_THRESHOLD` is 0.70 — the pass/fail line. The model must catch at least 70
   out of every 100 fraud cases.
6. It records everything in MLflow (a logbook for models) so there's a saved history.
7. If recall is 0.70 or higher, it prints "PROMOTED" and registers the new model as the
   official one. If recall is too low, it prints "REJECTED" and does not save it.
8. At the very end it uses *exit codes*. Exit code 0 means "all good." Exit code 1 means
   "something failed." So a passing model exits 0, and a failing one exits 1 — which makes
   the automatic build system stop and complain instead of shipping a bad model.

**What you get:** A safe retraining helper that only lets a new model take over when it
proves it's good enough, and loudly fails when it isn't — so a weak model never sneaks
into the real world.

➡ Next: [chapter-14-deployment](../chapter-14-deployment) — ship safely with canary/blue-green.
