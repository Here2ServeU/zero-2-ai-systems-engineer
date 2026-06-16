# Chapter 03 — Fraud Detection & Healthcare Anomaly Detection

**Book:** Chapter 3 (AI in Regulated Environments) · Lab 3.4
**Layer:** 2 · Data & Models · **You build:** Two production models, two paradigms

## What you build

- **Supervised** fraud detection (decision tree) with an interpretable confusion matrix
  suitable for regulatory review.
- **Unsupervised** healthcare anomaly detection (Isolation Forest) over synthetic vital signs.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install pandas scikit-learn numpy

python src/create_fintech_data.py    # -> data/fintech_transactions.csv
python src/fraud_detection.py        # classification report + confusion matrix
python src/anomaly_detection.py      # Isolation Forest anomaly counts
```

Read the confusion matrix carefully: **false negatives** (missed fraud) are the
dangerous error in regulated AI.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time.

First, a few words you will see a lot:

- **dataset** = a table of examples, like a spreadsheet with rows and columns.
- **model** = a pattern-spotter that learns from examples.
- **train** = let the model study the examples so it can guess on new ones.
- **decision tree** = a game of yes/no questions that ends in a guess.
- **fraud** = pretend or fake purchases that should not happen.
- **anomaly** = something weird that does not fit with everything else.

### `create_fintech_data.py` — make a pretend pile of bank purchases

**In one sentence:** It invents 2,000 fake bank purchases and saves them in a table to practice on.

**What it does, step by step:**

1. `import pandas as pd, numpy as np, os` — Borrow toolkits: `pandas` for tables,
   `numpy` for random numbers, `os` for making folders.
2. `np.random.seed(42); n = 2000` — Lock the dice so the data is the same every time,
   and ask for 2,000 purchases.
3. `amounts = np.random.exponential(150, n)` — Make 2,000 dollar amounts (mostly small, a few big).
4. `times = np.random.uniform(0, 24, n)` — Pick a time of day for each one.
5. `locations = np.random.randint(0, 50, n)` — Give each purchase a store number from 0 to 49.
6. `is_fraud = ((amounts>600)&((times<5)|(times>23))).astype(int)` — The "fake" rule:
   if a purchase is over $600 **and** happens very early (before 5am) **or** very late
   (after 11pm), mark it as fraud (`1`); otherwise okay (`0`).
7. `df = pd.DataFrame({...})` — Put it all in a table with four columns:
   `amount`, `time_of_day`, `merchant_loc`, `is_fraud`.
8. `os.makedirs('../data', exist_ok=True)` then `df.to_csv(...)` — Make a `data` folder
   and save the table as `fintech_transactions.csv`.
9. `print(...)` — Say how many purchases and how many were fraud.

**What you get:** A file `data/fintech_transactions.csv` with 2,000 rows and 4 columns,
plus a printed line like `2000 transactions, 41 fraud`.

### `fraud_detection.py` — teach the computer to catch fake purchases

**In one sentence:** It reads the pretend bank purchases, lets a yes/no-question robot study them, then shows a report card of what it caught and what it missed.

This is **supervised** learning: we already know the right answers (which ones are fraud),
so the robot learns from labeled examples.

**What it does, step by step:**

1. `import ...` — Borrow toolkits for tables, the decision-tree robot, and scoring tools.
2. `df = pd.read_csv('../data/fintech_transactions.csv')` — Open the table we made.
3. `X = df[['amount','time_of_day','merchant_loc']]` — The clues: amount, time, and store.
4. `y = df['is_fraud']` — The answer to guess: fraud or not.
5. `train_test_split(... test_size=0.2 ... stratify=y)` — Split into 80% to study and 20% to
   quiz. `stratify=y` makes sure both piles have a fair share of the rare fraud cases.
6. `model = DecisionTreeClassifier(max_depth=6, min_samples_split=5, ...)` — Build the robot.
   It can ask up to 6 questions, and it only splits a group if it has at least 5 examples.
7. `model.fit(X_tr, y_tr)` — Let the robot study. This is **training**.
8. `y_pred = model.predict(X_te)` — Ask it to guess on the quiz pile.
9. `print(f'Accuracy: ...')` — Show the overall grade (how often it was right).
10. `print(classification_report(...))` — Print a detailed report card, with `Legitimate`
    (okay) and `Fraud` (fake) named so it is easy to read.
11. `cm = confusion_matrix(...)` — A little 2x2 score grid. From it we print three numbers:
    - **True Positives** — real fraud the robot caught. Good.
    - **False Negatives** — real fraud the robot **missed**. The dangerous mistake.
    - **False Positives** — okay purchases it wrongly flagged. Annoying false alarms.

**What you get:** Printed text showing the accuracy, a full report card, and the counts of
fraud caught, fraud missed, and false alarms.

### `anomaly_detection.py` — spot weird hospital readings

**In one sentence:** It invents pretend patient vital signs, hides a few weird ones, then lets a robot find the weird ones all by itself.

This is **unsupervised** learning: nobody tells the robot which readings are bad. It just
looks for the ones that do not fit (the **anomalies**).

An **Isolation Forest** is the robot here. Think of it as a game: weird points are easy to
fence off by themselves with just a few cuts, so they get caught fast.

**What it does, step by step:**

1. `import ...` — Borrow toolkits for tables, the Isolation Forest robot, and a scaler.
2. `np.random.seed(42); n = 1500` — Lock the dice, and make 1,500 pretend patient readings.
3. `hr`, `bp`, `tmp`, `o2` — Make four normal-looking measurements: heart rate (around 75),
   blood pressure (around 120), temperature (around 98.6), and oxygen level (around 98).
4. `idx = np.random.choice(n, 50, replace=False)` — Secretly pick 50 patients.
5. `hr[idx] += ...` and `bp[idx] += ...` — Mess up those 50 patients' heart rate and blood
   pressure so they look strange. These are our hidden weird ones.
6. `df = pd.DataFrame({...})` — Put the four measurements in a table.
7. `X = df.values` — Pull the numbers out of the table.
8. `X_scaled = StandardScaler().fit_transform(X)` — Put every measurement on the same scale,
   so a big number like blood pressure does not bully a small one like temperature.
9. `IsolationForest(contamination=0.04, ...).fit_predict(X_scaled)` — Run the weird-finder.
   `contamination=0.04` tells it to expect about 4% of readings to be weird. It labels each
   reading `1` for normal or `-1` for weird.
10. `n_anom = (preds == -1).sum()` — Count how many it called weird.
11. `print(...)` — Show how many were normal and how many were anomalies (plus a percentage).

**What you get:** Two printed lines, like `Normal: 1440` and `Anomalies: 60 (4.0%)`, telling
you how many readings the robot thought were normal versus weird.

➡ Next: [chapter-04-mlflow](../chapter-04-mlflow) — track every experiment with MLflow.
