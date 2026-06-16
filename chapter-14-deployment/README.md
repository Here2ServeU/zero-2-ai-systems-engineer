# Chapter 14 — Advanced Deployment & Model Promotion

**Book:** Chapter 14 (Advanced Deployment and Model Promotion) · Lab 14.2
**Layer:** 7 · Continuous Delivery · **You build:** Canary, feature flags, blue/green

## What you build (`src/`)

- `models.py` — an old (stable) and new (candidate) model side by side.
- `router.py` — canary traffic split (20% → new) with usage tracking.
- `feature_flag.py` — instant on/off toggle without redeployment.
- `switch.py` — blue/green environment switch with rollback.

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install flask pandas

cd src
python -c "import router; [router.route_request({'value':99}) for _ in range(100)]; print(router.get_usage_stats())"
python -c "import feature_flag as f; f.toggle_new_model(); print(f.is_new_model_enabled())"
python -c "import switch as s; s.switch_environment(); s.rollback()"
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we are learning about *deployment* — that means putting your app out for real
people to use. We do it carefully, so if the new version is bad we can switch back fast.

### `models.py` — the old recipe and the new recipe, side by side

**In one sentence:** This file holds two versions of the "thinking" part of our app — the old one we trust, and a new one we are still testing.

**What it does, step by step:**

1. `old_model` is the safe, boring helper. No matter what you give it, it always says `'safe'`. It is like an old cookie recipe that never fails.
2. `new_model` is the new helper we want to try. It looks at a number called `value`. If that number is bigger than 50, it says `'risk'`. Otherwise it says `'safe'`.
3. We keep both helpers in the same file so the rest of the app can pick whichever one it wants.

**What you get:** Two helpers you can switch between — a trusted old one and a newer, smarter one.

### `router.py` — the helper that picks which version each visitor gets

**In one sentence:** A *router* is the helper that decides which version each visitor sees, and here it sends only a few people to the new one (this is called a *canary release*).

**What it does, step by step:**

1. A *canary release* means letting only a few people try the new version first — like one kid tasting the new cookie before the whole class eats it.
2. `CANARY = 0.20` means 20 out of every 100 visitors (1 in 5) get the new model. The other 80 get the old, trusted one.
3. When a request comes in, `route_request` rolls a dice with `random.random()`. If the dice lands under 0.20, the visitor gets the new model. If not, they get the old model.
4. Every time, we add 1 to a tally in `usage` — either to `'new'` or to `'old'` — so we can count who got which version.
5. `get_usage_stats` does the math and tells you what percent went to the old model, what percent to the new model, and the total number of visitors.

**What you get:** A traffic cop that quietly sends 1 in 5 people to the new model and keeps a running tally so you can watch how it goes.

### `feature_flag.py` — an on/off light switch for the new feature

**In one sentence:** A *feature flag* is an on/off light switch for a new feature, so you can turn the new model on or off instantly without rebuilding anything.

**What it does, step by step:**

1. `USE_NEW_MODEL = False` starts the switch in the OFF position. The new model is hidden for now.
2. `toggle_new_model` is the finger that flips the switch. Each time you call it, OFF becomes ON, and ON becomes OFF. It also prints the new state so you can see it.
3. `is_new_model_enabled` just looks at the switch and tells you `True` (ON) or `False` (OFF).
4. The best part: flipping this switch is instant. You do not have to shut the app down or build it again — like flicking a light switch instead of rewiring the house.

**What you get:** A quick on/off button for the new model that works in a snap, with no rebuilding.

### `switch.py` — keeping two copies and flipping which one is live

**In one sentence:** This is a *blue/green* switch — you keep two copies of your app (an old "blue" one and a new "green" one) and flip which one is live, so you can jump back to the old one fast if something breaks.

**What it does, step by step:**

1. `ACTIVE_ENV = 'blue'` says the "blue" copy is the one people are using right now. Blue is our safe, old copy.
2. `get_active` simply tells you which copy is live — blue or green.
3. `switch_environment` flips the two copies. If blue is live, it makes green live. If green is live, it makes blue live again. It prints which one is now on.
4. `rollback` is the emergency "undo" button. It always jumps straight back to blue, the old copy we trust. If the new green copy is acting up, one call here puts the safe copy back.

**What you get:** Two copies of your app and a flip switch between them, plus a panic button that snaps you back to the safe copy in one step.

➡ Next: [chapter-15-dashboards](../chapter-15-dashboards) — Prometheus + Grafana stack.
