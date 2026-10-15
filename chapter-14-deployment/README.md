# Chapter 14 — Release changes without scary surprises

> Matches **Chapter 14** in the book. This chapter is about shipping a new version of your
> program *safely*, so a mistake never hurts everyone at once.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

Imagine you cooked a brand-new recipe for a big party. Would you serve it to all 100 guests
right away? Probably not. You'd let a few guests taste it first. If they love it, you serve
everyone. If they make a face, only a few people got the so-so dish — not the whole party.
Releasing software safely works the same way.

There are three gentle tricks for this, and you'll try all three in this chapter:

1. **Canary release** — let only a *small slice* of people try the new version first (like a
   few guests tasting the new recipe). If it goes well, you let more people in.
2. **Blue/green** — keep the *old* kitchen running while you test the *new* one. When the new
   one is ready, you flip a switch so everyone uses it — and if it misbehaves, you flip the
   switch right back to the old kitchen.
3. **Feature flag** — a simple on/off **light switch** in your code. You can turn a new feature
   on or off in an instant, without rebuilding anything.

Notice the theme: never bet everything at once, and always keep a fast way back.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Canary release** — showing a new version to a tiny slice of users first, to catch problems
  before everyone sees them. (Named after canary birds miners once used to spot danger early.)
- **Blue/green** — keeping two copies (old "blue" and new "green") and switching traffic over
  instantly, so you can switch back fast if needed.
- **Feature flag** — an on/off switch in your code for turning features on or off without
  rebuilding.
- **Deployment** — putting your program where real people can use it.
- **Model** — the "thinking" part of our app that looks at a payment and guesses *safe* or
  *risk*.

## What you will build

Four tiny Python files that, together, show all three safe-release tricks:

- `models.py` — an **old** model we trust and a **new** model we're testing, side by side.
- `router.py` — a traffic cop that sends only 1 in 5 visitors to the new model (the canary).
- `feature_flag.py` — an on/off switch for the new model.
- `switch.py` — a blue/green switch with a panic "undo" button.

You'll run small one-line commands and watch each trick work.

---

## Let's do it, one small step at a time

### Step 1 — Make a folder and a clean toolbox

Open your **terminal** (in VS Code: **Terminal → New Terminal**) and type these one at a time:

```bash
python3 -m venv venv && source venv/bin/activate
pip install flask pandas
```

- The first line makes a **virtual environment** (a clean, private toolbox just for this
  project) and turns it on. You'll see `(venv)` appear at the start of your prompt — that means
  the toolbox is active.
- The second line installs two helper tools we'll use.

**What you should see:** your prompt now starts with `(venv)`, and `pip` prints a few lines
ending in something like `Successfully installed flask-... pandas-...`.

> **On Windows:** if `source venv/bin/activate` doesn't work, use
> `venv\Scripts\activate` instead.

### Step 2 — Create the four files

In VS Code, open this chapter's folder, then make four new files and type in the code below.

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
  the total number of visitors.

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
  prints the new state so you can see it.
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
- `rollback` is the emergency **undo** button — it always jumps straight back to blue, the copy
  we trust.

Save all four files (Ctrl+S, or Cmd+S on Mac).

### Step 3 — Watch the canary (1 in 5 gets the new model)

Make sure your terminal is in the folder that holds these four files. Then run:

```bash
python -c "import router; [router.route_request({'value':99}) for _ in range(100)]; print(router.get_usage_stats())"
```

This one line sends 100 pretend visitors through the traffic cop, then prints the tally.

**What you should see:** something close to this (your exact numbers will wobble a little
because of the dice roll):

```
{'old_pct': 80.0, 'new_pct': 20.0, 'total': 100}
```

About 80% got the old model and about 20% got the new one — exactly the canary slice we set.
You might see 78/22 or 21/79; that's normal randomness.

### Step 4 — Flip the feature flag

Run:

```bash
python -c "import feature_flag as f; f.toggle_new_model(); print(f.is_new_model_enabled())"
```

This flips the switch once, then asks whether the new model is now on.

**What you should see:**

```
New model: ON
True
```

The new model is now turned on — instantly, with no rebuilding. That's the magic of a feature
flag.

### Step 5 — Switch and roll back (blue/green)

Run:

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

---

## Try it yourself (mini challenges)

- 🔧 **Change the canary percentage.** In `router.py`, change `CANARY = 0.20` to `0.50`, save,
  and run the Step 3 command again. Now about half the visitors should get the new model.
- 🔧 **Flip the flag and watch which version answers.** Run the Step 4 command twice in a row.
  Notice the first run says `ON True` and the second says `OFF False` — each call flips the
  switch back and forth.
- 🔧 **Try a small payment through the new model.** Run
  `python -c "from models import new_model; print(new_model({'value': 10}))"`. Because 10 is
  not over 50, it should print `safe`. Now try `{'value': 99}` and watch it say `risk`.
- 🔧 **Roll back from green.** In a Python shell, call `s.switch_environment()` (to green) and
  then `s.get_active()`, then `s.rollback()` and `s.get_active()` again. Watch it return to
  blue.

## If something breaks

- **`ModuleNotFoundError: No module named 'models'`** → You're not in the folder that holds
  the four files, or the file isn't named exactly `models.py`. Use `cd` to move into the right
  folder and check the file names.
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

## What you just learned

- A **canary release** lets only a small slice of users try a new version first, so problems
  stay small.
- **Blue/green** keeps an old copy and a new copy side by side, with an instant flip *and* an
  instant way back.
- A **feature flag** is an on/off switch you can flip in a snap, without rebuilding.
- Together these let you **deploy** changes without scary surprises — there's always a fast
  path back to safety.

## Where to next

➡ [Chapter 15 — Dashboards you can watch (Grafana)](../chapter-15-dashboards). You'll turn your
program's numbers into live charts you can watch like a car dashboard.
