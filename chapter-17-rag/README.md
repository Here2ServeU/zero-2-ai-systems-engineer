# Chapter 17 — Retrieval-Augmented Generation (RAG)

**Book:** Chapter 17 (Retrieval-Augmented Generation) · Lab 17.5
**Layer:** 8 · Modern AI · **You build:** A complete RAG pipeline over compliance docs

## What you build

The three RAG pipelines, end to end:

1. `index_corpus.py` — chunk + embed `knowledge_base.txt` into ChromaDB (`./vector_db`).
2. `retrieval.py` — embed a question, return the top-k most similar chunks.
3. `rag_query.py` — assemble retrieved context, send it to Claude, return a grounded,
   cited answer.

`knowledge_base.txt` holds fintech compliance content (KYC, AML/SAR, transaction
monitoring, sanctions, recordkeeping, model governance).

## Setup & run

```bash
python3 -m venv venv && source venv/bin/activate
pip install chromadb sentence-transformers anthropic python-dotenv
export ANTHROPIC_API_KEY='your-key-here'

python index_corpus.py     # build the vector index (first run downloads ~80MB model)
python retrieval.py        # inspect retrieval quality
python rag_query.py        # grounded, cited answer
```

> Set `model='claude-opus-4-7'` to a currently available Claude model for your account.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we do something called **RAG**. RAG means: before the robot answers, we let it
peek at your own notes so it doesn't make things up. The pile of notes is called a
**knowledge base**. To find the *right* notes fast, the computer turns each sentence into
a list of numbers (an **embedding**) so it can tell which sentences mean similar things,
and it keeps them in a smart filing cabinet (a **vector database**, here called
**ChromaDB**) that finds notes by meaning, not by exact words.

### `knowledge_base.txt` — the study notes the robot reads from

**In one sentence:** It is the pile of notes (the **knowledge base**) the robot is allowed
to look at before answering.

**What it does, step by step:**

1. It is a plain text file full of bank-rule notes — the kind of money-and-law rules a bank
   must follow.
2. The notes cover things like: how to check who a customer really is (KYC), how to spot and
   report suspicious money moves (AML/SAR), watching transactions for weird activity, checking
   names against banned lists (sanctions), keeping records for years, and making sure the
   bank's fraud-catching computer models are fair and checked.
3. Nothing runs here — it is just the "textbook" the other scripts study from.

**What you get:** A trustworthy set of notes so the robot answers from facts, not guesses.

### `index_corpus.py` — filing all the notes into the cabinet

**In one sentence:** It chops the notes into small pieces and files them into the smart
filing cabinet so they can be found later. This filing step is called **indexing**.

**What it does, step by step:**

1. It opens `knowledge_base.txt` and reads all the notes.
2. It cuts the long text into smaller chunks of about 500 characters each, with a little
   overlap so no idea gets split in half at the edges.
3. It opens (or creates) the smart filing cabinet, **ChromaDB**, in a folder called
   `./vector_db`.
4. It uses a small helper model (`all-MiniLM-L6-v2`) to turn each chunk into an **embedding**
   — that list of numbers that captures the chunk's meaning. The first time you run it, this
   helper downloads (about 80MB).
5. It clears out any old copy of the notes, then adds all the chunks into the cabinet, each
   with its own little label (`chunk_0`, `chunk_1`, and so on).

**What you get:** All your notes neatly filed by meaning, ready to be searched.

### `retrieval.py` — pulling out the few notes that best match a question

**In one sentence:** It takes a question and grabs the handful of notes that are closest in
meaning. Grabbing the best-matching notes is called **retrieval**.

**What it does, step by step:**

1. It opens the same filing cabinet (`./vector_db`) and the same helper model so it measures
   meaning the same way the filing step did.
2. The `retrieve` function turns your question into numbers and asks the cabinet for the top
   matching chunks. `k=3` means "give me the 3 closest notes."
3. When you run the file on its own, it tries an example question ("What are KYC
   requirements?") and prints the first part of each matching note so you can check the
   matches look right.

**What you get:** The 3 most relevant notes for any question, found by meaning.

### `rag_query.py` — asking the robot, but only using your notes

**In one sentence:** It fetches the best notes, hands them to the robot, and asks it to
answer using only those notes — and to say where it got the answer.

**What it does, step by step:**

1. It opens the phone line to the robot (Claude) using your secret password, the **API key**.
2. It writes a **system prompt** — the standing rule for the robot. Here it says: "Answer
   using ONLY the notes I give you. If the notes don't have the answer, say so. Tell me which
   note you used."
3. It calls `retrieve` to pull the 3 best notes for the question.
4. It glues those notes together as "Context," then writes the **prompt** as: here is the
   context, and here is the question.
5. It phones the robot. `model='claude-opus-4-7'` is the example robot name from the book —
   in real life use a robot that exists today, like `claude-opus-4-8` or `claude-sonnet-4-6`.
   `max_tokens=600` lets the answer be a healthy paragraph or two.
6. It returns the answer, the exact notes it leaned on (its sources), and the word-piece
   counts. Running the file tries the example question "What documents are required for KYC?"

**What you get:** A grounded, fact-checked answer that points back to the notes it used.

➡ Next: [chapter-18-prodllm](../chapter-18-prodllm) — harden the LLM layer for production.
