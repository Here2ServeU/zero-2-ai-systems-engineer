# Chapter 17 — Phase 2: Promote it to the cloud (AWS EKS)

> In Phase 1 you built the RAG pipeline on your laptop and packed it into a container with a
> web door ([`rag_api.py`](../rag_api.py)): `POST /ask {"question": "..."}` returns an answer
> plus the passages it used. Now you move the **same container** to a real cloud cluster in
> two small steps: **2A** with plain Kubernetes YAML, then **2B** with the shared Helm chart and
> an **init container**. Phase 3 ([PRODUCTION.md](PRODUCTION.md)) makes it production-grade.

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

## Before you start

1. **Finish Phase 1** ([../README.md](../README.md)), including Step 7 (the container).
2. **Build the shared cloud platform once:**
   [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md). It
   creates the EKS cluster, your image shelf (ECR) and the add-ons, and takes about 20 minutes.
3. **Costs money.** The cluster costs money every hour it exists, and each robot question costs
   a fraction of a cent. Get permission if the accounts aren't yours, and **tear everything down
   when you finish** (see "Clean up").
4. **Set your API key in this terminal** (same as Phase 1):

```bash
export ANTHROPIC_API_KEY='paste-your-key-here'
```

**Run every command on this page from this folder:**

```bash
cd chapter-17-rag/cloud
```

## What changes from your laptop to the cloud

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| Image built on your laptop | Image pushed to **ECR**, your private image shelf in AWS | Cloud servers can't see your laptop |
| `docker run -e ANTHROPIC_API_KEY` | A Kubernetes **Secret** called `llm-api-keys`, made from your terminal's key | The key reaches the pod without ever being written to a file or to git |
| `curl localhost:5000` | A **port-forward** tunnel to the Service (port 80 → 5000) | Phase 2 stays private: no public address yet |
| One container files the notes, then serves (2A) | 2B: an **init container** files the notes, then the app container serves | Each step does one job, and you can read each step's log separately |
| No size limits | Each copy asks for 250m CPU and 1Gi memory, and may use at most 2Gi | PyTorch and the embedding model need about 1 GB; the cluster must pick a server with room |
| The model downloads on first run | The model is **already inside the image** (downloaded at build time) | Pods start faster and never depend on the model website |

## New words

- **Init container** — A container that runs to the end *before* the app container starts, in
  the same pod. Here it runs `index_corpus.py`.
- **Scratch folder (emptyDir)** — An empty folder that both containers in a pod share. Here it's
  `/app/vector_db`: the init container fills it, the app reads it. It disappears with the pod.
- **Secret** — A Kubernetes object that holds private values (like API keys) and hands them to
  pods as environment variables.
- **port-forward** — A tunnel from a port on your laptop to a Service inside the cluster.

## Step 0 — Build the image and push it to ECR

```bash
bash deploy.sh build
```

This logs in to ECR, builds [`../Dockerfile`](../Dockerfile) for `linux/amd64` (the kind of
computer EKS uses, even on an Apple Silicon Mac), tags it with your git commit, and pushes it.
The image is about **1.5 GB** (CPU-only PyTorch plus the embedding model), so the first build
and push are slow: allow 5 to 15 minutes depending on your internet upload speed.

**What you should see:** Docker build steps, then `[OK] Pushed ...zero2ai-dev/rag-api:<tag>`.

---

## Phase 2A — Plain YAML: one container does both steps

Open [`phase2a-yaml/deployment.yaml`](phase2a-yaml/deployment.yaml). It is one Deployment named
`rag-api-p1` that runs your image exactly like `docker run` did: the image's default command
`python index_corpus.py && python rag_api.py` files the notes and then serves. It adds:

- `envFrom: secretRef: llm-api-keys` — the key, like `-e ANTHROPIC_API_KEY` on your laptop.
- `resources` — 250m CPU and 1Gi memory requested, at most 2Gi.
- a `readinessProbe` on `/health` that waits 20 seconds and then allows up to about 2.5
  more minutes, because filing the notes and loading the model take a while.

[`phase2a-yaml/service.yaml`](phase2a-yaml/service.yaml) is the front desk: port `80` → `5000`.

```bash
bash deploy.sh 2a
bash test.sh 2a
```

**What you should see:**

- `deploy.sh 2a` prints `[OK] Secret llm-api-keys is ready (keys: ANTHROPIC_API_KEY )`, applies
  the two files, waits (often about a minute) for
  `deployment "rag-api-p1" successfully rolled out`, and ends with
  `[OK] Phase 2A deployed. Test it: bash test.sh 2a`.
- `test.sh 2a` opens a tunnel, calls `GET /health` → `{"status":"healthy"}`, then
  `POST /ask {"question":"What documents are required for KYC?"}` → JSON with an `answer`, the
  `sources` it used, the token counts and a `request_id` (it prints the first 1,500
  characters). It ends with `[OK] Phase 2A checks passed`.

What `test.sh 2a` does, by hand (two terminals):

```bash
kubectl -n zero2ai port-forward service/rag-api-p1 8080:80          # terminal 1: the tunnel
curl -s http://localhost:8080/health                                # terminal 2
curl -s -X POST http://localhost:8080/ask -H 'Content-Type: application/json' \
  -d '{"question":"What is the cash reporting threshold?"}'
```

Explore it:

```bash
kubectl -n zero2ai get pods -l app=rag-api-p1                 # one copy, Running
kubectl -n zero2ai logs deployment/rag-api-p1 | head -5       # "Produced 11 chunks", "Indexed 11 chunks", then Flask
kubectl -n zero2ai top pod -l app=rag-api-p1                  # memory: several hundred MiB, mostly PyTorch and the model
```

---

## Phase 2B — Helm, with an init container

Now the two steps get a container each, using the shared chart
[`../../chapter-10-kubernetes/helm/zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app)
and this chapter's answers in [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml):

- `initCommand: ["python", "index_corpus.py"]` — the **init container** files the notes.
- `command: ["python", "rag_api.py"]` — then the **app container** serves them.
- `scratchMounts: ["/app/vector_db"]` — the shared scratch folder between the two.
- `envFromSecrets: ["llm-api-keys"]` — the same Secret as 2A.
- `securityContext.readOnlyRootFilesystem: false` — the chart normally makes the disk
  read-only, but the embedding library may write small lock files next to its model, so this
  app keeps a writable disk. Everything else stays hardened (normal user, no extra powers).
- The chart adds a **startup probe** that gives the app up to 3 minutes to start.

```bash
bash deploy.sh 2b
bash test.sh 2b
```

**What you should see:** `deploy.sh 2b` removes the 2A objects, refreshes the Secret, runs
`helm upgrade --install rag-api ...`, prints the release history and ends with
`[OK] Phase 2B deployed. Test it: bash test.sh 2b`. `test.sh 2b` first prints the init
container's last log lines, including `Indexed 11 chunks`, then `[OK] helm test rag-api` (a
tiny pod inside the cluster called `/health`), then the same `/health` and `/ask` checks as 2A,
and ends with `[OK] Phase 2B checks passed`.

### Commands to explore

From `chapter-17-rag/cloud`:

```bash
kubectl -n zero2ai logs deployment/rag-api -c init           # the filing step's log
kubectl -n zero2ai logs deployment/rag-api -c app --tail=20  # the web door's log, with request ids
kubectl -n zero2ai describe pod -l app.kubernetes.io/instance=rag-api | grep -A3 'Init Containers'
helm get values rag-api -n zero2ai                           # the answers this release used
helm history rag-api -n zero2ai                              # numbered revisions
helm rollback rag-api 1 -n zero2ai                           # back to revision 1
```

## Try it yourself

- Watch the two steps happen in order. In one terminal run
  `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=rag-api -w`, and in another run
  `kubectl -n zero2ai rollout restart deployment/rag-api`. The new pod shows `Init:0/1`, then
  `PodInitializing`, then `Running`. Press Ctrl+C to stop watching.
- Add the ATM line from Phase 1's "Try it yourself" to `../knowledge_base.txt`, then run
  `bash deploy.sh build` and `bash deploy.sh 2b`. Ask about it with the port-forward commands
  above. New notes need a new image here, because the notes are baked into it. Phase 3 explains
  how big companies avoid that.

## If something breaks

- **`[ERROR] Set at least one key first, e.g. export ANTHROPIC_API_KEY=...`** → `export` the key
  in this terminal (see "Before you start") and deploy again.
- **`Cluster zero2ai-eks-dev not found`** → Build the platform first:
  [PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).
- **`No image recorded for 'rag-api'`** → Run Step 0 first: `bash deploy.sh build`.
- **`build` is very slow or fails with `no space left on device`** → The image is big. Free disk
  space on your laptop (`docker system prune` removes old images you no longer need) and try
  again.
- **The rollout waits a long time** → Normal for the first start: filing the notes and loading
  the model take about a minute. It gives up after 10 minutes.
- **Pod `OOMKilled`** (`kubectl -n zero2ai get pods` shows it restarting) → It ran out of memory.
  The 2Gi limit is usually plenty; check nothing else changed `resources`.
- **Pod `Pending`** with `Insufficient memory` in `kubectl -n zero2ai describe pod ...` → The
  servers are full (each copy asks for 1Gi). Remove other chapters' apps with their `down.sh`,
  or wait: the platform's Cluster Autoscaler adds a server within a few minutes.
- **`[ERROR] POST http://localhost:8080/ask failed`** → The robot call failed (HTTP 503). Read why:
  `kubectl -n zero2ai logs deployment/rag-api -c app --tail=20` (use `rag-api-p1` in 2A, without
  `-c app`). `401` = wrong key: export the right one and deploy again. `404` = model not
  available to your account (see Phase 1, Step 5). `429` = rate or spending limit.
- **Pods stuck in `CreateContainerConfigError`** → The `llm-api-keys` Secret is missing. Deploy
  again with the key exported.
- **`bash deploy.sh` prints `Usage: deploy.sh <build|2a|2b|3>`** → Use `build`, `2a`, `2b` or `3`.

## Clean up

```bash
bash down.sh                                                   # remove this chapter's app (the cluster stays)
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # delete the whole platform when you're done for the day
```

**What you should see:** `[OK] Chapter 17 removed`, and later the platform destroy finishing
without errors. After `platform-down.sh`, nothing from this course costs money.

## Next: Phase 3

Your knowledge platform runs in the cloud. Now run it the way big companies do:
**[PRODUCTION.md](PRODUCTION.md)**.
