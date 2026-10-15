# Chapter 02 — Your very first tiny AI experiment

> Matches **Chapter 02** in the book. This is your first taste of machine learning.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

Imagine you want to teach a friend to spot a fake $20 bill. You don't hand them a rulebook.
Instead, you show them lots of real bills and lots of fake ones until they start noticing the
pattern themselves. That's exactly what we'll do here, except our "friend" is the computer.

We'll make a pretend pile of purchases, mark which ones are sneaky fakes, and let the computer
**learn from examples** which ones look like trouble. Then we'll quiz it on purchases it has
never seen and check how well it did. That's a whole machine-learning experiment, in miniature.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **AI / ML** — software that learns patterns from examples instead of being told every rule.
- **Dataset** — a table of examples, like a spreadsheet with rows and columns.
- **Model** — a pattern-spotter that learns from examples and then guesses on new ones.
- **Train** — let the model study the examples so it can guess well later.
- **Fraud** — fake or sneaky purchases that should not happen. This is what we're hunting.
- **Train/test split** — splitting examples into two piles: most to study, some kept hidden to quiz with.
- **Accuracy / precision / recall** — three ways to measure how good the model's guesses are.

## What you will build

A program that invents 1,000 pretend purchases, teaches the computer to spot the fake ones,
then grades itself and writes the score into a little log file. You'll see something like:

```
Generated 1000 rows, 18 fraud
Acc:0.995 Pre:1.000 Rec:0.800
Logged to logs/experiments.txt
```

(Your exact numbers may differ a little — that's normal.)

---

## Let's do it, one small step at a time

### Step 1 — Go to this chapter's project folder

The real code lives in the book's chapter folder. Open your **terminal** and move into it:

```bash
cd chapter-02-data
```

**What you should see:** your terminal prompt now shows you're inside `chapter-02-data`.

> If you're not sure where you are, type `ls` to list what's around you. You should see a
> `src` folder and a `README.md`.

### Step 2 — Make a clean toolbox just for this project

A **virtual environment (venv)** is a private toolbox so this project's helpers don't bump
into anything else on your computer. Create one and turn it on:

```bash
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
```

**What you should see:** your prompt now starts with `(venv)`. That means the toolbox is on.

### Step 3 — Install the three helpers we need

We need three free helper toolkits. **Install** them with one command:

```bash
pip install pandas scikit-learn numpy
```

**What you should see:** lots of lines scrolling by, ending in something like
`Successfully installed pandas... scikit-learn... numpy...`.

- `pandas` builds and reads tables (think spreadsheets in code).
- `scikit-learn` is the learning toolkit — it holds our pattern-spotter.
- `numpy` makes random numbers, which we'll use to invent fake purchases.

### Step 4 — Move into the code folder

```bash
cd src
```

**What you should see:** you're now inside `src`, where the two program files live
(`generate_data.py` and `train_model.py`).

### Step 5 — Make the pretend pile of purchases

Run the first program. It invents 1,000 fake purchases and saves them as a table:

```bash
python generate_data.py
```

**What you should see:**

```
Generated 1000 rows, 18 fraud
```

That tells you it made 1,000 purchases and 18 of them are sneaky fakes. The table is saved
to a new file, `data/transactions.csv`.

**What this program says, in plain words** (open `generate_data.py` in VS Code to follow along):

1. `import pandas as pd` / `import numpy as np, os` — Borrow the three helper toolkits we installed.
2. `np.random.seed(42)` — Tell the random-number maker to always roll the *same* dice, so you
   and a friend get the exact same pretend data every time.
3. `n = 1000` — We want 1,000 pretend purchases.
4. `amounts = np.random.exponential(scale=200, size=n)` — Make 1,000 dollar amounts. Most are
   small, a few are big, just like real shopping.
5. `times = np.random.uniform(0, 24, size=n)` — Give each purchase a time of day (0 to 24 hours).
6. `is_fraud = ((amounts > 800) & (times < 6)).astype(int)` — The rule for "fake": if a purchase
   is over **$800** *and* happens before **6 in the morning**, mark it as **fraud** (`1`).
   Everything else is okay (`0`).
7. `df = pd.DataFrame({...})` — Put the amount, time, and the fraud label into one tidy
   **dataset** with three columns.
8. `os.makedirs('../data', exist_ok=True)` — Make a `data` folder to keep the table in.
9. `df.to_csv('../data/transactions.csv', index=False)` — Save the table to a file.
10. `print(...)` — Say out loud how many rows we made and how many were fraud.

### Step 6 — Teach the computer and grade it

Now run the second program. It reads the table, lets the **model** study it, then quizzes it:

```bash
python train_model.py
```

**What you should see:** two lines, something like:

```
Acc:0.995 Pre:1.000 Rec:0.800
Logged to logs/experiments.txt
```

**What this program says, in plain words** (open `train_model.py` to follow along):

1. `import ...` — Borrow toolkits for tables, dates, and the learning robot.
2. `df = pd.read_csv('../data/transactions.csv')` — Open the table we made in Step 5.
3. `X = df[['amount', 'time']]` — `X` is the *clues* we learn from: the amount and the time.
4. `y = df['is_fraud']` — `y` is the *answer* we want to guess: fraud or not.
5. `train_test_split(... test_size=0.2 ...)` — This is the **train/test split**. Put 80% of the
   examples in a "study" pile and keep 20% hidden in a "quiz" pile. Like studying most of your
   flashcards, then testing yourself on the rest you haven't seen.
6. `model = DecisionTreeClassifier(max_depth=5, random_state=42)` — Build a **decision tree**:
   a robot that plays a game of yes/no questions ("Is the amount over $800? Is the time before
   6am?"). `max_depth=5` means it may ask at most 5 questions in a row.
7. `model.fit(X_tr, y_tr)` — Let the robot study the study pile. **This is training.**
8. `y_pred = model.predict(X_te)` — Ask the robot to guess on the quiz pile it never saw.
9. The three scores:
   - `accuracy_score` → **accuracy**: how often it was right overall (like a test grade).
   - `precision_score` → **precision**: when it yelled "fraud!", how often it was really right.
   - `recall_score` → **recall**: of all the real fraud, how much did it catch.
10. `print(f'Acc:... Pre:... Rec:...')` — Show those three scores on the screen.
11. `os.makedirs('../logs', ...)` and the `with open(...)` block — Make a `logs` folder and
    *add* (not replace) one line with today's date and the three scores to `experiments.txt`.
    Every run leaves its own line, so you build up a history by hand.

> **Why three scores, not one?** Fraud is rare. A lazy model could say "nothing is fraud ever"
> and still be right 98% of the time (high accuracy!) while catching zero fraud (recall = 0).
> That's why precision and recall matter — they show what accuracy hides.

### Step 7 — Read your handwritten experiment log

Every run added a line to a log file. Look at it:

```bash
cat ../logs/experiments.txt
```

**What you should see:** one line per run, each with a date/time and the three scores, like:

```
2026-06-15 23:21|acc=1.000|prec=0.000|rec=0.000
```

This little file is your experiment notebook — kept by hand for now. In **Chapter 04** you'll
swap this manual file for a tool that keeps the notebook for you automatically.

---

## Try it yourself (mini challenges)

- 🔧 **Catch more fraud.** In `generate_data.py`, change `n = 1000` to `n = 5000` and rerun
  both programs. More examples often means the model learns better. Did recall change?
- 🔧 **Change the fraud rule.** Change `amounts > 800` to `amounts > 400` in `generate_data.py`,
  rerun both, and watch how the counts and scores shift.
- 🔧 **Give the robot fewer questions.** In `train_model.py`, change `max_depth=5` to
  `max_depth=1`. Rerun it. A robot allowed only one question usually scores worse — see for yourself.
- 🔧 **Build up your log.** Run `python train_model.py` three times, then `cat ../logs/experiments.txt`.
  Notice it now has three lines. You're keeping a history by hand.

## If something breaks

- **`python: command not found`** → Try `python3` instead. On Windows use `python`.
- **`No module named pandas` (or sklearn / numpy)** → Your toolbox isn't on, or the helpers
  aren't installed. Make sure your prompt shows `(venv)`, then redo Step 2 and Step 3.
- **`No such file or directory: '../data/transactions.csv'`** → You ran `train_model.py` before
  `generate_data.py`. Run `python generate_data.py` first.
- **`can't open file 'generate_data.py'`** → You're in the wrong folder. Make sure you did
  `cd src` (Step 4). Type `ls` to confirm you see the `.py` files.
- **Precision or recall shows `0.000`** → Totally normal here. Fraud is rare, so by luck the
  quiz pile may contain few or no fraud cases. Try the `n = 5000` challenge above.

## What you just learned

- A **dataset** is just a table of examples, and you can make one in code.
- A **model** learns patterns from examples — this is **machine learning**.
- **Training** is letting the model study; the **train/test split** keeps the quiz fair.
- A **decision tree** decides by asking yes/no questions.
- **Accuracy**, **precision**, and **recall** measure quality in three different ways, and you
  need more than just accuracy when the thing you're hunting (fraud) is rare.
- You kept an experiment log by hand — a habit Chapter 04 will automate.

## Where to next

➡ [Chapter 03 — Teach the computer to spot trouble](../chapter-03-models). You'll grow this into
two real-world detectors: one for bank fraud, and one that finds odd hospital readings all by itself.
