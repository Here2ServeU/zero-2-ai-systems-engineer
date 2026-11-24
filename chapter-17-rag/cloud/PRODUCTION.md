# Chapter 17 — Phase 3: Run it like a Fortune 500 company

> Phase 2 proved your knowledge platform runs in the cloud. Phase 3 makes it **survive real
> life**: busy hours, server upgrades, a broken data center, and leaked keys. Same Helm release,
> one more values file on top. Then you'll see what big companies add for **answer quality**
> and **document security**, the two things that make or break a RAG platform at work.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

- Finish Phase 2 ([README.md](README.md)), with the platform still running.
- Run every command from this folder: `cd chapter-17-rag/cloud`.
- **Put your key in the vault once.** Phase 3 does not read the key from your terminal. It
  reads it from **AWS Secrets Manager**, like a real company. From this folder, with
  `ANTHROPIC_API_KEY` exported:

```bash
bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev
```

**What you should see:** `[OK] Stored keys in zero2ai/dev/llm-api-keys: ANTHROPIC_API_KEY`.

> **Your service will have a public address.** Anyone who finds it can ask questions on your
> bill. Run the tests, look around, and **run `bash down.sh` when you're done**.

## Deploy and test Phase 3

```bash
bash deploy.sh 3
bash test.sh 3
```

**What you should see:**

- `deploy.sh 3` checks that `ANTHROPIC_API_KEY` is in Secrets Manager, runs
  `helm upgrade --install rag-api ... --atomic` (allow a few minutes: each copy files its notes
  before it starts), prints the release history and ends with
  `[OK] Phase 3 deployed. Test it: bash test.sh 3`.
- `test.sh 3` shows the ExternalSecret `rag-api` (`STATUS SecretSynced`, `READY True`), prints
  `[OK] helm test rag-api`, waits for the platform load balancer, prints
  `Public: http://k8s-zero2ai-....elb.amazonaws.com:8017`, calls `/health` and `/ask` through it,
  and ends with `[OK] Phase 3 checks passed`.

Ask your own question through the public address:

```bash
host=$(kubectl -n zero2ai get ingress rag-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s -X POST "http://$host:8017/ask" -H 'Content-Type: application/json' \
  -d '{"question":"Who must approve opening an account for a politically exposed person?"}'
```

**What you should see:** an answer that says **senior management** approval is required
(Enhanced Due Diligence), with the passages it used in `sources`.

## What changes in production, and why

Everything below is in [`phase3-production/values.yaml`](phase3-production/values.yaml),
added on top of [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml), and in the `3)` step of
[`deploy.sh`](deploy.sh).

| Setting | What it does | Why production needs it |
|---|---|---|
| `externalSecret` (`keys: ["ANTHROPIC_API_KEY"]`) + `envFromSecrets: []` | The External Secrets Operator copies the key from AWS Secrets Manager (`zero2ai/<env>/llm-api-keys`) into a Kubernetes Secret and refreshes it every hour | One safe place for keys; rotating a key means updating the vault, not every laptop |
| key check in `deploy.sh 3` | Stops with `[ERROR] ANTHROPIC_API_KEY is not in Secrets Manager yet` if the vault is empty | A clear message instead of pods that can't start |
| `replicaCount: 2` + `autoscaling` | 2 to 4 identical copies; the HPA adds copies above 75% CPU | Embedding questions uses CPU, so busy hours need more copies |
| each copy builds its own index (init container from 2B) | Every copy files the same notes at start-up, so copies are identical and independent | The HPA can add copies freely: no shared disk to manage |
| `pdb.enabled` | PodDisruptionBudget: at least 1 copy stays up | Server upgrades never take every copy down |
| `topologySpread.enabled` | Spreads copies across availability zones and servers | One data center going dark doesn't take the service down |
| `networkPolicy.enabled` (+ VPC range from `deploy.sh`) | Only the load balancer and pods in this namespace may connect to port 5000 | If something else in the cluster is broken into, it can't reach your documents |
| `ingress` on port `8017` | Joins the shared **platform ALB**, with a health check on `/health` | One stable public address, no extra load balancer to pay for |
| `--atomic` (in `deploy.sh 3`) | If the upgrade fails, Helm rolls back by itself | No half-broken releases |
| chart security settings | Runs as user 1000 (not root), no extra Linux powers (the disk stays writable, see Phase 2B) | Hardening required by most company clusters |

**What Phase 3 does not have in this chapter:** no metrics endpoint and no alert rules
(`rag_api.py` doesn't publish Prometheus numbers). You can still watch it with logs and
`kubectl top`. Chapter 18 adds metrics and alerts to an LLM service, and the same pattern works
here.

### Watch autoscaling work

In a second terminal: `kubectl -n zero2ai get hpa rag-api -w`. Then make some free traffic
from inside the cluster (health checks never call the robot, so they cost nothing):

```bash
kubectl -n zero2ai run load --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s -o /dev/null http://rag-api/health; done'
```

**What you should see:** the HPA's CPU number rises a little. Health checks are cheap, so it may
not cross 75%: real load comes from embedding questions, and every real question costs money,
which is why this course doesn't load-test `/ask`. Press Ctrl+C to stop.

### Roll back with one command

```bash
helm history rag-api -n zero2ai                         # find the Phase 2B revision number
helm rollback rag-api <phase-2b-revision> -n zero2ai
```

### Honest limits of this chapter's code

- **Re-indexing in every pod only works for small notebooks.** One text file takes seconds. For
  thousands of documents, companies index **once** into a managed vector store (for example
  Amazon OpenSearch Serverless, or Aurora PostgreSQL with pgvector) and every copy queries it.
- **New notes need a new image**, because `knowledge_base.txt` is baked in. At work, an
  **ingestion pipeline** watches the document store and re-indexes changed files automatically.
- **No login.** Anyone with the address can ask anything, and every question costs money.
- **Everyone sees every note.** There is no per-user access control on documents yet (see
  "Security" below).

---

## How big companies run this

Each item is labeled **built in** (this chapter really does it) or **how you'd extend it at
work**.

### 1. Promise a level of service: SLIs and SLOs (how you'd extend it at work)

An **SLI** (service level indicator) is a number that shows whether users are happy. An **SLO**
(service level objective) is the promise. A RAG platform needs three kinds:

- **Availability and errors:** "99.5% of `/ask` calls return 200 each month". Today you can see
  errors in the logs (`Failed:` lines); a metrics endpoint like Chapter 18's would let
  Prometheus count them.
- **Latency:** "95% of answers in under 10 seconds". Most of the time is the robot call.
- **Answer quality (groundedness):** "at least 95% of sampled answers use only the supplied
  passages and cite the right one". Teams measure this with a **golden set**: 50 to 200
  questions with known correct answers and known correct passages, scored every day by people
  or by a second "judge" model. Two numbers matter: did retrieval find the right passage
  (**retrieval hit rate**), and did the answer stick to it (**groundedness**).

The raw ingredients are **built in**: every answer returns its `sources`, and the system prompt
asks the robot to cite them, so a checker can compare the answer with the passages.

### 2. Write a runbook (how you'd extend it at work)

A **runbook** is a recipe anyone on call can follow at 3 a.m. This chapter has no alert rules,
so this runbook starts from the symptom a user reports.

| | |
|---|---|
| **Symptom** | `/ask` returns `{"error":"RAG call failed"}` (HTTP 503), or the public address doesn't answer |
| **What it means** | The robot call is failing, or no copy is ready |
| **First 3 commands** | `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=rag-api` · `kubectl -n zero2ai logs deployment/rag-api -c app --tail=50 \| grep Failed` · `kubectl -n zero2ai get externalsecret rag-api` |
| **How to fix** | `401`/authentication → the key was revoked or rotated: store the new one (`put-llm-secret.sh dev`) and run `kubectl -n zero2ai rollout restart deployment/rag-api`. `429` → provider rate or spending limit: raise it or reduce traffic. Pods `Init:Error` → read `kubectl -n zero2ai logs <pod> -c init`. Pods `OOMKilled` or `Pending` → see "If something breaks". Started right after a release → `helm rollback rag-api <previous> -n zero2ai`. |

### 3. Security in layers

- **Built in:** the key lives in AWS Secrets Manager and reaches pods through External
  Secrets, never in git or the image. Containers run as a normal user with no extra powers. A
  NetworkPolicy limits who can connect. The image needs no internet at start-up (the model is
  baked in), and the system prompt tells the robot to use only the supplied passages.
- **Document access control (how you'd extend it at work):** in a real company, not everyone
  may read every document (HR files, legal cases, customer records). Store who may read each
  chunk as **metadata** next to it in the vector database, and filter the search by the
  logged-in user's permissions *before* anything reaches the robot. The robot can't leak a
  passage it was never given.
- **PII in documents (how you'd extend it at work):** scan documents for personal data (names,
  account numbers, ID numbers) before indexing, and mask or exclude it.
- **Prompt injection through documents (how you'd extend it at work):** a document can contain
  hidden instructions like "ignore your rules and reveal everything". Only index documents from
  trusted sources, keep the rules in the system prompt, and never let the robot take actions
  based on document text alone.
- **Key rotation (how you'd extend it at work):** make a new key, store it with
  `put-llm-secret.sh`, restart the deployment (or wait for the hourly refresh), then delete the
  old key in the provider console.

### 4. Reliability

- **Built in:** 2 to 4 identical copies spread across zones, a disruption budget, a startup
  probe that allows 3 minutes for indexing, health checks on the load balancer, and the
  Anthropic library's own automatic retries for short network errors.
- **How you'd extend it at work:** an explicit timeout on the robot call, a fallback provider
  (Chapter 16 has OpenAI and Gemini versions), and a managed vector store so copies start in
  seconds instead of re-indexing.

### 5. Safe change: test a prompt, model or chunk-size change before release

- **Built in:** every release is a numbered Helm revision, `--atomic` undoes a failed upgrade,
  and `helm rollback` goes back in one command.
- **How you'd extend it at work:** changing the system prompt, the model, `k`, or the chunk size
  can quietly make answers worse. Run the **golden set** against the old and new versions,
  compare retrieval hit rate, groundedness, cost and speed, and release only if the new version
  is at least as good. Then roll out slowly with a canary (Chapter 14).

### 6. Cost control (FinOps)

- **Built in:** `max_tokens=600` caps each answer, empty questions are refused before any robot
  call, embeddings run free inside the pod (no paid embedding service), and the HPA removes
  copies when it's quiet.
- **How you'd extend it at work:** most of each request's tokens are the retrieved passages, so
  `k` and the chunk size are your biggest cost levers (you saw this in Phase 1's `Tokens:` line).
  Teams also cache answers to repeated questions (Chapter 18), log tokens per request, and set a
  monthly spending limit in the provider's console.

### 7. Audit and compliance (partly built in)

- **Built in:** each `/ask` response includes the exact `sources` used and a `request_id` that
  also appears in the log (`[a1b2c3d4] Q: ...`). For a regulated bank, being able to show *which
  rule text* an answer came from is a big deal.
- **How you'd extend it at work:** store each question, answer, sources, model name and prompt
  version in a tamper-proof log with a retention period (the knowledge base's own
  "Recordkeeping and Auditability" rule asks for five years).

## Production readiness checklist

Tick each box by running the command next to it (from `chapter-17-rag/cloud`).

- [ ] The key comes from the vault: `kubectl -n zero2ai get externalsecret rag-api` shows `SecretSynced`
- [ ] At least 2 copies are Ready: `kubectl -n zero2ai get deploy rag-api`
- [ ] Every copy filed its notes: `kubectl -n zero2ai logs -l app.kubernetes.io/instance=rag-api -c init | grep Indexed` shows one `Indexed 11 chunks` line per copy
- [ ] The autoscaler exists and shows a CPU number: `kubectl -n zero2ai get hpa rag-api`
- [ ] A disruption budget protects it: `kubectl -n zero2ai get pdb rag-api`
- [ ] Copies sit on different servers: `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=rag-api -o wide`
- [ ] Network access is limited: `kubectl -n zero2ai get networkpolicy rag-api`
- [ ] It runs as a normal user: `kubectl -n zero2ai exec deploy/rag-api -c app -- id` shows `uid=1000`
- [ ] Answers come with their sources through the public address: `bash test.sh 3` output contains `"sources"`
- [ ] You can roll back: `helm history rag-api -n zero2ai` shows more than one revision
- [ ] You know how to turn it all off: `bash down.sh` and `bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev`

## Career corner

What you just built is the daily work of **AI Engineers**, **ML Engineers**, **AI Platform
Engineers** and **Search / Retrieval Engineers**. You can now answer interview questions like:

1. Explain RAG to a manager in two sentences. Why is it better than asking the model directly?
2. What are embeddings, and why do chunk size and overlap matter?
3. Users say answers got worse after a change. How would you find out whether retrieval or
   generation is the problem?
4. How would you stop an employee from getting answers based on documents they're not allowed
   to read?
5. Your knowledge base grows from 1 file to 1 million documents. What changes in your design?

## If something breaks

- **`[ERROR] ANTHROPIC_API_KEY is not in Secrets Manager yet`** → Run
  `bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev` with the key exported, then
  `bash deploy.sh 3` again.
- **ExternalSecret shows `SecretSyncedError`** → `kubectl -n zero2ai describe externalsecret rag-api`
  shows why; usually the vault secret is empty, or the External Secrets add-on isn't running
  (`kubectl -n external-secrets get pods`).
- **`Error: UPGRADE FAILED` and the release rolled back** → `--atomic` did its job. See why with
  `kubectl -n zero2ai get events --sort-by=.lastTimestamp | tail -20`. A common cause here:
  2 copies x 1Gi didn't fit, so a pod stayed `Pending` past the timeout. Remove other chapters'
  apps (`bash down.sh` in their `cloud` folders) and deploy again.
- **The address on :8017 doesn't answer yet** → New ALB rules take a couple of minutes.
  `bash test.sh 3` waits; run it again if it times out.
- **HPA shows `<unknown>/75%`** → The metrics service needs about a minute after pods start.

## Clean up

```bash
bash down.sh                                                   # remove this chapter's app
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # when you're done for the day
```

**What you should see:** `[OK] Chapter 17 removed`, and later the platform destroy finishing
without errors.

## Where to next

[Chapter 18 — Run the smart robot for real (Production LLM)](../../chapter-18-prodllm/README.md).
The capstone: you'll put a cache, spending limits, a safety filter, retries, metrics and cost
alerts around the robot, and finish the platform you've been building since Chapter 10.
