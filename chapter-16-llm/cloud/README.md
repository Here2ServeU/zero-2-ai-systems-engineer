# Chapter 16 — Phase 2: Promote it to the cloud (the chat API on EKS)

> Phase 1 (your laptop) is in [../README.md](../README.md). Phase 3 (production) is in
> [PRODUCTION.md](PRODUCTION.md).
> Build the shared platform first: [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).

**Labels:** Needs an AWS account that costs money · Needs an LLM account that may cost money · Needs the internet

---

> ### Money and secrets
>
> - The shared platform costs roughly $0.15-0.30 per hour while it exists (see PLATFORM.md).
>   Always finish with the clean-up steps at the bottom.
> - Every question to the robot costs a fraction of a cent. Each `test.sh` run asks **one**
>   question.
> - Keys are **never** put in the image, in a values file, or in git. They go from your
>   terminal's environment variables straight into the cluster.
> - Pick **one** provider with `LLM_PROVIDER=anthropic`, `openai` or `gemini` (default
>   `anthropic`). Gemini has a free tier.

## What changes from your laptop to the cloud, and why

| On your laptop (Phase 1) | On EKS (Phase 2) | Why |
|---|---|---|
| The key lived in your terminal (`export ANTHROPIC_API_KEY=...`) | The key lives in a **Kubernetes Secret** called `llm-api-keys`, made from your terminal's variable | Pods can't read your terminal. A Secret is the cluster's locked drawer, and pods read it as environment variables, so the code doesn't change at all |
| `docker run -e ANTHROPIC_API_KEY ...` | The Deployment says `envFrom: secretRef: llm-api-keys` | Same idea: the key is handed to the container when it starts, never baked in |
| You picked the file to run (`python llm_api_gemini.py`) | `LLM_PROVIDER=gemini` picks the command for you | Switching providers is one setting, not a code change. That's the "gateway" idea |
| `curl http://localhost:5000/chat` | A tunnel (port-forward) to the Service, then the same `curl` | In Phase 2 the app is private inside the cluster. Phase 3 gives it a public address |
| Nobody checks if the app is alive | Kubernetes calls `/health` (a **readiness probe**) and only sends traffic to copies that answer | A broken copy gets no visitors |

## New words

- **Kubernetes Secret** — Kubernetes' locked drawer for small secrets. Pods read it as
  environment variables. (Careful: anyone allowed to read Secrets in the namespace can read the
  key. The values are only base64-encoded, which is *not* encryption.)
- **`LLM_PROVIDER`** — a setting for `deploy.sh` that picks which company's front-desk file to
  run: `anthropic` (`llm_api.py`), `openai` (`llm_api_openai.py`) or `gemini`
  (`llm_api_gemini.py`).
- **port-forward** — a private tunnel from your laptop into the cluster, so
  `http://localhost:8080` reaches the app.
- **helm test** — a tiny pod the chart starts that calls `/health`, to prove the release works.

## Before you start

1. The platform is up: `bash chapter-10-kubernetes/scripts/platform-up.sh dev` from the top of
   the repo ([PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md), about 20 minutes).
2. Phase 1 works on your laptop with your key, so you know the key is good.
3. Your key is exported **in the terminal you'll use** (Phase 1, Step 3). Pick your line:

   ```bash
   export ANTHROPIC_API_KEY='your-key-here'                         # default provider
   # export OPENAI_API_KEY='your-key-here'; export LLM_PROVIDER=openai
   # export GEMINI_API_KEY='your-key-here'; export LLM_PROVIDER=gemini
   ```

Every command below runs from **this folder**: `chapter-16-llm/cloud`.

```bash
cd chapter-16-llm/cloud
```

---

## Step 0 — Build the image and push it to the cloud

From `chapter-16-llm/cloud`:

```bash
bash deploy.sh build
```

This logs in to **ECR** (your private image shelf in AWS), builds the same `Dockerfile` you used
in Phase 1 for `linux/amd64` (the kind of computer EKS runs), and pushes it. One image holds all
three providers' code. No key is involved.

**What you should see:** build and push lines, ending with
`[OK] Pushed <account>.dkr.ecr.us-east-1.amazonaws.com/zero2ai-dev/llm-api:<tag>`.

---

## Phase 2A — Plain YAML, key from your terminal

Two small files in [`phase2a-yaml/`](phase2a-yaml):

- [`deployment.yaml`](phase2a-yaml/deployment.yaml) — run 1 copy of the image with
  `command: ["python", "__SCRIPT__"]` (`deploy.sh` fills in the file for your provider) and
  `envFrom: secretRef: llm-api-keys` (the key). It asks for a little CPU and memory, and uses
  `/health` as its readiness probe.
- [`service.yaml`](phase2a-yaml/service.yaml) — a stable name, `llm-api-p1`, on port 80, in
  front of the app's port 5000.

`deploy.sh 2a` first runs the equivalent of
`kubectl create secret generic llm-api-keys --from-literal=ANTHROPIC_API_KEY=...` using the keys
in your terminal (never a file), then applies the two YAML files.

From `chapter-16-llm/cloud`:

```bash
bash deploy.sh 2a
```

**What you should see:** `[OK] Secret llm-api-keys is ready (keys: ANTHROPIC_API_KEY )`,
`==> Phase 2A with anthropic (llm_api.py)`, `deployment.apps/llm-api-p1 created`,
`service/llm-api-p1 created`, `deployment "llm-api-p1" successfully rolled out`, and
`[OK] Phase 2A deployed. Test it: bash test.sh 2a`.

```bash
bash test.sh 2a
```

This opens a tunnel to the Service (`localhost:8080` -> `llm-api-p1:80`), calls `/health`, then
asks one real question: "In one sentence: what is a chargeback?"

**What you should see:**

```
GET http://localhost:8080/health
{"status":"healthy"}

POST http://localhost:8080/chat  {"question":"In one sentence: what is a chargeback?"}
{"answer":"A chargeback is ...","request_id":"1a2b3c4d","tokens_in":40,"tokens_out":35,"ts":"..."}

[OK] Phase 2A checks passed
```

---

## Phase 2B — Helm, switch provider with one setting

Now install the course's shared Helm chart
([`chapter-10-kubernetes/helm/zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app)) with
[`phase2b-helm/values.yaml`](phase2b-helm/values.yaml):

- `command: ["python", "llm_api.py"]` — the default; `deploy.sh` replaces it for your provider.
- `containerPort: 5000`, `replicaCount: 1`.
- `envFromSecrets: ["llm-api-keys"]` — the key still comes from the Secret made from your
  terminal.

The chart adds safety settings on top: the app runs as a non-root user with a read-only file
system, and gets startup, readiness and liveness probes. `deploy.sh 2b` removes the Phase 2A
objects first, and stamps the pods with the time so they restart and pick up a changed key.

From `chapter-16-llm/cloud`:

```bash
bash deploy.sh 2b
```

**What you should see:** `[OK] Secret llm-api-keys is ready (...)`, Helm output with
`STATUS: deployed`, a short `helm history` table, and
`[OK] Phase 2B deployed (anthropic). Test it: bash test.sh 2b`.

```bash
bash test.sh 2b
```

**What you should see:** `[OK] helm test llm-api`, then the same `GET .../health` and
`POST .../chat` lines as 2A, and `[OK] Phase 2B checks passed`.

### Try it: switch provider with one setting

If you have a second provider's key (Gemini's free tier works), export it and redeploy. From
`chapter-16-llm/cloud`:

```bash
export GEMINI_API_KEY='your-gemini-key'
LLM_PROVIDER=gemini bash deploy.sh 2b
bash test.sh 2b
```

**What you should see:** `[OK] Phase 2B deployed (gemini). ...`, then an answer written by
Gemini. Same image, same chart, different robot. Your other apps never noticed.

---

## Explore with kubectl and helm

From anywhere (these talk to the cluster):

```bash
kubectl -n zero2ai get pods -l app.kubernetes.io/instance=llm-api      # your copy
kubectl -n zero2ai logs deploy/llm-api --tail=20                       # ticket numbers and token counts
kubectl -n zero2ai get secret llm-api-keys                             # the Secret exists (values hidden)
kubectl -n zero2ai describe secret llm-api-keys                        # key NAMES and sizes, not values
helm get values llm-api -n zero2ai                                     # the settings Helm used (no key in here)
helm history llm-api -n zero2ai                                        # every upgrade, numbered
```

**What you should see:** one `Running` pod; log lines like
`INFO [1a2b3c4d] tokens in/out: 40/35`; the Secret `llm-api-keys` of type `Opaque`; under
**Data**, lines like `ANTHROPIC_API_KEY:  108 bytes`; and values that show the `command` and
`envFromSecrets` but never the key.

> Avoid `kubectl get secret llm-api-keys -o yaml`: it prints the key (only base64-encoded) to your
> screen, where it could end up in a screenshot or your terminal history.

---

## If something breaks

- **`Set at least one key first, e.g. export ANTHROPIC_API_KEY=...`** -> No key is exported in
  this terminal. Export it (see "Before you start") and run `deploy.sh 2a` or `2b` again.
- **`LLM_PROVIDER must be anthropic, openai or gemini`** -> Check the spelling (all lower case).
- **`Usage: deploy.sh <build|2a|2b|3>`** -> You used a phase that doesn't exist (the old `1`, `2`,
  `3` numbering is gone). Use `build`, `2a`, `2b` or `3`.
- **`Cluster zero2ai-eks-dev not found`** -> Build the platform first (see "Before you start").
- **`No image recorded for 'llm-api'`** -> Run `bash deploy.sh build` first.
- **Pod in `CrashLoopBackOff`, and `kubectl -n zero2ai logs deploy/llm-api` (or
  `deploy/llm-api-p1`) shows `KeyError: 'GEMINI_API_KEY'`** -> The Secret doesn't hold the key
  for the provider you picked. Example: you chose `LLM_PROVIDER=gemini` but only exported
  `ANTHROPIC_API_KEY`. Export the matching key and deploy again.
- **Pod `CreateContainerConfigError: secret "llm-api-keys" not found`** -> The Secret was deleted.
  Export a key and rerun `bash deploy.sh 2a` or `2b`.
- **`POST .../chat failed`** -> The front desk answered `500`. Read why:
  `kubectl -n zero2ai logs deploy/llm-api --tail=30` (`deploy/llm-api-p1` in 2A). Usually it's an
  invalid key (`AuthenticationError` / `API key not valid`), no credit left, or a rate limit
  (`429`). Fix the key, then deploy again so the pods pick it up.
- **You changed the key but the app still uses the old one** -> Pods read Secrets only when they
  start. `deploy.sh 2a` and `2b` restart them for you; or run
  `kubectl -n zero2ai rollout restart deploy/llm-api`.
- **`port-forward` errors, or `address already in use` on 8080** -> Something on your laptop uses
  port 8080. Close it and run `test.sh` again.

## Clean up

Remove this chapter's app (the cluster keeps running). From `chapter-16-llm/cloud`:

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 16 removed (the llm-api-keys Secret is kept for Chapters 17-18; ...)`.
If you're not going on to Chapter 17 today, delete the Secret too:

```bash
kubectl -n zero2ai delete secret llm-api-keys
```

**What you should see:** `secret "llm-api-keys" deleted`.

Finished for the day? Destroy the platform so it stops costing money. From `chapter-16-llm/cloud`:

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

**What you should see:** Terraform destroying everything, ending with
`[OK] Everything for dev is destroyed.`

## Next

Move the keys out of everyone's terminal and into a real vault: [PRODUCTION.md](PRODUCTION.md).
