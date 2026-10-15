# Chapter 13 — Notice when the world changes (Drift & retraining)

> Matches **Chapter 13** in the book. This is the gentle on-ramp version.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

A **model** (the pattern-spotter you trained back in Chapter 03) learns from examples it sees
*today*. But the world keeps moving. Prices go up. People's habits change. Yesterday's "normal"
slowly becomes today's "unusual."

When the world changes so much that the model's old chapters stop fitting, we call it **drift** —
like a **paper map going out of date**. The roads on the map were correct once, but new roads
got built and old ones closed, so the map now leads you astray. The map didn't get *worse*; the
world moved on without it.

The fix is **retraining**: teaching the model again on **fresh examples**, the same way you'd
buy an updated map.

In this chapter you'll build two small things:

1. A **drift detector** that compares old data with new data and shouts if they look too
   different.
2. A **retraining helper** that teaches a fresh model, *quizzes* it, and only keeps it if it
   passes the test — and loudly fails if it doesn't, so a weak model never sneaks out.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Drift** — When the real world slowly changes so your model's old training no longer fits.
- **Retraining** — Teaching the model again on fresh data when drift shows up.
- **Recall** — Out of all the real fraud, how much the model caught. (Higher is better.)
- **MLflow** — A tool that automatically keeps a tidy notebook of every experiment and model.

## What you will build

- `drift_detector.py` — compares a **baseline** (old, normal data) with **current** (fresh)
  data and prints whether drift was detected.
- `retrain_pipeline.py` — retrains a model on fresh data, scores it on **recall**, and only
  saves ("promotes") it if recall clears a quality line — otherwise it rejects it and exits with
  a failure code so an automatic build system would stop.

---

## Let's do it, one small step at a time

### Step 1 — Make a folder and go into it

In your **terminal**, type these one at a time:

```bash
mkdir chapter-13-retraining
cd chapter-13-retraining
```

- `mkdir chapter-13-retraining` makes a new **folder**.
- `cd chapter-13-retraining` moves you *into* it.

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
pip install scikit-learn pandas numpy mlflow scipy
```

- `pip` **installs** helpers into your toolbox.
- `scikit-learn` builds and trains the model. `pandas` and `numpy` handle the data. `scipy` does
  the drift math. `mlflow` keeps the tidy notebook of results.

**What you should see:** lines ending with `Successfully installed ...`. This one installs a few
big helpers, so it may take a minute. That's normal.

### Step 4 — Write the drift detector

Make a new file called **`drift_detector.py`** and type this in:

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
- `stats.ks_2samp(...)` — Run a *KS-test*. This is a math way to check if two piles of numbers
  look different. Picture laying two stacks of cards side by side to see if they match.
- `pvalue` — The test gives back a **p-value**, a number between 0 and 1. A *tiny* p-value means
  "these two piles are really different."
- `pvalue < threshold` — The **threshold** (the pass/fail line) is `0.05`. If the p-value is
  smaller than 0.05, that's drift, so it returns `'DRIFT DETECTED: retrain required'`. Otherwise
  `'No significant drift'`.
- `baseline = np.random.normal(200, 50, 1000)` — Make 1000 pretend old numbers centered around
  **200**.
- `new_data = np.random.normal(300, 70, 500)` — Make 500 pretend new numbers centered around
  **300**. Because 200 and 300 are clearly different, the test *should* flag drift.

Run it:

```bash
python drift_detector.py
```

(On Mac/Linux you can also type `python3`.)

**What you should see:** a single line like:

```
{'drift_detected': True, 'ks_statistic': 0.62, 'p_value': 0.0, 'interpretation': 'DRIFT DETECTED: retrain required'}
```

`drift_detected` is `True` — the detector noticed the world moved. 🎉 (The exact numbers will
wiggle a little each run because the data is randomly generated. That's fine.)

### Step 5 — Write the retraining helper

When drift shows up, we retrain — but we don't blindly trust the new model. We *test* it first.
Make a new file called **`retrain_pipeline.py`**:

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
  money, what time of day, and a label saying whether each one was **fraud** (sneaky payment)
  or not.
- `train_test_split(...)` — Split the data into two piles: a **study set** to learn from, and a
  hidden **test set** to quiz on later. Quizzing on examples it never studied is the only fair
  way to grade it.
- `DecisionTreeClassifier(...)` and `clf.fit(...)` — Train a **decision tree**, a model that
  learns yes/no questions to sort the data, like a game of "20 questions."
- `recall = recall_score(...)` — Grade the model on **recall**: of all the *real* fraud cases,
  how many did it catch? Higher is better.
- `RECALL_THRESHOLD = 0.70` — The pass/fail line. The new model must catch at least 70 out of
  every 100 fraud cases.
- `mlflow.log_metric(...)` and `mlflow.sklearn.log_model(...)` — Record everything in **MLflow**
  (a logbook for models) so there's a saved history.
- `if recall >= RECALL_THRESHOLD:` — If it passes, print `PROMOTED` and **register** the new
  model as the official one. If not, print `REJECTED` and do *not* save it.
- `exit(0 if success else 1)` — End with an **exit code**: `0` means "all good," `1` means
  "something failed." A failing model exits `1`, which makes an automatic build system stop and
  complain instead of shipping a weak model.

Run it:

```bash
python retrain_pipeline.py
```

**What you should see:** a few MLflow setup lines, then something like:

```
PROMOTED: recall=0.95
```

That means the fresh model passed its quiz and was kept. 🎉 You'll also notice a new folder
called `mlruns` appear — that's MLflow's saved notebook.

### Step 6 — Check the exit code (optional but cool)

The script quietly ends with an exit code. Right after running it, ask the terminal what that
code was:

```bash
echo $?
```

(On Windows PowerShell, use `echo $LASTEXITCODE` instead.)

**What you should see:** `0` — meaning success. If the model had been rejected, you'd see `1`.
This little number is how robots (automatic build systems) tell "good" from "bad" without
reading any words.

---

## Try it yourself (mini challenges)

- 🔧 **Feed it shifted data and watch drift get flagged.** In `drift_detector.py`, change
  `new_data` to `np.random.normal(205, 50, 500)` (very close to the baseline's 200). Run it —
  now drift should *not* be detected. Then change it back to `300` and watch it flag drift again.
- 🔧 **Move the drift line.** Change `threshold=0.05` to `threshold=0.5`. A bigger threshold is
  more suspicious and flags drift more easily.
- 🔧 **Make the model fail its quiz.** In `retrain_pipeline.py`, raise the bar to an impossible
  `RECALL_THRESHOLD = 0.999`. Run it and watch it print `REJECTED`. Then run `echo $?` and see
  the exit code change to `1`.
- 🔧 **Make the tree simpler.** Change `max_depth=6` to `max_depth=1`. A very shallow tree may
  catch fewer fraud cases, lowering recall. Run it and compare the recall number.

## If something breaks

- **`(venv)` is missing from your terminal line** → The toolbox isn't on. Run
  `source venv/bin/activate` (or `venv\Scripts\activate` on Windows), inside the
  `chapter-13-retraining` folder.
- **`ModuleNotFoundError: No module named 'sklearn'` (or `scipy`, `mlflow`)** → The helpers
  aren't installed in this toolbox. Redo Step 3:
  `pip install scikit-learn pandas numpy mlflow scipy`. (Note the install name is
  `scikit-learn`, but you `import sklearn`.)
- **The install in Step 3 takes a long time or seems stuck** → These are big helpers. Give it a
  minute or two. As long as you don't see an error, it's working.
- **`python retrain_pipeline.py` prints lots of MLflow text** → That's normal. MLflow chats a
  bit while it sets up its notebook. Look for the `PROMOTED` or `REJECTED` line at the end.
- **The drift numbers are slightly different each run** → Expected. The data is randomly
  generated, so the exact p-value wiggles. What matters is the `True`/`False` of
  `drift_detected`.

## What you just learned

- **Drift** is when the world changes so a model's old chapters stop fitting, like a map going
  out of date.
- A **KS-test** and a **p-value** can tell you, with math, whether new data looks too different
  from old data.
- **Retraining** means teaching the model again on fresh examples.
- A safe pipeline **quizzes** the new model (on **recall**) and only **promotes** it if it
  passes — and **rejects** it (with an exit code of `1`) if it doesn't, so a weak model never
  ships.
- **MLflow** keeps a saved notebook of every run and model.

## Where to next

➡ [Chapter 14 — Release changes without scary surprises](../chapter-14-deployment). You now know
*when* to ship a new model; next you'll learn *how* to ship it safely, without scaring your
users.
