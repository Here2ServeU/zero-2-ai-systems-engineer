# Chapter 14 — Release changes without scary surprises

> Matches Chapter 14 in the book.

**Labels:** Phase 1 runs free on your laptop · Phases 2 and 3 need an account that may cost money · Needs the internet (Phases 2 and 3)

---

## The big idea (in plain words)

Imagine you cooked a brand-new recipe for a big party. Would you serve it to all 100 guests
right away? Probably not. You'd let a few guests taste it first. If they love it, you serve
everyone. If they make a face, only a few people got the so-so dish, not the whole party.
Releasing software safely works the same way.

There are three gentle tricks for this, and you'll try all three in this chapter:

1. **Canary release** — let only a *small slice* of people try the new version first (like a
   few guests tasting the new recipe). If it goes well, you let more people in.
2. **Blue/green** — keep the *old* kitchen running while you test the *new* one. When the new
   one is ready, you flip a switch so everyone uses it, and if it misbehaves, you flip the
   switch right back to the old kitchen.
3. **Feature flag** — a simple on/off **light switch** in your code. You can turn a new feature
   on or off in an instant, without rebuilding anything.

Notice the theme: never bet everything at once, and always keep a fast way back.

## The platform you are building

In this chapter you build a **progressive delivery platform**: a way to release a new version to
a few users first, grow it step by step, switch everyone over in one move, and **roll back
instantly** if anything looks wrong. Companies like banks, shops and streaming services ship
changes many times a day, and one bad release can cost millions or make the news, so they pay
for systems that make releases boring and safe. The people who build them are called **Release
Engineers**, **DevOps Engineers**, **Site Reliability Engineers (SREs)** and **Platform
Engineers**.

## How this builds on Chapter 13

In Chapter 13 your platform learned to retrain the model and put each approved version on a
numbered shelf (the MLflow model registry). But an approved model is only *approved*. Nobody is
using it yet. Swapping the model inside a live fraud checker is a risky change: if the new
version is wrong, every payment gets the wrong answer. This chapter is how you release a change
like that safely.

What carries over:

- **Chapter 10's fraud API:** the cloud track runs the *same* fraud API image as Chapter 10,
  built from [`../chapter-10-kubernetes/fraud-api`](../chapter-10-kubernetes/fraud-api), as two
  copies. The only difference between them is two settings, `APP_VERSION` and `APP_COLOR`, so its
  `/info` page tells you which copy answered.
- **Chapter 10's platform:** the EKS cluster, the shared Helm chart (which already has
  blue/green and canary switches built in), and the shared load balancer (ALB) on port 8014.
- **Chapter 13's idea of a gate:** there, a model had to pass a quiz before it was kept. Here, a
  release has to stay healthy before it gets more traffic, and Helm undoes a release that fails
  its health checks.

What is new:

- Two copies running side by side (**blue** = today's version, **green** = the new one).
- A **switch** that moves all traffic at once, and a **canary** that moves it a slice at a time.
- **Instant rollback**, by hand or automatically.

```text
Your platform so far

  Chapter 10 (platform)       Chapters 11-13                     Chapter 14 (new: release safely)
  +-----------------------+   +----------------------------+    +---------------------------------+
  | EKS cluster, Helm     |   | metrics + alerts (11)      |    | blue  = fraud API v1.0.0 (90%)  |
  | chart, fraud API      |   | a guard that acts (12)     |    | green = fraud API v2.0.0 (10%)  |
  | shared ALB  ----------|---|----------------------------|--->| canary split, switch, rollback  |
  +-----------------------+   | retrain + model registry   |    +---------------------------------+
                              | (13) -> a new version to   |
                              |   release safely           |
                              +----------------------------+
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **Phase 1 — Build it on your laptop** (this page) | Your computer | Write a canary router, a feature flag and a blue/green switch, then run real blue and green copies of the fraud API in containers | Free |
| **Phase 2 — Promote it to the cloud** ([cloud/README.md](cloud/README.md)) | AWS EKS | **2A:** blue/green with plain YAML and one switch. **2B:** the same with Helm, and rollback with one command | Costs money while the platform runs. Destroy it when done. |
| **Phase 3 — Run it like a Fortune 500 company** ([cloud/PRODUCTION.md](cloud/PRODUCTION.md)) | AWS EKS | A real canary split by the load balancer, automatic rollback of a broken release, autoscaling and hardening, a runbook | Costs money while the platform runs. Destroy it when done. |

You can stop after Phase 1 and still have learned the whole idea.

## New words

Look up anything else in the [GLOSSARY](../GLOSSARY.md).

- **Release** — Handing a new version of your program to real users.
- **Canary release** — Showing a new version to a tiny slice of users first, to catch problems
  before everyone sees them. (Named after the canary birds miners once used to spot danger early.)
- **Blue/green** — Keeping two copies (old "blue" and new "green") and switching traffic over
  instantly, so you can switch back fast if needed.
- **Feature flag** — An on/off switch in your code for turning features on or off without
  rebuilding.
- **Rollback** — Going back to the last version that worked.
- **Deployment** — Putting your program where real people can use it.
- **Model** — The "thinking" part of our app that looks at a payment and guesses *safe* or
  *risk*.
- **Environment variable** — A setting you hand to a program from the outside when it starts,
  like `APP_COLOR=green`. Same program, different settings.

## What you will build

Four tiny Python files that, together, show all three safe-release tricks:

- `models.py` — an **old** model we trust and a **new** model we're testing, side by side.
- `router.py` — a traffic cop that sends only 1 in 5 visitors to the new model (the canary).
- `feature_flag.py` — an on/off switch for the new model.
- `switch.py` — a blue/green switch with a panic "undo" button.

Then you'll run **real** blue and green copies of Chapter 10's fraud API in containers, and send
a canary slice of visits to green.

---

## Phase 1 — Build it on your laptop

Everything in Phase 1 is free and runs on your own computer.

**You need:** Python 3 (check with `python3 --version`), and for the last step, Docker Desktop
(from Chapter 06) and this repo downloaded on your computer.

### Step 1 — Make a practice folder and a clean toolbox

Open your **terminal** (in VS Code: **Terminal → New Terminal**) and type these one at a time:

```bash
mkdir my-releases
cd my-releases
python3 -m venv venv && source venv/bin/activate
pip install flask pandas
```

- `mkdir my-releases` makes a new, empty folder for your practice files, and `cd my-releases`
  moves you into it.
- The third line makes a **virtual environment** (a clean, private toolbox just for this
  project) and turns it on. You'll see `(venv)` appear at the start of your prompt: that means
  the toolbox is active.
- The last line installs two helper tools the book uses in this chapter. (Today's four files
  only need plain Python, so even if this step gives you trouble, Steps 2 to 5 still work.)

**What you should see:** your prompt now starts with `(venv)`, and `pip` prints a few lines
ending in something like `Successfully installed flask-... pandas-...`.

> **On Windows:** if `source venv/bin/activate` doesn't work, use
> `venv\Scripts\activate` instead, and type `python` wherever this page says `python3`.

> This repo's `chapter-14-deployment/src` folder already has finished copies of the four files.
> Typing them yourself is how you really learn them. If you get stuck, compare with those.

### Step 2 — Create the four files

In VS Code, open your `my-releases` folder, then make four new files and type in the code below.

**`models.py`** — the old recipe and the new recipe:

```python
# models.py
def old_model(data):
    return 'safe'

def new_model(data):
    if data.get('value', 0) > 50:
        return 'risk'
    return 'safe'
```

**What each line says, in plain words:**

- `old_model` is the safe, boring helper. No matter what you give it, it always answers
  `'safe'`. Like an old cookie recipe that never fails.
- `new_model` is the new helper we're testing. It peeks at a number called `value`. If that
  number is bigger than 50, it says `'risk'`; otherwise it says `'safe'`.

**`router.py`** — the traffic cop that does the canary split:

```python
# router.py
import random
from models import old_model, new_model

usage = {'old':0, 'new':0}
CANARY = 0.20

def route_request(data):
    if random.random() < CANARY:
        usage['new'] += 1
        return 'new_model', new_model(data)
    usage['old'] += 1
    return 'old_model', old_model(data)

def get_usage_stats():
    total = usage['old'] + usage['new'] or 1
    return {
        'old_pct': usage['old']/total*100,
        'new_pct': usage['new']/total*100,
        'total': total
    }
```

**What each line says, in plain words:**

- `usage = {'old':0, 'new':0}` — two tally counters, both starting at zero, to count who got
  which model.
- `CANARY = 0.20` — the canary slice: `0.20` means 20 out of every 100 visitors (1 in 5) get
  the new model. The other 80 get the old, trusted one.
- `route_request` rolls a dice with `random.random()` (a random number between 0 and 1). If it
  lands under `0.20`, this visitor gets the **new** model; otherwise the **old** one. Either
  way, it adds 1 to the matching tally.
- `get_usage_stats` does the math and reports what percent went old, what percent went new, and
  the total number of visitors. (`or 1` stops it dividing by zero before anyone has visited.)

**`feature_flag.py`** — the on/off light switch:

```python
# feature_flag.py
USE_NEW_MODEL = False

def toggle_new_model():
    global USE_NEW_MODEL
    USE_NEW_MODEL = not USE_NEW_MODEL
    state = 'ON' if USE_NEW_MODEL else 'OFF'
    print(f'New model: {state}')

def is_new_model_enabled():
    return USE_NEW_MODEL
```

**What each line says, in plain words:**

- `USE_NEW_MODEL = False` — the switch starts in the **OFF** position. The new model is hidden
  for now.
- `toggle_new_model` is the finger that flips the switch: OFF becomes ON, ON becomes OFF. It
  prints the new state so you can see it. (`global` lets the function change the switch that
  lives outside it.)
- `is_new_model_enabled` just looks at the switch and answers `True` (ON) or `False` (OFF).

**`switch.py`** — the blue/green switch with an undo button:

```python
# switch.py
ACTIVE_ENV = 'blue'

def get_active():
    return ACTIVE_ENV

def switch_environment():
    global ACTIVE_ENV
    ACTIVE_ENV = 'green' if ACTIVE_ENV=='blue' else 'blue'
    print(f'Switched to: {ACTIVE_ENV}')

def rollback():
    global ACTIVE_ENV
    ACTIVE_ENV = 'blue'
    print('Rolled back to previous stable (blue)')
```

**What each line says, in plain words:**

- `ACTIVE_ENV = 'blue'` — "blue" is the safe, old copy that people are using right now.
- `get_active` simply tells you which copy is live.
- `switch_environment` flips the two copies: if blue is live it makes green live, and the other
  way around.
- `rollback` is the emergency **undo** button: it always jumps straight back to blue, the copy
  we trust.

Save all four files (Ctrl+S, or Cmd+S on Mac).

### Step 3 — Watch the canary (1 in 5 gets the new model)

Make sure your terminal is in your `my-releases` folder (the one that holds these four files),
with `(venv)` showing. Then run:

```bash
python -c "import router; [router.route_request({'value':99}) for _ in range(100)]; print(router.get_usage_stats())"
```

This one line sends 100 pretend visitors through the traffic cop, then prints the tally.

**What you should see:** something close to this (your exact numbers will wobble a little
because of the dice roll):

```
{'old_pct': 80.0, 'new_pct': 20.0, 'total': 100}
```

About 80% got the old model and about 20% got the new one: exactly the canary slice we set.
You might see 78/22 or 84/16; that's normal randomness.

### Step 4 — Flip the feature flag

From the same folder, run:

```bash
python -c "import feature_flag as f; f.toggle_new_model(); print(f.is_new_model_enabled())"
```

This flips the switch once, then asks whether the new model is now on.

**What you should see:**

```
New model: ON
True
```

The new model is now turned on, instantly, with no rebuilding. That's the magic of a feature
flag.

### Step 5 — Switch and roll back (blue/green)

From the same folder, run:

```bash
python -c "import switch as s; s.switch_environment(); s.rollback()"
```

This flips from blue to green, then immediately hits the undo button to return to blue.

**What you should see:**

```
Switched to: green
Rolled back to previous stable (blue)
```

You just moved everyone to the new "green" kitchen and then snapped them back to the safe
"blue" one in a single step. That fast way back is what makes releases feel safe instead of
scary.

### Step 6 — Pack it in a container: real blue and green copies

So far, "blue" and "green" were just words in a variable. Now let's run two **real** copies of a
real app, side by side, the way the cloud will. We'll use the fraud API from Chapter 10 (it
checks payments for fraud). Its `/info` page reports two **environment variables**:
`APP_VERSION` and `APP_COLOR`. So we can start the *same* image twice with different settings,
and each copy will tell us who it is.

Make sure **Docker Desktop** is running. Then, from this repo's **`chapter-14-deployment`**
folder (not your practice folder), build the image:

```bash
docker build -t zero2ai-fraud-api:v1.0 ../chapter-10-kubernetes/fraud-api
```

- `-t zero2ai-fraud-api:v1.0` gives the image a name and a version tag.
- `../chapter-10-kubernetes/fraud-api` is the folder with the Dockerfile (`..` means "go up one
  folder").

**What you should see:** Docker works through the recipe (the `pip install` step takes a minute
the first time) and finishes with a line like
`naming to docker.io/library/zero2ai-fraud-api:v1.0`.

Now start **two copies** of the same image, from any folder:

```bash
docker run -d --name fraud-blue  -p 5001:5000 -e APP_VERSION=1.0.0 -e APP_COLOR=blue  zero2ai-fraud-api:v1.0
docker run -d --name fraud-green -p 5002:5000 -e APP_VERSION=2.0.0 -e APP_COLOR=green zero2ai-fraud-api:v1.0
```

- `-d` runs the copy in the background, so you get your terminal back.
- `--name fraud-blue` gives the copy a name you can use later.
- `-p 5001:5000` connects door **5001** on your laptop to door 5000 inside the box. Green uses
  door **5002**, so the two don't bump into each other.
- `-e APP_COLOR=blue` hands the copy a setting. This is the only thing that differs.

**What you should see:** each command prints one long ID, like `ff330f09099a...`.

Wait about 5 seconds (each copy trains its small model when it starts), then ask each one who
it is:

```bash
curl http://localhost:5001/info
curl http://localhost:5002/info
```

**What you should see:**

```
{"author":"Rev Dr Emmanuel Naweji","color":"blue","name":"Zero2AI Fraud API","program":"Zero2AI","version":"1.0.0"}
{"author":"Rev Dr Emmanuel Naweji","color":"green","name":"Zero2AI Fraud API","program":"Zero2AI","version":"2.0.0"}
```

Same image, two copies, two answers. That's blue/green for real: the new version (green) is
running and healthy *before* anyone is sent to it. You can also open
http://localhost:5001/info and http://localhost:5002/info in your browser.

> **On Windows PowerShell,** type `curl.exe` instead of `curl`.

Now let's be the traffic cop for real. Go back to your **`my-releases`** folder and make one more
file, **`canary_visits.py`**. It's `router.py`'s dice roll, but each visit goes to a real copy:

```python
# canary_visits.py
import random, json, urllib.request

CANARY = 0.20
counts = {'blue': 0, 'green': 0}

for _ in range(20):
    port = 5002 if random.random() < CANARY else 5001
    with urllib.request.urlopen(f'http://localhost:{port}/info') as reply:
        counts[json.load(reply)['color']] += 1

print(counts)
```

- `port = 5002 if random.random() < CANARY else 5001` — 1 visit in 5 goes to green's door, the
  rest to blue's.
- `urllib.request.urlopen(...)` visits the page, like `curl` does. `json.load(...)['color']`
  reads which color answered.

Run it from your `my-releases` folder:

```bash
python canary_visits.py
```

**What you should see:** something like `{'blue': 16, 'green': 4}`. The numbers wobble each run,
but most visits go to blue.

**Roll back the canary:** change `CANARY = 0.20` to `CANARY = 0.0` and run it again. You'll see
`{'blue': 20, 'green': 0}`: nobody is sent to green any more, and green is still running if you
want to try again. Change it to `1.0` and everyone goes to green: that's the full switch.

When you're done, stop and remove both copies (from any folder):

```bash
docker rm -f fraud-blue fraud-green
```

**What you should see:** the two names, `fraud-blue` and `fraud-green`, printed back.

**What's still missing?** On your laptop, *you* had to pick the door (5001 or 5002) for every
visit. Real users all use one address. In Phase 2, Kubernetes gives you that single front door
and lets you flip it from blue to green with one command. In Phase 3, the cloud's load balancer
does the 90/10 canary split for you.

### Try it yourself

All of these are run from your `my-releases` folder, with `(venv)` showing.

- **Change the canary percentage.** In `router.py`, change `CANARY = 0.20` to `0.50`, save,
  and run the Step 3 command again. Now about half the visitors should get the new model.
- **Flip the flag twice.** Run
  `python -c "import feature_flag as f; f.toggle_new_model(); f.toggle_new_model(); print(f.is_new_model_enabled())"`.
  You'll see `New model: ON`, then `New model: OFF`, then `False`. Now run the Step 4 command
  twice in a row: both times it says `ON` and `True`. Why? Each `python -c` is a brand-new
  program that starts with the switch OFF. A flag kept in memory is forgotten when the program
  stops. That's why real feature flags live *outside* the code, as settings, like the
  `APP_COLOR` setting you passed with `-e` in Step 6.
- **Try a small payment through the new model.** Run
  `python -c "from models import new_model; print(new_model({'value': 10}))"`. Because 10 is
  not over 50, it prints `safe`. Now try `{'value': 99}` and watch it say `risk`.
- **Roll back from green.** Run
  `python -c "import switch as s; s.switch_environment(); print(s.get_active()); s.rollback(); print(s.get_active())"`.
  You'll see `Switched to: green`, `green`, `Rolled back to previous stable (blue)`, `blue`.

### If something breaks

- **`ModuleNotFoundError: No module named 'models'`** (or `router`, `switch`, `feature_flag`) →
  You're not in the folder that holds the four files, or a file isn't named exactly right (for
  example `models.py.txt`). Use `cd` to move into `my-releases` and check with `ls` (or `dir` on
  Windows).
- **`ModuleNotFoundError: No module named 'flask'`** → Your toolbox (venv) isn't active, or
  Step 1 didn't finish. Re-run `source venv/bin/activate` (you should see `(venv)`), then
  `pip install flask pandas`.
- **`command not found: python`** → Try `python3` instead, or re-check that your venv is
  active.
- **The canary percent looks off (like 15% or 26%)** → That's fine. The dice roll is random,
  so 100 visitors won't split *exactly* 80/20. Send more visitors (change `range(100)` to
  `range(1000)`) and it lands much closer to 20%.
- **`SyntaxError`** → A typo. Most often a missing quote `'` or parenthesis `)`. Compare your
  file to the example, character by character.
- **On Windows, the `python -c "..."` lines give strange errors** → Use the VS Code terminal or
  Command Prompt, and keep the outer quotes as double quotes `"` and the inner ones as single
  quotes `'`, exactly as shown.
- **`Cannot connect to the Docker daemon`** → Docker Desktop isn't running. Start it, wait for
  the whale icon to settle, and try again.
- **`docker build` says `unable to prepare context` or `path not found`** → You're not in this
  repo's `chapter-14-deployment` folder, so `../chapter-10-kubernetes/fraud-api` doesn't exist
  from where you are. `cd` into `chapter-14-deployment` and try again.
- **`Conflict. The container name "/fraud-blue" is already in use`** → An old copy is still
  there. Remove it with `docker rm -f fraud-blue fraud-green`, then run the two `docker run`
  lines again.
- **`Bind for 0.0.0.0:5001 failed: port is already allocated`** → Something else is using that
  door. Pick other doors, for example `-p 5011:5000` and `-p 5012:5000`, and use the same numbers
  in the `curl` commands and in `canary_visits.py`.
- **`curl: (7) Failed to connect` or `Connection reset by peer`, or `canary_visits.py` shows
  `ConnectionRefusedError`** → The copies are still starting. Wait 5 seconds and try again. Still
  failing? Run `docker ps` (both should say `Up`) and `docker logs fraud-blue` (it should end with
  `Running on http://...:5000`).
- **Both copies say `"color":"blue"`** → The `-e APP_COLOR=green` part is missing from the green
  command. Remove the copies and run the two `docker run` lines again, exactly as shown.

### What you learned in Phase 1

- A **canary release** lets only a small slice of users try a new version first, so problems
  stay small.
- **Blue/green** keeps an old copy and a new copy side by side, with an instant flip *and* an
  instant way back.
- A **feature flag** is an on/off switch you can flip in a snap, without rebuilding. Kept only
  in memory it's forgotten on restart, so real flags are settings.
- The **same image** can run as blue and green, told apart only by **environment variables**.
- Together these let you **deploy** changes without scary surprises: there's always a fast path
  back to safety.

## Phase 2 and Phase 3

You just ran blue and green copies on your laptop and did the canary dice roll by hand. Next,
let the cloud do it with real traffic on **AWS EKS**:

1. Build the shared cloud platform once: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
2. **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md). Blue/green with
   one switch, first with plain YAML, then with Helm and one-command rollback.
3. **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md).
   A canary split by the load balancer, automatic rollback, a runbook.

> **Costs money.** The cloud platform costs roughly **$0.10/hour** plus servers and load
> balancers. Get permission if the AWS account isn't yours, and **destroy everything when you
> finish** (every guide ends with a one-line teardown).

## Where to next

[Chapter 15 — Dashboards you can watch (Grafana)](../chapter-15-dashboards/README.md). You'll turn
your program's numbers into live charts you can watch like a car dashboard, which is exactly how
you'd watch a canary before giving it more traffic.
