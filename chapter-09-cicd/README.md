# Chapter 09 — A robot helper that checks your work (CI/CD)

> Matches **Chapter 09** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 🌐 Needs the internet · 🧑‍🤝‍🧑 Easier with a helper the first time

---

## The big idea (in plain words)

Every time you change your code, *something* could break — even a tiny typo. Checking by hand,
every single time, is tiring and easy to forget. So we hire a **tireless robot helper**.

Here's the deal: every time you save your code up to **GitHub** (you learned this is a website
that stores your project online), the robot helper wakes up, grabs a fresh clean computer,
rebuilds your project from scratch, and re-runs your checks. If anything is broken, it tells you
right away. If everything's fine, it gives a quiet green check mark.

That pattern — *automatically re-checking your work every time you change it* — is called
**CI/CD**. On GitHub, the robot helper is called **GitHub Actions**. You tell the robot what to
do by writing its to-do list in a file called a **workflow**.

> 🧑‍🤝‍🧑 **Easier with a helper the first time.** Connecting your project to GitHub and
> reading the robot's report has a few fiddly first-time steps. A friend who's done it before
> makes it smooth. Good news: a **free** GitHub account is all you need — **no credit card**.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **GitHub** — A website that stores your project online.
- **Push** — Send your saved snapshots up to GitHub.
- **CI/CD** — A robot helper that automatically checks (and ships) your code every time you
  change it.
- **GitHub Actions** — GitHub's built-in robot helper for CI/CD.
- **Workflow** — The robot's to-do list, written in a file.
- **Job** — One big chore on the list.
- **Step** — One small task inside a chore.
- **Trigger** — The rule that says what *wakes the robot up*.

## What you will build

You'll set up a workflow file so that **every time you push code, the robot automatically**:
rebuilds your project on a clean machine, makes the practice data, and re-trains the model to
make sure nothing broke. Then you'll change one line, push it, and watch the robot run.

---

## How the robot's to-do list works (`ci.yml`)

GitHub looks for the robot's to-do list in a special spot: a folder named `.github/workflows/`.
The file there is `ci.yml`. Here's the whole thing — we'll read it block by block:

```yaml
name: Zero2AI Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Create venv and install deps
        run: |
          python -m venv venv
          source venv/bin/activate
          pip install pandas scikit-learn

      - name: Generate training data
        run: |
          source venv/bin/activate
          cd chapter-02-data/src
          python generate_data.py

      - name: Train and validate model
        run: |
          source venv/bin/activate
          cd chapter-02-data/src
          python train_model.py
```

### `name:` — what the robot's list is called

```yaml
name: Zero2AI Pipeline
```

Just a friendly label so you recognize this to-do list among others.

### `on:` — what wakes the robot up (the trigger)

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

This is the **trigger**. It says the robot should start working when you **push** (save) new
code to the `main` line of work, *or* when someone opens a **pull request** (a polite "may I add
these changes?") aimed at `main`.

### `jobs:` — the chores

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
```

There's one chore here, named `build-and-test`. `runs-on: ubuntu-latest` means it runs on a
**fresh, clean computer** every time — like a brand-new clean desk with nothing left over from
last time. That freshness is exactly what makes the check trustworthy.

### `steps:` — the small tasks, in order

Each step is one small task. In plain words:

1. **Checkout code** — download a copy of your code onto the clean machine.
2. **Set up Python 3.11** — install the Python language the project speaks.
3. **Create venv and install deps** — make a `venv` (a clean private toolbox just for this
   project) and install the helper tools `pandas` and `scikit-learn`.
4. **Generate training data** — go into the Chapter 2 folder and run `generate_data.py` to make
   the practice data.
5. **Train and validate model** — run `train_model.py` to teach the model and confirm it still
   works.

If any step fails, the robot stops and shows a red X with the error. If all pass, you get a
green check.

## Let's try it (gently)

You can actually do this — it's free. Take it one small step at a time, ideally with a helper
nearby the first time.

### Step 1 — Make sure your project is on GitHub

If your project folder is already pushed to GitHub, great. If not, this is the fiddly part where
a helper shines: you'll create a free account at **github.com**, make a new empty repository,
and push your project up to it. (You installed **Git** back in Chapter 01.)

### Step 2 — Add the robot's to-do list

1. In your project, create a folder path exactly: `.github/workflows/`
   (the leading dot matters — it's how GitHub finds it).
2. Inside it, create a file named `ci.yml`.
3. Paste in the workflow shown above and **save**.

> ⚠️ YAML files care about spaces. Each indent is **two spaces**, never a tab. If lines don't
> line up, the robot can't read its list. This is the most common first-time snag.

### Step 3 — Push it up

In your terminal, type these one at a time:

```bash
git add .github/
git commit -m "Add CI pipeline"
git push
```

- `git add .github/` — gather the new folder for saving.
- `git commit -m "..."` — take a snapshot with a short note.
- `git push` — send the snapshot up to GitHub. **This wakes the robot.**

### Step 4 — Watch the robot work

1. Open your repository on GitHub in a web browser.
2. Click the **Actions** tab at the top.
3. You'll see your run, "Zero2AI Pipeline," start ticking through its steps.
4. Wait for it to finish: a green check ✅ means everything passed; a red X ❌ means a step
   failed — click it to read which one and why.

🎉 You just hired a tireless helper that re-checks your project every single time you save it.

---

## Try it yourself (mini challenges)

- 🔧 **Change one line and watch.** Edit a comment or a `print(...)` line in a Chapter 2 file,
  then push. Watch a brand-new run appear in the Actions tab.
- 🔧 **Read the trigger.** In `ci.yml`, find the part that decides *what wakes the robot up*.
  What two things start it? Which branch does it watch?
- 🔧 **Find a tool.** Which step installs `pandas` and `scikit-learn`? What command does the
  installing?
- 🔧 **Break it on purpose (safely).** Introduce a tiny typo in a Chapter 2 script, push, and
  watch the robot turn red and tell you. Then fix it and watch it go green again. Seeing the
  robot *catch* a mistake is the whole point.

## If something breaks

- **No run appears in the Actions tab** → The file may be in the wrong place. It must be at
  exactly `.github/workflows/ci.yml`. Check the leading dot and the spelling.
- **`Invalid workflow file` / YAML error** → Almost always indentation. Use **two spaces** per
  indent, never tabs. Compare your file line-by-line to the example.
- **A step shows a red X** → That's the robot doing its job. Click the failed step to read the
  error, fix the cause in your code, then push again.
- **`git push` is rejected** → Your local copy is behind GitHub. Run `git pull` first, then
  push again. (A good moment to ask your helper.)
- **Actions tab is empty or disabled** → On some repositories Actions must be turned on once in
  the repository's **Settings → Actions**.

## What you just learned

- **CI/CD** means a robot helper that re-checks your work automatically every time you change it.
- On GitHub, that helper is **GitHub Actions**, and you tell it what to do with a **workflow**
  file at `.github/workflows/ci.yml`.
- A workflow has a **trigger** (what wakes it), **jobs** (big chores), and **steps** (small
  tasks in order).
- Running on a **fresh, clean machine** every time is what makes the check trustworthy.
- A free GitHub account is enough — no credit card needed.
- A red X isn't failure on your part; it's the robot catching a problem early, which is exactly
  what you wanted.

## Where to next

➡ [Chapter 10 — Run many copies safely (Kubernetes)](../chapter-10-kubernetes). You'll meet a
playground manager that runs many copies of your app and restarts any that fall over.
