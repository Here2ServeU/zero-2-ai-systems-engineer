# Chapter 06 — Containerization with Docker

**Book:** Chapter 6 (Containerization with Docker) · Lab 6.3
**Layer:** 3 · APIs & Containers · **You build:** A portable image of the fraud API

## What you build

The Chapter 5 API packaged into an immutable Docker image with layer caching, a
non-root user, and a small base image — plus a `docker-compose.yml` for one-command
startup. (`app/` here is copied from Chapter 5, exactly as the book's lab does.)

## Build & run

```bash
docker build -t nawex-fraud-api:v1.0 .
docker run -d -p 5000:5000 --name fraud-api nawex-fraud-api:v1.0
docker ps
curl http://localhost:5000/health
docker logs fraud-api
docker stop fraud-api && docker rm fraud-api

# Or the whole thing with compose:
docker compose up -d
docker compose down
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we put our little fraud-checking program into a **lunchbox** so it works the
same on every computer. The fancy word for that lunchbox is a **container**, and the
tool that makes it is called **Docker**.

### `Dockerfile` — the recipe for the lunchbox

**In one sentence:** This file is the recipe that tells Docker how to build the lunchbox
(the **image**) that holds our program.

**What it does, step by step:**

1. `FROM python:3.11-slim` — Start with a small, ready-made box that already has Python
   inside. "slim" means it is a tiny box with only the parts we need, so it stays light.
2. `LABEL ...` — Stick name tags on the box (who made it, the program name, the version).
   These are just sticky notes; they do not change how it runs.
3. `ENV ...` — Set a few rules for inside the box: do not leave messy leftover files,
   print messages right away, and run in "production" mode (the grown-up, careful mode).
4. `WORKDIR /app` — Pick a room inside the box called `/app` and do all our work there.
5. `COPY requirements.txt .` — Copy in our shopping list of helpers first (see the
   `requirements.txt` part below). We copy it first on purpose so Docker can remember
   ("cache") the helpers and not re-download them every time we change our code.
6. `RUN pip install --no-cache-dir -r requirements.txt` — Go shopping: install all the
   helpers on the list. `--no-cache-dir` means do not keep the receipts, to save space.
7. `COPY app/ .` — Now copy our actual program files into the box.
8. `RUN useradd -m appuser` and `USER appuser` — Make a regular, non-boss user named
   `appuser` and switch to it. Running as the boss ("root") is risky, so we use a plain
   user to stay safe.
9. `EXPOSE 5000` — Tell the box to open a little window numbered 5000 so people outside
   can talk to our program.
10. `CMD ["python", "api.py"]` — When the box turns on, start the program by running
    `api.py`.

**What you get:** A complete recipe that bakes our fraud program into one neat, safe,
portable lunchbox that runs the same anywhere.

### `docker-compose.yml` — a way to start the lunchbox with one button

**In one sentence:** This file lets you start (and later stop) the lunchbox with a single
short command instead of typing many long ones.

**What it does, step by step:**

1. `version: '3.8'` — Tells Docker which rulebook version we are using.
2. `services:` — Lists the programs we want to run. We have one, called `fraud-api`.
3. `build: .` — Build the lunchbox using the recipe (the `Dockerfile`) in this folder.
4. `image: nawex-fraud-api:v1.0` — Give the finished lunchbox a name and a version number.
5. `ports: ['5000:5000']` — Connect window 5000 on your computer to window 5000 inside
   the box, so you can visit it in a browser.
6. `environment: - FLASK_ENV=production` — Run in the careful grown-up mode.
7. `restart: unless-stopped` — If the program falls down, stand it back up automatically,
   unless you told it to stop on purpose.
8. `healthcheck:` — Every 30 seconds, poke the program at `/health` to make sure it is
   still feeling okay. Try 3 times before deciding it is sick.

**What you get:** One simple command (`docker compose up -d`) turns the whole thing on,
keeps it healthy, and restarts it if it trips.

### `app/model.py` — the brain that guesses fraud

**In one sentence:** This file builds and uses a tiny "brain" (a machine-learning model)
that looks at a payment and guesses whether it is fraud or okay.

**What it does, step by step:**

1. It lists the clues it looks at (`FEATURES`), like the dollar amount, the hour of day,
   and whether it was a weekend.
2. `load_model()` — Makes 2,000 pretend payments to practice on, then trains a
   "decision tree" (a yes/no question game) to spot fraud. It prints how good it got.
3. `predict_one(...)` — Takes one real payment, asks the trained brain, and gives back an
   answer: `FRAUD` or `LEGIT`, plus how sure it is and which version of the brain answered.

**What you get:** A small, trained brain that can take payment clues and say "this looks
like fraud" or "this looks fine."

### `app/api.py` — the front desk that people talk to

**In one sentence:** This file is the front desk (a web service) that takes requests from
the internet, checks them, asks the brain, and sends back an answer.

**What it does, step by step:**

1. It starts a tiny web server using Flask (a helper for making web services) and loads
   the brain from `model.py`.
2. `validate(...)` — Checks that the visitor sent all the needed clues and that they are
   the right kind (numbers where numbers belong, hour between 0 and 23).
3. `/health` — A door you can knock on to ask "are you alive?" It answers "healthy."
4. `/info` — A door that tells you the program's name, version, and author.
5. `/predict` — The main door. Send it a payment, it checks it, asks the brain, and
   returns `FRAUD` or `LEGIT` with a unique ticket number for that request.
6. The last lines start the server listening on window 5000 for everyone.

**What you get:** A working web front desk that people and other programs can send
payments to and get a fraud answer back.

### `requirements.txt` — the shopping list

**In one sentence:** This is a shopping list of the helper tools our program needs.

**What it does, step by step:**

1. `flask` — the helper that builds the web front desk.
2. `scikit-learn` — the helper that builds the fraud-guessing brain.
3. `pandas` — the helper that holds our pretend payments in a neat table.
4. `numpy` — the helper that does fast number-crunching.

**What you get:** A simple list so Docker can buy (install) every helper our program needs
in one go.

➡ Next: [chapter-07-terraform](../chapter-07-terraform) — provision a real cloud server as code.
