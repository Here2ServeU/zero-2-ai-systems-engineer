# Chapter 17 — Cloud track: RAG as a web service on EKS

> Chapter 17 ran as three scripts. For the cloud it becomes a small web API,
> [`rag_api.py`](../rag_api.py): `POST /ask {"question": "..."}` → answer + the passages used.
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

Uses **Anthropic Claude** like the chapter's code: `export ANTHROPIC_API_KEY=...` first.

## New words

- **Init container** — Runs to completion *before* the app container starts, in the same pod.
  Here: `index_corpus.py` files the notes into the search index.
- **Shared scratch folder (emptyDir)** — A folder both containers in a pod can use; here
  `/app/vector_db`.

## Step 0 — Build and push (big image)

The [`Dockerfile`](../Dockerfile) installs **CPU-only PyTorch** (GPU builds are ~4 GB bigger) and
downloads the `all-MiniLM-L6-v2` embedding model **at build time**, so pods start fast and never
fetch it from the internet. Expect ~1.5 GB and a slow first push.

```bash
cd chapter-17-rag/cloud
bash deploy.sh build
```

## Phase 1 — One container does both steps

The image's default command is `python index_corpus.py && python rag_api.py`.

```bash
bash deploy.sh 1
bash test.sh 1       # asks: "What documents are required for KYC?"
```

## Phase 2 — Init container + app container

[`phase2/values.yaml`](phase2/values.yaml): `initCommand` builds the index, `command` serves it,
`scratchMounts: ["/app/vector_db"]` is the shared folder.

```bash
bash deploy.sh 2
bash test.sh 2       # also prints the init container's "Indexed N chunks"
```

## Phase 3 — Scale out, secrets from the vault

Each copy builds its own small index at start-up, so copies are **identical and independent**:
the HPA can add copies without any shared disk. Keys come from Secrets Manager (see Chapter 16).

```bash
bash ../../platform/scripts/put-llm-secret.sh dev
bash deploy.sh 3
bash test.sh 3
```

> **When the notebook grows:** re-indexing per pod is fine for one text file. For thousands of
> documents, index once into a managed vector store (e.g. Amazon OpenSearch Serverless or
> Aurora PostgreSQL with pgvector) and let every copy query it.

## If something breaks

- **Pod `OOMKilled`** → PyTorch + the model need ~1 GB. Values set a 2 GiB limit; dev nodes
  (t3.medium, 4 GB) fit two copies.
- **Startup takes ~1 minute** → Normal: the index is built before the app starts. The chart's
  startup probe allows up to 3 minutes.

## Clean up / next

`bash down.sh` · Next: [Chapter 18's cloud track](../../chapter-18-prodllm/cloud/README.md).
