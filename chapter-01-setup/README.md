# Chapter 01 — Your Toolkit & Setup

**Book:** Before Chapter 1 (Your Toolkit) + Chapter 1 (The Rise of Production AI Systems)
**Layer:** 0–1 · Foundation · **You build:** dev environment + first Python script

## What you build

Your first Python program, after installing Python, VS Code, and Git.

## Run

```bash
python3 hello.py    # macOS/Linux
python  hello.py    # Windows
```

Expected:

```
Hello, Emmanuel!
Let's build something real.
```

This is the entire engineering workflow you'll use for the rest of the book:
create a file, write code, save, open a terminal, run it.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time.

### `hello.py` — the computer says hello

**In one sentence:** It teaches the computer to remember your name and say hi.

**What it does, line by line:**

1. `name = "Emmanuel"` — Put the word *Emmanuel* into a labeled box called `name`.
   (A box with a label is called a **variable**. You can put anything in it.)
2. `print(f"Hello, {name}!")` — `print` means "say this out loud on the screen."
   The `{name}` part means "look inside the box and use what's there," so the computer
   says **Hello, Emmanuel!**
3. `print("Let's build something real.")` — Say one more line on the screen.

**What you get:** Two friendly lines printed in your terminal. That's it — you just ran
a real program. Every big system in this book is built from small, simple steps like these.

➡ Next: [chapter-02-data](../chapter-02-data) — your first version-controlled ML experiment.
