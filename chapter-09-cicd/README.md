# Chapter 09 — CI/CD with GitHub Actions

**Book:** Chapter 9 (CI/CD for MLOps) · Lab 9.2
**Layer:** 5 · Automation & Orchestration · **You build:** An automated test/train pipeline

## What you build

A GitHub Actions workflow that, on every push to `main`, creates a fresh venv, installs
dependencies, regenerates the Chapter 2 dataset, and re-trains/validates the model.

The workflow lives at the repository root (where GitHub looks for it):

➡ **[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)**

It runs the Chapter 2 scripts via `cd chapter-02-data/src`, which resolves correctly because the
chapter folders sit at the repo root — exactly the `~/ai-ml-engineer` workspace the book builds.

## Trigger

```bash
git add .github/ && git commit -m "Add CI pipeline" && git push
# Watch: github.com/<you>/<repo>/actions
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. This chapter's
"script" is the robot helper's to-do list that runs every time you save your work.

CI/CD means a robot helper that checks and ships your work automatically every time you
save it to GitHub. GitHub Actions is the place that robot lives. A workflow is the robot's
to-do list. A job is one big chore. A step is one small task inside that chore.

### `ci.yml` — the robot helper's to-do list

**In one sentence:** Every time you save your code to GitHub, a robot helper wakes up,
builds your project from scratch, makes the practice data, and trains the model to make
sure nothing is broken.

**What it does, step by step:**

1. **Names the robot's list.** It calls the to-do list "Nawex AI Pipeline" so you know
   what it is.
2. **Says what wakes the robot up.** The robot starts working when you `push` (save) new
   code to the `main` branch, or when someone opens a `pull_request` (asks to add changes)
   to `main`. This "wake up" rule is called a trigger.
3. **Picks a clean computer to work on.** The job `build-and-test` runs on a fresh
   `ubuntu-latest` machine — like a brand-new clean desk every time.
4. **Step one — grab the code.** It checks out (downloads) a copy of your code onto that
   clean machine.
5. **Step two — set up Python.** It installs Python version 3.11, the language the project
   speaks.
6. **Step three — build a little sandbox and install tools.** It makes a `venv` (a private
   toy box just for this project) and installs the helper tools `pandas` and
   `scikit-learn` inside it.
7. **Step four — make the practice data.** It goes into the Chapter 2 folder and runs
   `generate_data.py` to create the pretend data to learn from.
8. **Step five — train and check the model.** It runs `train_model.py` to teach the model
   and make sure it still works.

**What you get:** A tireless robot that rebuilds and re-tests your project every single
time you save it to GitHub, so you find out right away if something breaks.

➡ Next: [chapter-10-kubernetes](../chapter-10-kubernetes) — orchestrate the container.
