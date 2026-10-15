# Chapter 17 — Give the robot your own notes to read (RAG)

> Matches **Chapter 17** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

> ### ⚠️ Money & secrets — please read this first
>
> Like Chapter 16, this chapter phones a paid online robot. To use it you need an **API key** —
> think of it as a **credit card for a robot service**. Each call can cost a small amount of
> money.
>
> - **Get permission first** if the account isn't yours.
> - **Never paste the key into your code, and never share it.** Keep it in an **environment
>   variable** (your computer's settings), as this chapter shows.
> - **You only need ONE robot company.** The book offers three (Anthropic Claude, OpenAI,
>   Google Gemini). The book's code here is written for **Anthropic Claude**, but **Google
>   Gemini has a free tier** that's the cheapest way to start if you adapt the call.
> - **No key? No problem.** It is completely fine to *read* this chapter to understand RAG even if
>   you never run it.
>
> Good news: the *first two* scripts in this chapter (filing the notes and searching them) run
> **free on your laptop** — only the final "ask the robot" step spends money.

---

## The big idea (in plain words)

In Chapter 16 your pen pal answered from everything they'd ever read — which means they might
*guess* about things specific to *you*. **RAG** fixes that. RAG stands for
**Retrieval-Augmented Generation**, but the picture is simple: before the pen pal answers, you
**hand them YOUR notebook** and say "read these notes first, then answer using only what's in
here." Now they answer from *your* facts instead of guessing.

To make this work, the computer needs to find the *right* notes fast. So it does two clever
things:

1. It turns each piece of text into a list of numbers (an **embedding**) that captures the
   *meaning* of the text.
2. It keeps all those number-versions in a smart filing cabinet (a **vector database**, here
   called **ChromaDB**) that finds notes by *meaning*, not by exact words.

In this chapter the "notebook" is a set of bank-rule notes (the kind of money-and-law rules a
bank must follow), and you'll build the whole pipeline end to end.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **RAG (Retrieval-Augmented Generation)** — giving the robot your *own* notes to read before it
  answers, so it answers from your facts instead of guessing.
- **Embedding** — turning a piece of text into a list of numbers so the computer can tell which
  texts mean similar things.
- **Vector database / ChromaDB** — a special filing cabinet that stores those number-versions of
  text and finds the closest matches fast.
- **API key** — a secret password that lets your program use the paid robot service. Keep it in
  your computer's settings, never in your code. (Same as Chapter 16.)

## What you will build

Three small scripts that work together:

1. `index_corpus.py` — chops your notes into small pieces and files them into ChromaDB. (Free,
   on your laptop.)
2. `retrieval.py` — takes a question and pulls out the few notes that best match it. (Free, on
   your laptop.)
3. `rag_query.py` — fetches the best notes, hands them to the robot, and gets back a grounded
   answer that says which note it used. (This one phones the robot, so it costs a little.)

The notes themselves live in `knowledge_base.txt`.

---

## Let's do it, one small step at a time

### Step 1 — Get the code and open it

```bash
cd chapter-17-rag
```

Inside you'll find:

- **`knowledge_base.txt`** — the pile of notes (the *knowledge base*) the robot is allowed to
  read. It's plain text full of bank-rule notes; nothing runs here, it's just the "textbook."
- **`index_corpus.py`**, **`retrieval.py`**, **`rag_query.py`** — the three scripts above.

### Step 2 — Make a clean toolbox and install the helpers

```bash
python3 -m venv venv && source venv/bin/activate
pip install chromadb sentence-transformers anthropic python-dotenv
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*).
- `source venv/bin/activate` steps into it. (Windows: `venv\Scripts\activate`.)
- The install brings: `chromadb` (the smart filing cabinet), `sentence-transformers` (the helper
  that turns text into **embeddings**), and `anthropic` (to phone the robot).

**What you should see:** packages downloading, ending with `Successfully installed chromadb-...`.

### Step 3 — Set your API key (needed only for the last script)

```bash
export ANTHROPIC_API_KEY='your-key-here'    # PowerShell: $env:ANTHROPIC_API_KEY='your-key-here'
```

- This puts your secret password into a slot in *this terminal's* settings, so the code never
  holds it. It only lasts for this terminal window — if you open a new one, set it again.
- Get a key from [console.anthropic.com](https://console.anthropic.com).

> **Set the model to one that exists.** The book's `rag_query.py` says
> `model='claude-opus-4-7'`, which is **just an example**. Open `rag_query.py` and change it to a
> real model for your account, like `claude-opus-4-8` (smartest) or `claude-sonnet-4-6` (fast,
> cheaper).

### Step 4 — File the notes into the cabinet (FREE)

```bash
python index_corpus.py
```

**What you should see:** something like:

```
Produced 9 chunks
Indexed 9 chunks
```

(The very first run also quietly downloads a small embedding helper, about 80MB — give it a
moment.)

**What `index_corpus.py` does, in plain words:**

```python
def chunk_text(text, size=500, overlap=100):
    ...
```

- It opens `knowledge_base.txt` and reads all the notes.
- `chunk_text(...)` cuts the long text into small **chunks** of about 500 characters, with a
  little overlap (100 characters) so no idea gets sliced in half at the edges.

```python
client = chromadb.PersistentClient(path='./vector_db')
embed = ef.SentenceTransformerEmbeddingFunction(model_name='all-MiniLM-L6-v2')
collection = client.create_collection(name='compliance_kb', embedding_function=embed)
collection.add(documents=chunks, ids=[f'chunk_{i}' for i in range(len(chunks))])
```

- `PersistentClient(path='./vector_db')` — open (or create) the **ChromaDB** filing cabinet in a
  folder called `vector_db`.
- `SentenceTransformerEmbeddingFunction(...)` — the small helper that turns each chunk into an
  **embedding** (its number-version of meaning).
- `collection.add(...)` — file every chunk into the cabinet, each with its own label
  (`chunk_0`, `chunk_1`, ...).

**What you get:** all your notes neatly filed by *meaning*, ready to search.

### Step 5 — Search the notes (FREE)

```bash
python retrieval.py
```

**What you should see:** the top 3 notes that best match an example question, something like:

```
--- Match 1 ---
Know Your Customer (KYC) Requirements. Before onboarding any customer ...

--- Match 2 ---
Customer Due Diligence and Risk Rating. Every customer is assigned ...
```

**What `retrieval.py` does, in plain words:**

```python
def retrieve(question, k=3):
    results = collection.query(query_texts=[question], n_results=k)
    return results['documents'][0]
```

- It opens the *same* cabinet and the *same* embedding helper, so it measures meaning the same
  way the filing step did.
- `retrieve(question, k=3)` turns your question into numbers and asks the cabinet for the `k`
  closest notes. `k=3` means "give me the 3 best matches."
- Run on its own, it tries the example question "What are KYC requirements?" and prints the start
  of each match so you can check the matches look right.

### Step 6 — Ask the robot using only your notes (COSTS A LITTLE)

```bash
python rag_query.py
```

**What you should see:** a grounded answer written by the robot that uses *only* your notes, plus
a token count, something like:

```
For an individual customer, KYC requires a government-issued photo ID, proof of address
dated within 90 days, and a taxpayer ID. (From passage [1].)

Tokens: 412/96
```

**What `rag_query.py` does, in plain words:**

```python
SYSTEM = ('You are a fintech compliance assistant. Answer using ONLY the supplied context. '
          'If the context does not contain the answer, say so explicitly. '
          'Cite which passage you used.')
```

- This **system prompt** is the standing rule: "Answer using ONLY the notes I give you. If the
  notes don't have the answer, say so. Tell me which note you used." This is what stops the robot
  from guessing.

```python
def answer(question):
    chunks = retrieve(question, k=3)
    context = '\n\n'.join(f'[{i+1}] {c}' for i, c in enumerate(chunks))
    prompt = (f'Context:\n{context}\n\nQuestion: {question}')
    msg = client.messages.create(
        model='claude-opus-4-7', max_tokens=600, system=SYSTEM,
        messages=[{'role':'user','content':prompt}])
    ...
```

- `chunks = retrieve(question, k=3)` — fetch the 3 best notes for the question (Step 5's helper).
- It glues those notes together as labeled **Context**, then writes the **prompt** as: here is
  the context, and here is the question.
- It phones the robot. `model='claude-opus-4-7'` — **swap for a real model** (Step 3).
  `max_tokens=600` lets the answer be a healthy paragraph or two.
- It returns the answer, the exact notes it leaned on (its **sources**), and the token counts.

🎉 You just built a full RAG pipeline: the robot answered a question using *your* notebook, not
its own guesses — and pointed back to the note it used.

---

## Try it yourself (mini challenges)

- 🔧 **Add a line to the notes and ask about it.** Open `knowledge_base.txt` and add a new fact,
  for example: `The maximum daily ATM withdrawal limit is 500 dollars.` Save it. Then **re-run
  `python index_corpus.py`** (so the cabinet learns the new note), and ask about it by editing
  the question in `rag_query.py` to `q = 'What is the daily ATM withdrawal limit?'`. The robot
  should answer from your new line.
- 🔧 **Ask something NOT in the notes.** Change the question to `q = 'What is the weather today?'`
  and run `rag_query.py`. Because of the system prompt, the robot should say the notes don't
  cover that — instead of making something up.
- 🔧 **Change how many notes it reads.** In `rag_query.py`, change `retrieve(question, k=3)` to
  `k=1`. With fewer notes, does the answer get thinner? Try `k=5` too.
- 🔧 **Peek at the sources.** In `rag_query.py`'s `__main__` block, add
  `print(result['sources'])` to see exactly which notes the robot was handed.

## If something breaks

- **`KeyError: 'ANTHROPIC_API_KEY'`** → The key isn't set in this terminal. Redo Step 3's
  `export`. It only lasts for the current terminal window.
- **An "authentication" / "invalid API key" / 401 error** → The key is wrong or has a typo.
  Create a fresh key and `export` it again.
- **A "model not found" error** → You're using the example name `claude-opus-4-7`. Change `model`
  in `rag_query.py` to a real one like `claude-opus-4-8` or `claude-sonnet-4-6`.
- **`Collection ... does not exist` / nothing found when searching** → You ran `retrieval.py` or
  `rag_query.py` *before* `index_corpus.py`. Run `python index_corpus.py` first to build the
  cabinet.
- **The first run hangs for a while** → The first `index_corpus.py` run downloads an ~80MB
  embedding helper; this needs the **internet** and a minute. Let it finish.
- **A "rate limit" / 429 error** → You called the robot too fast or hit a free-tier cap. Wait a
  minute and try again.

## What you just learned

- **RAG** means handing the robot *your* notes first so it answers from your facts, not guesses.
- Text becomes an **embedding** (numbers that capture meaning) so the computer can match by
  meaning.
- A **vector database (ChromaDB)** stores those embeddings and finds the closest notes fast.
- The pipeline is three steps: **index** the notes, **retrieve** the best ones, then **ask** the
  robot using only those notes.
- A strict **system prompt** ("use ONLY these notes, and cite them") keeps the answer honest.

## Where to next

➡ [Chapter 18 — Run the smart robot for real (Production LLM)](../chapter-18-prodllm). You'll add
the grown-up care — spending limits, logging, safety filters — so the robot can serve real people
reliably.
