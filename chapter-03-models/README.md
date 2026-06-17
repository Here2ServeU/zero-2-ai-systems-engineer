# Chapter 03 — Teach the computer to spot trouble

> Matches **Chapter 03** in the book. Two real detectors, two different ways of learning.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

In Chapter 02 you taught the computer to spot fake purchases from labeled examples. Now we'll
do two grown-up versions of that idea.

First, a bigger **fraud** detector for bank purchases — but this time we'll print a proper
"report card" that shows not just how often it was right, but exactly what it *caught* and what
it *missed*. In fraud, a missed fake is the scary mistake.

Second, something new: an **anomaly** finder for hospital readings. Here nobody tells the
computer which readings are bad. It just looks at thousands of patient measurements and points
out the few that don't fit the crowd — like a teacher noticing the one student acting unlike
everyone else, without being told who to watch.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Anomaly** — something that doesn't fit the normal pattern; an oddity worth a closer look.
- **Supervised learning** — learning from examples that already have the right answer (which were fraud).
- **Unsupervised learning** — learning with *no* answers given; the computer finds odd ones on its own.
- **Confusion matrix** — a small grid that shows what the model caught, missed, and falsely flagged.
- **False negative** — real fraud the model *missed*. The dangerous error.
- **Isolation Forest** — the anomaly-finder we use; it fences off odd points with just a few cuts.

## What you will build

Two programs. One reads 2,000 pretend bank purchases and prints a fraud report card. The other
invents 1,500 pretend patient readings and finds the weird ones by itself. You'll see roughly:

```
2000 transactions, 41 fraud
Accuracy: 0.998
... (a report card with Legitimate and Fraud rows) ...
True Positives (fraud caught): 7
False Negatives (fraud missed): 1
False Positives (false alarms): 0

Normal: 1440
Anomalies: 60 (4.0%)
```

(Your exact numbers may differ a little — that's normal.)

---

## Let's do it, one small step at a time

### Step 1 — Go to this chapter's project folder

Open your **terminal** and move into the chapter folder:

```bash
cd chapter-03-models
```

**What you should see:** your prompt now shows you're inside `chapter-03-models`. Type `ls` and
you should see a `src` folder.

### Step 2 — Make a clean toolbox just for this project

Create and turn on a fresh **virtual environment (venv)**:

```bash
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
```

**What you should see:** your prompt now starts with `(venv)`.

### Step 3 — Install the three helpers

Same three free toolkits as last chapter:

```bash
pip install pandas scikit-learn numpy
```

**What you should see:** lines scrolling by, ending in `Successfully installed ...`.

### Step 4 — Make the pretend pile of bank purchases

```bash
python src/create_fintech_data.py
```

**What you should see:**

```
2000 transactions, 41 fraud
```

It made 2,000 purchases, 41 of them fake, and saved them to `data/fintech_transactions.csv`.

**What this program says, in plain words** (open `src/create_fintech_data.py` to follow along):

1. `import pandas as pd, numpy as np, os` — Borrow the table, random-number, and folder toolkits.
2. `np.random.seed(42); n = 2000` — Lock the dice so the data is the same every time, and ask
   for 2,000 purchases.
3. `amounts = np.random.exponential(150, n)` — Make 2,000 dollar amounts (mostly small, a few big).
4. `times = np.random.uniform(0, 24, n)` — Pick a time of day for each.
5. `locations = np.random.randint(0, 50, n)` — Give each purchase a store number from 0 to 49.
   (This is a *new third clue* compared with Chapter 02.)
6. `is_fraud = ((amounts>600)&((times<5)|(times>23))).astype(int)` — The "fake" rule: over **$600**
   *and* very early (before 5am) **or** very late (after 11pm) → **fraud** (`1`); otherwise okay (`0`).
7. `df = pd.DataFrame({...})` — Put it in a **dataset** with four columns.
8. `os.makedirs(...)` then `df.to_csv(...)` — Make a `data` folder and save the table.
9. `print(...)` — Say how many purchases and how many were fraud.

### Step 5 — Run the fraud detector and read its report card

```bash
python src/fraud_detection.py
```

**What you should see:** the accuracy, a report card naming `Legitimate` and `Fraud`, then
three counts (fraud caught, fraud missed, false alarms).

**What this program says, in plain words** (open `src/fraud_detection.py` to follow along):

1. `import ...` — Borrow toolkits for tables, the **decision tree** robot, and scoring tools.
2. `df = pd.read_csv('../data/fintech_transactions.csv')` — Open the table we just made.
3. `X = df[['amount','time_of_day','merchant_loc']]` — The clues: amount, time, and store number.
4. `y = df['is_fraud']` — The answer to guess: fraud or not. Because we *have* the answers,
   this is **supervised learning**.
5. `train_test_split(... test_size=0.2 ... stratify=y)` — Split into 80% study, 20% quiz.
   `stratify=y` makes sure both piles get a fair share of the rare fraud cases.
6. `model = DecisionTreeClassifier(max_depth=6, min_samples_split=5, ...)` — Build the robot.
   It may ask up to 6 yes/no questions, and only splits a group that has at least 5 examples.
7. `model.fit(X_tr, y_tr)` — Let it study. **This is training.**
8. `y_pred = model.predict(X_te)` — Ask it to guess on the quiz pile.
9. `print(f'Accuracy: ...')` — Show the overall grade.
10. `print(classification_report(...))` — Print a detailed report card with `Legitimate` and
    `Fraud` rows so it's easy to read.
11. `cm = confusion_matrix(...)` — Build a small score grid (the **confusion matrix**). From it
    we print three numbers:
    - **True Positives** — real fraud the robot caught. Good.
    - **False Negatives** — real fraud the robot *missed*. The dangerous mistake.
    - **False Positives** — okay purchases it wrongly flagged. Annoying false alarms.

> **Why stare at the missed fraud?** In a bank, a missed fake (a false negative) means real
> money lost. A false alarm just means one extra phone call. So we care most about keeping
> false negatives low.

### Step 6 — Find the weird hospital readings (no answers given)

```bash
python src/anomaly_detection.py
```

**What you should see:** two lines, something like:

```
Normal: 1440
Anomalies: 60 (4.0%)
```

**What this program says, in plain words** (open `src/anomaly_detection.py` to follow along):

1. `import ...` — Borrow toolkits for tables, the **Isolation Forest** robot, and a scaler.
2. `np.random.seed(42); n = 1500` — Lock the dice, make 1,500 pretend patient readings.
3. `hr`, `bp`, `tmp`, `o2` — Make four normal-looking measurements: heart rate (around 75),
   blood pressure (around 120), temperature (around 98.6), and oxygen level (around 98).
4. `idx = np.random.choice(n, 50, replace=False)` — Secretly pick 50 patients.
5. `hr[idx] += ...` and `bp[idx] += ...` — Mess up those 50 patients' heart rate and blood
   pressure so they look strange. These are our hidden odd ones — but the robot is *not* told
   which they are. That makes this **unsupervised learning**.
6. `df = pd.DataFrame({...})` — Put the four measurements in a table.
7. `X = df.values` — Pull the raw numbers out of the table.
8. `X_scaled = StandardScaler().fit_transform(X)` — Put every measurement on the same scale, so
   a big number (blood pressure) doesn't bully a small one (temperature).
9. `IsolationForest(contamination=0.04, ...).fit_predict(X_scaled)` — Run the weird-finder.
   `contamination=0.04` tells it to expect about 4% of readings to be odd. It labels each
   reading `1` for normal or `-1` for weird.
10. `n_anom = (preds == -1).sum()` — Count how many it called weird.
11. `print(...)` — Show how many were normal and how many were **anomalies**.

> **Two ways to learn.** Fraud detection had answers to study (supervised). The hospital finder
> had none — it just spotted the odd ones out (unsupervised). Real systems use both.

---

## Try it yourself (mini challenges)

- 🔧 **Make fraud rarer.** In `create_fintech_data.py`, change `amounts>600` to `amounts>900`,
  rerun Steps 4 and 5, and watch the "fraud missed" count. Rarer fraud is harder to catch.
- 🔧 **Loosen the detective.** In `fraud_detection.py`, change `max_depth=6` to `max_depth=2`.
  Rerun it. Does it miss more fraud (more false negatives)?
- 🔧 **Expect more oddities.** In `anomaly_detection.py`, change `contamination=0.04` to `0.10`.
  Rerun it. The "Anomalies" count should jump — you told it to expect more.
- 🔧 **Hide more weirdos.** In `anomaly_detection.py`, change the secret `50` (in the
  `np.random.choice(n, 50, ...)` line) to `150`, rerun, and see if the finder notices.

## If something breaks

- **`No module named pandas` (or sklearn / numpy)** → Your toolbox isn't on, or helpers aren't
  installed. Confirm your prompt shows `(venv)`, then redo Step 2 and Step 3.
- **`No such file or directory: '../data/fintech_transactions.csv'`** → You ran
  `fraud_detection.py` before making the data. Run `python src/create_fintech_data.py` first (Step 4).
- **`can't open file 'src/...'`** → You're in the wrong folder. Make sure you did
  `cd chapter-03-models` (Step 1). Type `ls` to confirm you see the `src` folder.
- **The report card looks confusing** → That's expected at first. Just focus on the three plain
  lines below it: fraud caught, fraud missed, false alarms.
- **Anomaly count is exactly what you set (around 4%)** → That's by design. `contamination`
  tells the robot roughly how many odd ones to expect.

## What you just learned

- **Supervised learning** uses examples *with* answers; **unsupervised learning** has *no*
  answers and finds the odd ones itself.
- A **confusion matrix** shows what a detector caught, missed, and wrongly flagged.
- A **false negative** (missed fraud) is usually the most dangerous mistake.
- An **Isolation Forest** can spot **anomalies** without ever being told which are bad.
- Scaling numbers first keeps big values from drowning out small ones.

## Where to next

➡ [Chapter 04 — Keep a tidy notebook of your experiments](../chapter-04-mlflow). You'll stop
writing your scores in a file by hand and let a tool keep the notebook for you automatically.
