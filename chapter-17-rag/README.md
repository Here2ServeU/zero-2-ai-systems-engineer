# Chapter 17 — Give the robot your own notes to read (RAG)

> Matches Chapter 17 in the book.

**Labels:** Needs an account that may cost money · Needs the internet

---

> ### Money and secrets: please read this first
>
> Like Chapter 16, this chapter phones a paid online robot (an LLM). To use it you need an
> **API key**: think of it as a **credit card for a robot service**. Each question costs a small
> amount of money, usually a fraction of a cent.
>
> - **Get permission first** if the account isn't yours.
> - **Never paste the key into your code, never commit it to git, and never share it.** Keep it
>   in an **environment variable** (a setting in your terminal), exactly as this chapter shows.
> - **You only need ONE robot company.** The book offers three (Anthropic Claude, OpenAI, Google
>   Gemini). The book's code for this chapter is written for **Anthropic Claude**.
> - **No key? You can still do most of this chapter.** Filing the notes (Step 3) and searching
>   them (Step 4) run **free on your laptop**. Only the "ask the robot" step spends money.

---

## The platform you are building

You are building an **enterprise knowledge platform**, also called a **RAG platform**: a
service that answers questions using *your own* documents, and shows which document each
answer came from. Banks use it so staff can ask "what does the rule say about X?" and get an
answer from the real rulebook, not the robot's guess. Hospitals, law firms, support teams and
almost every large company are building one right now, because a robot that answers from the
company's own facts (and admits when it doesn't know) is far more useful and safer than one that
makes things up. People who build these are called **AI Engineers**, **ML Engineers**,
**AI Platform Engineers** and **Search / Retrieval Engineers**.

## How this builds on Chapter 16

**What carries over:**

- The same **Anthropic Python library** and `client.messages.create(...)` call from Chapter 16.
- The same **API-key habit**: `export ANTHROPIC_API_KEY=...` in your terminal, read with
  `os.environ['ANTHROPIC_API_KEY']`, never written into code.
- The same **system prompt** idea: a standing rule the robot always follows. Here the rule is
  "answer using ONLY these notes".
- In the cloud (Phases 2 and 3): the same `llm-api-keys` Kubernetes Secret made from your
  terminal's key, the same **AWS Secrets Manager** vault (`put-llm-secret.sh`) in Phase 3, and
  the same shared cluster, Helm chart, load balancer and autoscaler from Chapter 10.

**What's new:** **embeddings** (text turned into numbers that capture meaning), a **vector
database** (ChromaDB) that finds notes by meaning, and **grounded answers** that cite their
source. In the cloud: an **init container** that files the notes before the app starts, and a
much bigger container image, because it carries its own small AI model for embeddings.

```text
Your platform so far

 question --> rag_api (Ch 17, new)
                |  1. turn the question into numbers (embedding model, runs locally, free)
                |  2. find the 3 closest notes in ChromaDB (vector database, free)
                |  3. send question + notes to the LLM (Ch 16) with "use ONLY these notes"
                v
             answer + the notes it used

 In the cloud: ALB + HPA + PDB (Ch 10) --> rag-api copies --> LLM key from Secrets Manager (Ch 16)
```

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **1 — Build it on your laptop** | Your computer | File the notes, search them, ask the robot, pack it all in a container | Free, except each robot question (a fraction of a cent) |
| **2 — Promote it to the cloud** | AWS EKS | 2A: plain YAML. 2B: the Helm chart with an init container | Money while the cluster runs (about $0.15 to $0.30 an hour for dev) |
| **3 — Run it like a Fortune 500 company** | AWS EKS + ALB | Several identical copies, autoscaling, keys from the vault, a public address | Same as Phase 2, a little more for extra copies |

## New words

Look up anything else in the [GLOSSARY](../GLOSSARY.md).

- **RAG (Retrieval-Augmented Generation)** — Giving the robot *your* notes to read before it
  answers, so it answers from your facts instead of guessing. *Retrieval* = finding the right
  notes; *generation* = the robot writing the answer.
- **Knowledge base** — The pile of notes the robot is allowed to use. Here: `knowledge_base.txt`.
- **Chunk** — A small piece of a long text (here about 500 characters), small enough to search
  and hand to the robot.
- **Embedding** — A list of numbers that captures what a piece of text *means*. Texts with
  similar meanings get similar numbers, even if they use different words.
- **Embedding model** — The small AI that turns text into embeddings. Here
  `all-MiniLM-L6-v2`, which runs free on your laptop.
- **Vector database / ChromaDB** — A filing cabinet for embeddings that finds the closest
  matches fast.
- **Grounded answer** — An answer that sticks to the supplied notes and says which note it used.
- **Hallucination** — When a robot confidently makes something up. RAG is the main defense.
- **API key** — A secret password for the paid robot service. Keep it in an environment
  variable, never in your code. (Same as Chapter 16.)

---

## Phase 1 — Build it on your laptop

You build three small scripts that work together, then pack them into one container:

1. `index_corpus.py` — cuts your notes into chunks and files them into ChromaDB. (Free.)
2. `retrieval.py` — takes a question and pulls out the notes that best match it. (Free.)
3. `rag_query.py` — fetches the best notes, hands them to the robot, and gets back a grounded
   answer. (Costs a fraction of a cent.)

### Step 1 — Go to the chapter folder

From the top of the course repo:

```bash
cd chapter-17-rag
ls
```

**What you should see:** `Dockerfile`, `index_corpus.py`, `knowledge_base.txt`, `rag_api.py`,
`rag_query.py`, `requirements.txt`, `retrieval.py`, this `README.md`, and a `cloud` folder.

- **`knowledge_base.txt`** — the notes the robot may read: eight bank rules (KYC, anti-money
  laundering, sanctions screening and more). Open it and skim it. Nothing runs here; it's the
  "textbook".
- **`index_corpus.py`**, **`retrieval.py`**, **`rag_query.py`** — the book's three scripts.
- **`rag_api.py`** and **`Dockerfile`** — a small web door around the same pipeline, used in
  Step 7 and in the cloud.

### Step 2 — Make a clean toolbox and install the helpers

Run from `chapter-17-rag`:

```bash
python3 -m venv venv
source venv/bin/activate          # Windows PowerShell: venv\Scripts\Activate.ps1
pip install chromadb sentence-transformers anthropic python-dotenv
```

- `python3 -m venv venv` makes a clean, private **toolbox** (a *virtual environment*) in a
  folder called `venv`. `source venv/bin/activate` steps into it; your prompt starts with
  `(venv)`.
- `chromadb` is the filing cabinet, `sentence-transformers` turns text into embeddings (it
  brings **PyTorch**, a big AI library), and `anthropic` phones the robot.

> **On Linux, install the small CPU-only PyTorch first** (run it *before* the line above). The
> normal Linux download includes graphics-card code and is several GB bigger:
> `pip install torch --index-url https://download.pytorch.org/whl/cpu`

**What you should see:** many packages downloading (this one is big: allow a few minutes and
about 1.5 GB of disk), ending with a line that starts `Successfully installed ...` and includes
`chromadb-...`, `sentence-transformers-...` and `anthropic-...`.

### Step 3 — File the notes into the cabinet (FREE)

```bash
python index_corpus.py
```

**What you should see:**

```text
Produced 11 chunks
Indexed 11 chunks
```

The **first** run also downloads the embedding model `all-MiniLM-L6-v2` (about 90 MB) from the
Hugging Face website, so it needs the internet and may take a minute. You may see a warning
like `You are sending unauthenticated requests to the HF Hub`, a `Loading weights` progress
bar, and on a Mac `NOTE: Redirects are currently not supported in MacOs.` All of these are
normal and appear in Step 4 too. Later runs use the saved copy of the model.

A new folder `vector_db` appears. That's the filing cabinet on disk.

**What `index_corpus.py` does, in plain words:**

```python
def chunk_text(text, size=500, overlap=100):
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + size, len(text))
        chunks.append(text[start:end])
        if end == len(text):
            break
        start = end - overlap
        ...
```

- It reads all of `knowledge_base.txt` (about 4,400 characters).
- `chunk_text(...)` cuts it into **chunks** of 500 characters. Each new chunk starts 100
  characters *before* the previous one ended (the **overlap**), so a sentence cut at an edge
  still appears whole in one of the two chunks. That's why you get 11 chunks, not 9.

> **Note for book readers:** this folder's `index_corpus.py` has one extra line compared to
> the printed book: `if end == len(text): break`. Without it, the loop never ends when it
> reaches the end of the text: it keeps adding the same last chunk until the computer runs out
> of memory. If you typed the code from the book and it hangs, add that line.

```python
client = chromadb.PersistentClient(path='./vector_db')
embed = ef.SentenceTransformerEmbeddingFunction(model_name='all-MiniLM-L6-v2')
collection = client.create_collection(name='compliance_kb', embedding_function=embed)
collection.add(documents=chunks, ids=[f'chunk_{i}' for i in range(len(chunks))])
```

- `PersistentClient(path='./vector_db')` — open (or create) the filing cabinet in `vector_db`.
- `SentenceTransformerEmbeddingFunction(...)` — the helper that turns each chunk into an
  embedding.
- `delete_collection(...)` (just above `create_collection` in the file) — throws away the old
  drawer first, so running the script again starts fresh instead of failing.
- `collection.add(...)` — files every chunk with its own label (`chunk_0`, `chunk_1`, ...).

### Step 4 — Search the notes (FREE)

```bash
python retrieval.py
```

**What you should see:** three matches for the example question "What are KYC requirements?",
each showing the first 200 characters of a chunk:

```text
--- Match 1 ---
Know Your Customer (KYC) Requirements. Before onboarding any customer, a financial institution
must verify the customer's identity ...

--- Match 2 ---
...

--- Match 3 ---
...
```

The top match should be about KYC (words like "Know Your Customer", "identification",
"passport"). The exact order of matches 2 and 3 can differ slightly between computers.

**What `retrieval.py` does, in plain words:**

```python
def retrieve(question, k=3):
    results = collection.query(query_texts=[question], n_results=k)
    return results['documents'][0]
```

- It opens the *same* cabinet with the *same* embedding model, so it measures meaning the same
  way the filing step did.
- `retrieve(question, k=3)` turns your question into numbers and asks for the `k` closest
  chunks. `k=3` means "give me the 3 best matches".

Try your own question without spending anything. Run from `chapter-17-rag`:

```bash
python -c "from retrieval import retrieve; print(retrieve('How many days to file a SAR?', k=1)[0][:300])"
```

**What you should see:** a chunk from the "Anti-Money-Laundering (AML) Reporting" note that
mentions filing a Suspicious Activity Report within 30 calendar days. Notice your question said
"how many days" and the note says "within 30 calendar days": the match is by *meaning*, not by
exact words.

### Step 5 — Set your API key (only needed from here on)

Get a key from [console.anthropic.com](https://console.anthropic.com), then:

```bash
export ANTHROPIC_API_KEY='paste-your-key-here'     # Windows PowerShell: $env:ANTHROPIC_API_KEY='paste-your-key-here'
```

- It lasts only for this terminal window. Open a new one and you must set it again.
- Check it's set without showing it on screen: `test -n "$ANTHROPIC_API_KEY" && echo key is set`.
- Never put the key in a file you commit. If it ever leaks, delete it in the console and make
  a new one.

> **About the model name.** The book's `rag_query.py` uses `model='claude-opus-4-7'`. If your
> account reports "model not found", change that one line to a model your account offers (the
> console's model list shows them; a smaller model such as `claude-sonnet-4-6` is cheaper for
> testing).

### Step 6 — Ask the robot using only your notes (COSTS A FRACTION OF A CENT)

```bash
python rag_query.py
```

**What you should see** after a few seconds: an answer to "What documents are required for
KYC?" that uses *only* your notes and points to the passage it used, then the token counts.
The wording changes every time, but it looks something like:

```text
For an individual customer, the required KYC documents are a government-issued photo ID
(such as a passport or driver's license), proof of residential address dated within the last
90 days, and a valid taxpayer identification number. Business customers must also provide ...
(Source: passage [1].)

Tokens: 520/140
```

`Tokens: 520/140` means about 520 tokens went *in* (your question plus 3 chunks of notes) and
140 came *out*. Almost all of the input is the notes: that's the price of grounding.

**What `rag_query.py` does, in plain words:**

```python
SYSTEM = ('You are a fintech compliance assistant. Answer using ONLY the supplied context. '
          'If the context does not contain the answer, say so explicitly. '
          'Cite which passage you used.')
```

- This **system prompt** is the standing rule. "ONLY the supplied context" stops guessing;
  "say so explicitly" makes it admit when the notes don't cover something; "cite" lets a human
  check the answer.

```python
def answer(question):
    chunks = retrieve(question, k=3)
    context = '\n\n'.join(f'[{i+1}] {c}' for i, c in enumerate(chunks))
    prompt = (f'Context:\n{context}\n\nQuestion: {question}')
    msg = client.messages.create(model='claude-opus-4-7', max_tokens=600,
                                 system=SYSTEM, messages=[{'role':'user','content':prompt}])
    ...
```

- `retrieve(question, k=3)` — fetch the 3 best chunks (Step 4).
- The chunks are numbered `[1]`, `[2]`, `[3]` and glued together as **Context**, so the robot
  can say "passage [1]".
- `max_tokens=600` — the longest answer allowed, which also caps the cost.
- It returns the answer, the chunks it used (`sources`), and the token counts.

You just built a full RAG pipeline: the robot answered from *your* notebook and pointed back
to the passage it used.

### Step 7 — Pack it in a container

In Phase 2 the cloud runs this pipeline as a small web service from a container image, so you
build and test that image here first.

[`rag_api.py`](rag_api.py) puts the pipeline behind a web door:

- `GET /health` → `{"status": "healthy"}` (the cloud uses this to check the app is alive).
- `POST /ask` with `{"question": "..."}` → the answer, the `sources`, the token counts and a
  `request_id` ticket number. It reuses `answer()` from `rag_query.py`, unchanged.

The [`Dockerfile`](Dockerfile) installs the small CPU-only PyTorch, **downloads the embedding
model while building** (so the container never needs the model website), copies the scripts,
and switches to a normal user. When the container starts, it files the notes
(`index_corpus.py`) and then opens the web door (`rag_api.py`) on port 5000.

Make sure Docker Desktop (or Docker Engine) is running. Run from `chapter-17-rag`:

```bash
docker build -t zero2ai-rag .
```

**What you should see:** Docker works through the `Dockerfile` steps and ends with a line like
`naming to docker.io/library/zero2ai-rag:latest`. This image is big (about 1.5 GB), so the first
build takes several minutes.

Run it (TERMINAL 1). `-e ANTHROPIC_API_KEY` with no `=value` copies the key from your terminal
into the container, so it never appears in the command or your shell history:

```bash
docker run --rm --name rag -p 5000:5000 -e ANTHROPIC_API_KEY zero2ai-rag
```

**What you should see:** `Produced 11 chunks`, `Indexed 11 chunks`, then Flask starting:
`Running on http://127.0.0.1:5000`. Leave it running.

Check it from a second terminal (TERMINAL 2):

```bash
curl -s http://localhost:5000/health; echo
curl -s -X POST http://localhost:5000/ask -H 'Content-Type: application/json' \
  -d '{"question":"What is the cash reporting threshold?"}'; echo
curl -s -X POST http://localhost:5000/ask -H 'Content-Type: application/json' -d '{}'; echo
docker exec rag id
```

**What you should see:**

1. `{"status":"healthy"}`
2. JSON with an `answer` that mentions **10,000 dollars** and a Currency Transaction Report,
   a `sources` list of 3 chunks, `tokens_in`, `tokens_out` and a `request_id` (this one costs a
   fraction of a cent)
3. `{"error":"Missing question","request_id":"..."}` (empty questions are refused for free)
4. `uid=1000(appuser) ...`: the app runs as a normal user, not the all-powerful `root` user

Press **Ctrl+C** in Terminal 1 to stop the container (`--rm` deletes it).

### Try it yourself

- **Add a note and ask about it.** Add this line at the end of `knowledge_base.txt`:
  `The maximum daily ATM withdrawal limit is 500 dollars.` Save it, **re-run
  `python index_corpus.py`** (the count stays at 11 chunks: the new line is short, so it
joins the last chunk), then check it's findable for
  free: `python -c "from retrieval import retrieve; print(retrieve('What is the daily ATM withdrawal limit?', k=1))"`.
  Finally change the question in `rag_query.py` to
  `q = 'What is the daily ATM withdrawal limit?'` and run it.
- **Ask something NOT in the notes.** Set `q = 'What is the weather today?'` and run
  `rag_query.py`. Because of the system prompt, the robot should say the notes don't cover it,
  instead of making something up.
- **Change how many notes it reads.** In `rag_query.py`, change `retrieve(question, k=3)` to
  `k=1`, then `k=5`. Watch the `Tokens:` input number: more notes = more tokens = more cost,
  but fewer notes can miss the answer.
- **Peek at the sources.** In `rag_query.py`'s `__main__` block, add `print(result['sources'])`.
- Put the files back the way they were when you're done.

### If something breaks

- **`KeyError: 'ANTHROPIC_API_KEY'`** (from `rag_query.py`, or the container exits right after
  `Indexed 11 chunks`) → The key isn't set in this terminal. Redo Step 5. Steps 3 and 4 never
  need it.
- **`anthropic.AuthenticationError: Error code: 401`** → The key is wrong, mistyped or deleted.
  Make a fresh key and `export` it again.
- **`anthropic.NotFoundError: Error code: 404`** mentioning the model → Your account doesn't
  offer that model. See "About the model name" in Step 5.
- **`anthropic.RateLimitError: Error code: 429`** → Too many requests too fast, or a free-tier
  or spending limit. Wait a minute and check your limits and credit in the console.
- **`Error code: 400` with "credit balance is too low"** → Add credit in the console's billing
  page.
- **`chromadb.errors.NotFoundError: Collection [compliance_kb] does not exist`** → You ran
  `retrieval.py` or `rag_query.py` before filing the notes, or from a different folder. Run
  `python index_corpus.py` from `chapter-17-rag` first.
- **The first `index_corpus.py` seems stuck, or fails with a connection error** → It's
  downloading the embedding model (about 90 MB) and needs the internet. Wait, or check your
  connection and run it again.
- **`index_corpus.py` never finishes and the computer slows down** → You're using code typed
  from the book without the extra line. See "Note for book readers" in Step 3.
- **`No space left on device` while installing** → PyTorch is big. Free some disk space. On
  Linux, use the CPU-only PyTorch line from Step 2.
- **`ModuleNotFoundError: No module named 'chromadb'`** → The toolbox isn't active. Run
  `source venv/bin/activate` again in this terminal.
- **`Address already in use` / "Port 5000 is in use"** when running the container → On a Mac,
  the AirPlay Receiver uses port 5000: turn it off in System Settings → General → AirDrop &
  Handoff, or map another laptop port: `-p 5050:5000`, then use `http://localhost:5050`.
- **`{"error":"RAG call failed",...}` (HTTP 503) from the container** → The robot call failed.
  Terminal 1 shows the reason on the `Failed:` line (401, 404, 429 as above).
- **`Cannot connect to the Docker daemon`** → Start Docker Desktop and wait for "Engine running".

### What you learned in Phase 1

- **RAG** means handing the robot *your* notes first, so it answers from your facts, not
  guesses, and can show its source.
- Text is cut into overlapping **chunks**, and each chunk becomes an **embedding** (numbers
  that capture meaning), so the computer can match by meaning, not exact words.
- A **vector database (ChromaDB)** stores embeddings and finds the closest notes fast.
- The pipeline is three steps: **index** the notes (free), **retrieve** the best ones (free),
  then **ask** the robot using only those notes (paid).
- A strict **system prompt** ("use ONLY these notes, say when you don't know, cite them") keeps
  answers honest.
- More notes per question means more tokens and more cost: retrieval quality is also a cost
  lever.

---

## Phase 2 and Phase 3

- **Phase 2 — Promote it to the cloud:** [cloud/README.md](cloud/README.md). The same
  container on AWS EKS, first with plain YAML, then with the Helm chart and an init container
  that files the notes.
- **Phase 3 — Run it like a Fortune 500 company:** [cloud/PRODUCTION.md](cloud/PRODUCTION.md).
  Identical copies that scale out, keys from the vault, a public address, and what big
  companies add for answer quality and document security.

Build the shared platform first: [../chapter-10-kubernetes/PLATFORM.md](../chapter-10-kubernetes/PLATFORM.md).
It costs money while it runs, so destroy it when you finish.

## Where to next

[Chapter 18 — Run the smart robot for real (Production LLM)](../chapter-18-prodllm/README.md).
Your knowledge platform gives *good* answers. Next you make the robot service *safe, cheap and
reliable* for many users: a cache, spending limits, a safety filter, retries, and alerts on cost.
