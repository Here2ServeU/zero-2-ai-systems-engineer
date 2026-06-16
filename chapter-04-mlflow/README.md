# Chapter 04 — Experiment Tracking with MLflow

**Book:** Chapter 4 (Experiment Tracking and Reproducibility) · Lab 4.4
**Layer:** 2 · Data & Models · **You build:** Tracked runs + Model Registry

## What you build

Replace Chapter 2's text-file logging with MLflow. Train three hyperparameter variants,
compare them in the MLflow UI, and register the best run in the Model Registry.

> Reads `../chapter-02-data/data/transactions.csv` — run Chapter 2's `generate_data.py` first.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install mlflow scikit-learn pandas numpy

python train_with_tracking.py --max_depth 3 --min_samples 2
python train_with_tracking.py --max_depth 8 --min_samples 5
python train_with_tracking.py --max_depth 6 --criterion entropy

mlflow ui    # open http://127.0.0.1:5000 -> select runs -> Compare
python register_best_model.py
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we use **MLflow** — a notebook that automatically writes down how well each try
did. This is called **experiment tracking**, which is a fancy way of saying *keeping
score*. At the end we put our best try on a **model registry** — a trophy shelf where
you keep the best model.

### `train_with_tracking.py` — try a guess, and let MLflow keep score

**In one sentence:** This file trains a fraud-spotting model one time and writes down the
settings it used and how good it turned out.

**What it does, step by step:**

1. It opens a list of dials you can turn before training. These dials are called
   `--max_depth`, `--min_samples`, and `--criterion`. You set them when you start the
   script. If you do not set them, the script uses safe default numbers.
2. It opens a big table of past money transactions (the file `transactions.csv`) and
   reads it in.
3. It picks two clues to look at — the `amount` of money and the `time` — and the answer
   it wants to learn — was it fraud or not (`is_fraud`).
4. It splits the table into two piles: a big pile to learn from and a small pile to test
   itself on later. This is like studying with most of your flashcards and saving a few
   to quiz yourself.
5. It tells MLflow, "Start a new try now and keep score." Then it writes down which dial
   settings it used so we never forget them.
6. It builds a little decision-tree model (a model that asks yes/no questions to make a
   guess) using your dial settings, and lets it study the big pile.
7. It quizzes the model on the small pile and counts how often it was right. It writes
   down three scores: accuracy, recall, and f1 (different ways of measuring "how good").
8. It saves the trained model itself into MLflow and prints the recall score on the
   screen so you can see it.

**What you get:** One scored "try" saved in MLflow. Run it a few times with different
dials, and MLflow remembers every try so you can compare them.

### `register_best_model.py` — put the winner on the trophy shelf

**In one sentence:** This file looks at all your tries, finds the one with the best score,
and moves it to the trophy shelf so it is easy to find and use later.

**What it does, step by step:**

1. It opens a helper that can talk to MLflow and read all your saved tries.
2. It finds the group of tries named `fraud-detection-v1` (the experiment you ran).
3. It asks MLflow for every try in that group, sorted from best to worst by the
   **recall** score. The very first one in the line is the winner.
4. It grabs the winner's special address (its "run id") so it knows exactly which model
   to pick up.
5. It places that winning model on the trophy shelf, the **model registry**, under the
   name `FraudDetectionModel`.
6. It prints which version number the winner got (version 1, then 2, and so on each time
   you register a new winner).

**What you get:** Your best model, picked by recall score, sitting safely on the trophy
shelf with a clear name and version number — ready for the next chapter to use.

➡ Next: [chapter-05-api](../chapter-05-api) — serve the model behind a Flask API.
