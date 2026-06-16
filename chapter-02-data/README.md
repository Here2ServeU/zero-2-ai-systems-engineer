# Chapter 02 — Your First Version-Controlled ML Experiment

**Book:** Chapter 2 (MLOps, DevOps, and AIOps) · Lab 2.4
**Layer:** 2 · Data & Models · **You build:** First ML experiment with manual logging

## What you build

A synthetic fraud dataset and a decision-tree classifier. Every run appends its
metrics to `logs/experiments.txt` — the manual version of what MLflow automates in
Chapter 4.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install pandas scikit-learn numpy

cd src
python generate_data.py     # -> ../data/transactions.csv
python train_model.py       # -> prints Acc/Pre/Rec, appends ../logs/experiments.txt
cat ../logs/experiments.txt
```

`data/` and `logs/` are created on first run.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time.

First, three words you will see a lot:

- **dataset** = a table of examples, like a spreadsheet with rows and columns.
- **model** = a pattern-spotter that learns from examples.
- **train** = let the model study the examples so it can guess on new ones.
- **fraud** = pretend or fake purchases that should not happen.

### `generate_data.py` — make a pretend pile of purchases

**In one sentence:** It invents 1,000 fake purchases and saves them in a table so we have something to practice on.

**What it does, step by step:**

1. `import pandas as pd` / `import numpy as np, os` — Borrow three helper toolkits.
   `pandas` builds tables. `numpy` makes random numbers. `os` lets us make folders.
2. `np.random.seed(42)` — Tell the random-number maker to always roll the same dice.
   This way you and a friend get the *same* pretend data every time.
3. `n = 1000` — We want 1,000 pretend purchases.
4. `amounts = np.random.exponential(scale=200, size=n)` — Make 1,000 dollar amounts.
   Most are small, a few are big (like real shopping).
5. `times = np.random.uniform(0, 24, size=n)` — Pick a time of day (0 to 24 hours) for each one.
6. `is_fraud = ((amounts > 800) & (times < 6)).astype(int)` — Make a rule for "fake":
   if a purchase is over $800 **and** happens before 6 in the morning, mark it as fraud (`1`).
   Everything else is okay (`0`).
7. `df = pd.DataFrame({...})` — Put the amount, time, and the fraud label into a tidy table
   with three columns: `amount`, `time`, `is_fraud`.
8. `os.makedirs('../data', exist_ok=True)` — Make a `data` folder to keep the table in
   (skip it if the folder is already there).
9. `df.to_csv('../data/transactions.csv', index=False)` — Save the table as a file called
   `transactions.csv`.
10. `print(...)` — Say out loud how many rows we made and how many were fraud.

**What you get:** A file `data/transactions.csv` with 1,000 rows and 3 columns
(`amount`, `time`, `is_fraud`), plus a printed line like `Generated 1000 rows, 18 fraud`.

### `train_model.py` — teach the computer to spot fake purchases

**In one sentence:** It reads the pretend purchases, lets a "yes/no question" robot study them, then checks how well it learned.

A **decision tree** is just a game of yes/no questions ("Is the amount over $800? Is the
time before 6am?") that leads to a guess at the end.

**What it does, step by step:**

1. `import ...` — Borrow toolkits for tables, dates, and the learning robot.
2. `df = pd.read_csv('../data/transactions.csv')` — Open the table we made earlier.
3. `X = df[['amount', 'time']]` — `X` is the clues we learn from: the amount and the time.
4. `y = df['is_fraud']` — `y` is the answer we want to guess: fraud or not.
5. `train_test_split(... test_size=0.2 ...)` — Split the examples into two piles:
   80% to study (`X_tr`, `y_tr`) and 20% to test (`X_te`, `y_te`).
   Like studying most of the flashcards, then quizzing yourself on the rest.
6. `model = DecisionTreeClassifier(max_depth=5, random_state=42)` — Build the yes/no-question
   robot. `max_depth=5` means it can ask at most 5 questions in a row.
7. `model.fit(X_tr, y_tr)` — Let the robot study the practice pile. This is **training**.
8. `y_pred = model.predict(X_te)` — Ask the robot to guess on the quiz pile it never saw.
9. `accuracy_score` — How often was it right overall (like a test grade).
   `precision_score` — When it yelled "fraud!", how often was it really fraud.
   `recall_score` — Of all the real fraud, how much did it catch.
10. `print(f'Acc:... Pre:... Rec:...')` — Show those three scores on the screen.
11. `os.makedirs('../logs', exist_ok=True)` and the `with open(...)` block — Make a `logs`
    folder and **add** (not replace) one line with today's date and the three scores to
    `experiments.txt`. Every run leaves its own line, so you keep a history.

**What you get:** A printed line like `Acc:0.995 Pre:1.000 Rec:0.800`, and a new line added
to `logs/experiments.txt` recording the date and those scores.

➡ Next: [chapter-03-models](../chapter-03-models) — fraud + healthcare anomaly models.
