# Chapter 01 — Set up your computer and say hello

> Matches **Chapter 01** in the book. This is the very first step of the whole journey.
> The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop

---

## The big idea (in plain words)

Think of the computer as a friend who only does *exactly* what you tell it — no more, no
less. To give it instructions, you need three things:

1. **A language to speak** — we use **Python**, which reads almost like English.
2. **A place to write** — an editor called **VS Code**.
3. **A way to save your work safely** — a tool called **Git**.

In this chapter you'll install those three, then write your very first program: one that makes
the computer say hello to you. That's it. Small on purpose.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Python** — the language we write programs in.
- **VS Code** — the app where we write our code.
- **Terminal** — a text window where you type commands instead of clicking buttons.
- **Run** — to make the computer actually *do* what your program says.

## What you will build

A program called `hello.py` that prints two friendly lines:

```
Hello, Sam!
Let's build something real.
```

(You'll use your own name instead of Sam.)

---

## Let's do it, one small step at a time

### Step 1 — Install Python

1. Go to **python.org/downloads** in your web browser.
2. Click the big yellow **Download Python** button.
3. Open the file you downloaded.
   - **Windows:** **Tick the box that says "Add Python to PATH"** before clicking Install.
     This one tick saves you many headaches later.
   - **Mac:** just click through Install.
4. **Check it worked.** Open your **Terminal** (see Step 3 if you don't know how) and type:

   ```bash
   python3 --version
   ```

   **What you should see:** something like `Python 3.11.5`. Any `3.something` is fine.

### Step 2 — Install VS Code (your writing app)

1. Go to **code.visualstudio.com** and click **Download**.
2. Install it like any normal app.
3. Open VS Code. When it asks to install the **Python extension**, say **yes** — it makes
   writing Python much friendlier.

### Step 3 — Find your Terminal

The terminal is where you'll tell the computer to *run* your programs.

- **The easy way:** inside VS Code, click the top menu **Terminal → New Terminal**. A text
  panel opens at the bottom. That's it.
- Mac also has a separate **Terminal** app; Windows has **PowerShell**. Either works, but the
  VS Code one is simplest because it sits right next to your code.

### Step 4 — Install Git (saves your work safely)

1. Go to **git-scm.com/downloads**, pick your system, and install.
2. Check it worked — in the terminal type:

   ```bash
   git --version
   ```

   **What you should see:** something like `git version 2.42.0`.

> Don't worry about *using* Git yet. We just want it installed. You'll learn to save and share
> your work in a later chapter.

### Step 5 — Make a folder for this chapter

In the terminal, type these one at a time:

```bash
mkdir hello-project
cd hello-project
```

- `mkdir hello-project` makes a new **folder** called `hello-project`.
- `cd hello-project` moves you *into* that folder, so your work lands there.

### Step 6 — Write your first program

1. In VS Code, open the `hello-project` folder (**File → Open Folder**).
2. Make a new file called **`hello.py`** (File → New File, then save it with that name).
3. Type these three lines exactly (use **your** name):

   ```python
   name = "Sam"
   print(f"Hello, {name}!")
   print("Let's build something real.")
   ```

**What each line says, in plain words:**

1. `name = "Sam"` — Put the word *Sam* into a labeled box called `name`. (A labeled box is a
   **variable**. You can put anything in it.)
2. `print(f"Hello, {name}!")` — `print` means "say this on the screen." The `{name}` part
   means "look inside the box and use what's there," so it says **Hello, Sam!**
3. `print("Let's build something real.")` — Say one more line on the screen.

4. **Save the file** (Ctrl+S, or Cmd+S on Mac). Saving matters — the computer runs the *saved*
   version.

### Step 7 — Run it

In the terminal (make sure you're inside `hello-project`), type:

```bash
python3 hello.py     # Mac / Linux
python hello.py      # Windows
```

**What you should see:**

```
Hello, Sam!
Let's build something real.
```

🎉 You just wrote and ran a real program. Every giant system later in this book is built from
small steps exactly like this one: make a file, write code, save, run it.

---

## Try it yourself (mini challenges)

- 🔧 **Change the name.** Put your best friend's name in the box and run it again.
- 🔧 **Add a third line.** Make it print your favorite food. (Hint: copy a `print(...)` line.)
- 🔧 **Break it on purpose.** Delete one of the quotation marks and run it. Read the error.
  Then put the mark back. Seeing errors — and fixing them — is a normal part of coding.

## If something breaks

- **`python3: command not found` (or `python` not found on Windows)** → Python isn't installed
  or wasn't added to PATH. Redo Step 1; on Windows make sure you ticked "Add Python to PATH,"
  then close and reopen the terminal.
- **`can't open file 'hello.py'`** → You're not in the right folder. Type `cd hello-project`
  first, or check the file is really named `hello.py` (not `hello.py.txt`).
- **`SyntaxError`** → A typo. Most often a missing quote `"` or parenthesis `)`. Compare your
  three lines to the example, character by character.
- **Nothing prints** → Make sure you *saved* the file before running it.

## What you just learned

- You installed the three core tools every developer uses: **Python**, **VS Code**, and
  **Git**.
- You found and used the **terminal**.
- You created a folder, wrote a Python file, and **ran** your first program.
- You learned that **variables** are labeled boxes and `print` shows things on screen.
- You learned that **errors are normal** and tell you what to fix.

## Where to next

➡ [Chapter 02 — Your very first tiny AI experiment](../chapter-02-data). You'll make the
computer *learn from examples* for the first time.
