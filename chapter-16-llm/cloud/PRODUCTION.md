# Chapter 16 — Phase 3: Run it like a Fortune 500 company

> Phase 1 (laptop): [../README.md](../README.md) · Phase 2 (cloud): [README.md](README.md).
> You need Phase 2 working first, and the shared platform from
> [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).

**Labels:** Needs an AWS account that costs money · Needs an LLM account that may cost money · Needs the internet

---

## The big idea (in plain words)

In Phase 2 the key went from *your* terminal into the cluster. That's fine for one person
practising. In a big company it's a problem: who has the key on their laptop? What happens when
someone leaves? How do you change the key without breaking the app?

So in production the key lives in a **vault**, **AWS Secrets Manager**. Nobody's terminal is
needed to run the app. A helper called **External Secrets** copies the key from the vault into the
cluster, and copies it again every hour, so changing ("rotating") the key is easy.

## New words

- **AWS Secrets Manager** — AWS's vault for secrets. Terraform made an empty one for you in
  Chapter 10, named `zero2ai/<env>/llm-api-keys` (for example `zero2ai/dev/llm-api-keys`).
- **External Secrets Operator** — a helper running in the cluster that copies values from the
  vault into a normal Kubernetes Secret, and re-copies them every hour.
- **SecretStore** — tells External Secrets *where* the vault is (Secrets Manager, in your region).
- **ExternalSecret** — tells External Secrets *what* to copy (which key) and *into which*
  Kubernetes Secret (here `llm-api-secrets`).
- **Pod Identity** — a way for one pod to get AWS permissions without any password or access key
  stored anywhere.
- **Key rotation** — swapping an old key for a new one on purpose, regularly or after a leak.

## Deploy and test

Every command runs from `chapter-16-llm/cloud`. Step 0 (`bash deploy.sh build`) from Phase 2 must
have run at least once.

**1. Put your key in the vault (once).** With your key exported in this terminal (and
`LLM_PROVIDER` if not Anthropic):

```bash
bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev
```

**What you should see:** `[OK] Stored keys in zero2ai/dev/llm-api-keys: ANTHROPIC_API_KEY`
(the key *names* only, never the values).

> `put-llm-secret.sh` **replaces** the whole vault entry with the keys exported right now. Using
> two providers? Export both keys before you run it, or the one you didn't export is removed.

**2. Deploy:**

```bash
bash deploy.sh 3
```

`deploy.sh 3` first checks the vault really holds the key for your provider. If not, it stops with
`[ERROR] ANTHROPIC_API_KEY is not in Secrets Manager yet. Run: ...`.

**What you should see:** Helm output with `STATUS: deployed`, a `helm history` table, then
`[OK] Phase 3 deployed (anthropic, keys from Secrets Manager). Test it: bash test.sh 3`. If the
new version doesn't become healthy within 10 minutes, `--atomic` rolls it back automatically and
you see an error instead.

**3. Test:**

```bash
bash test.sh 3
```

This shows the ExternalSecret's status, runs `helm test`, waits for the public load balancer, then
asks one question through it (a fraction of a cent).

**What you should see** (addresses shortened; the table columns can differ slightly between External Secrets versions):

```
==> External Secrets status (Ready=True means the key was copied from AWS)
NAME      STORE         REFRESH INTERVAL   STATUS         READY
llm-api   llm-api-aws   1h                 SecretSynced   True
[OK] helm test llm-api
==> Waiting for the AWS load balancer for ingress/llm-api (first time: 2-4 minutes)
==> Public: http://k8s-zero2ai-....elb.amazonaws.com:8016
GET http://k8s-zero2ai-....elb.amazonaws.com:8016/health
{"status":"healthy"}
POST http://k8s-zero2ai-....elb.amazonaws.com:8016/chat  {"question":"In one sentence: what is a chargeback?"}
{"answer":"A chargeback is ...","request_id":"...","tokens_in":40,"tokens_out":35,"ts":"..."}
[OK] Phase 3 checks passed
```

> **A public chat endpoint spends your money.** Anyone who finds the address can ask questions on
> your bill. Don't share it, run `bash down.sh` when you're done, and read "Cost" below for how
> companies lock it down.

## What changes in production and why

All of this comes from [`phase3-production/values.yaml`](phase3-production/values.yaml), added on
top of [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml), plus settings that
[`deploy.sh`](deploy.sh) adds in its `3)` branch.

| What | Setting | Why |
|---|---|---|
| **Key from the vault** | `externalSecret.enabled: true`; `deploy.sh` sets `remoteKey` (`zero2ai/<env>/llm-api-keys`), `keys` (just your provider's key) and `region` | No human terminal is needed to run the app. The key has one home, the vault |
| **No more terminal-made Secret** | `envFromSecrets: []`, and `deploy.sh 3` deletes `llm-api-keys` afterwards | Only one copy of the key in the cluster, made by External Secrets |
| **Hourly re-copy** | `refreshInterval: 1h` | Change the key in the vault and the cluster picks it up within an hour (or right away with a force-sync) |
| **Least privilege** | External Secrets reads AWS with its own Pod Identity role, allowed to read **only** `zero2ai/<env>/*` (from Chapter 10's Terraform). The app pod itself gets no AWS permissions and no Kubernetes API token | If the app is broken into, it can't read other secrets |
| **Only the key it needs** | `externalSecret.keys` = one key (for example `ANTHROPIC_API_KEY`) | A pod running Gemini never holds the Anthropic key |
| **Two copies, autoscaling** | `replicaCount: 2`, `autoscaling: 2 to 4 copies` (target 70% CPU, chart default) | One copy can fail and the other keeps answering; busy times get more copies |
| **Disruption budget** (PDB) | `pdb.enabled: true` | When AWS replaces a node, at least 1 copy stays up |
| **Zone spreading** | `topologySpread.enabled: true` | Copies spread across availability zones and nodes |
| **Network rules** (NetworkPolicy) | `networkPolicy.enabled: true`, plus the VPC range (set by `deploy.sh`) | Only pods in the namespace and the load balancer may connect |
| **Public address** | `ingress.enabled: true`, `port: 8016` | The app gets its own port on the shared platform ALB: `http://<platform-alb>:8016` |
| **Auto-rollback** | `--atomic` (set by `deploy.sh 3`) | A version that doesn't become healthy is rolled back automatically |
| **Locked-down container** (already on since 2B) | chart defaults: non-root user 1000, read-only file system, all Linux capabilities dropped | If someone breaks in, they can do very little |

In `qa` and `prod` the platform also encrypts Kubernetes Secrets with **KMS** (AWS's key service),
and in `prod` a deleted vault entry can be recovered for 7 days (Chapter 10's Terraform).

### Rotate a key, the production way

From `chapter-16-llm/cloud`, after creating a **new** key on your provider's website:

```bash
export ANTHROPIC_API_KEY='your-new-key'
bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev
kubectl -n zero2ai annotate externalsecret llm-api force-sync=$(date +%s) --overwrite
kubectl -n zero2ai rollout restart deploy/llm-api
bash test.sh 3
```

**What you should see:** `[OK] Stored keys in zero2ai/dev/llm-api-keys: ...`,
`externalsecret.external-secrets.io/llm-api annotated`,
`deployment.apps/llm-api restarted`, then `[OK] Phase 3 checks passed`. Now delete the **old**
key on the provider's website. No redeploy, no code change, nobody's laptop involved.

---

## How big companies run this

### 1. Security: secrets management

- **Implemented here:** keys live in a vault (Secrets Manager), are copied by External Secrets
  using a Pod Identity role that can read only this course's secrets, each pod gets only its
  provider's key, the image and git never contain a key, and the container runs non-root with a
  read-only file system behind a NetworkPolicy.
- **How you'd extend it at work:**
  - **Rotate on a schedule** (for example every 90 days) and **immediately** after any leak.
  - Turn on **secret scanning** in git (GitHub secret scanning, or tools like gitleaks) so a
    pasted key is caught before it's pushed.
  - Use **one key per app and per environment**, so a leak in `dev` can't spend `prod`'s money,
    and the provider's dashboard shows who spent what.
  - Alert on **who reads the vault** (AWS CloudTrail logs every read).

### 2. Cost (FinOps): tokens are money

LLM bills grow quietly, one token at a time. The **unit cost** is what you pay per request:

```text
cost per request = tokens_in  x (input price  per 1M tokens) / 1,000,000
                 + tokens_out x (output price per 1M tokens) / 1,000,000
```

Your API already returns `tokens_in` and `tokens_out`, and logs them with the ticket number, so you
can do this sum for any request. Multiply by requests per day and you have your daily bill.

- **Implemented here:** `max_tokens=512` caps the size (and cost) of each answer; token counts are
  logged for every request; one provider setting makes it easy to move to a cheaper model.
- **How you'd extend it at work:**
  - Set a **monthly budget and alerts** in each provider's billing console, and an AWS Budget for
    the cluster.
  - Put **rate limits** in front of the API (per user or per team), so one script in a loop
    can't burn the month's budget in an hour.
  - **Lock down the public address**: set `ingress.allowedCidrs` to your office range, put login
    in front (Amazon Cognito or an API gateway), or use `ingress.scheme: internal`.
  - Route easy questions to a **cheaper, smaller model** and only hard ones to the big model.
  - Turn token counts into **metrics** and a dashboard (cost per day, per team). Chapter 18 does
    this.

### 3. Reliability: LLM calls are slow and sometimes fail

A call to an LLM can take seconds, and providers sometimes rate-limit you (`429`) or have outages
(`5xx`).

- **Implemented here:** 2 to 4 copies, PDB, zone spreading, probes on `/health`, `--atomic`
  rollback. The provider SDKs' own defaults apply for timeouts and retries (the Anthropic and
  OpenAI SDKs retry a couple of times on rate limits and server errors).
- **How you'd extend it at work:**
  - Set an explicit **timeout** on each LLM call (for example 30 seconds), so a slow provider
    can't tie up every copy.
  - **Retry with backoff** (wait 1 s, then 2 s, then 4 s) on `429` and `5xx` only, never on a bad
    key.
  - Return a **friendly JSON error** (for example `503` with "please try again") instead of a
    bare `500 Internal Server Error`.
  - Add a **fallback provider**: if Anthropic is down, try Gemini. Your one-setting provider
    switch is the first step towards that.
  - Track **SLOs** such as "99% of `/chat` answers in under 10 seconds."

### 4. Audit and compliance: what do you log?

- **Implemented here:** each request logs a ticket number, the **first 60 characters of the
  question**, and the token counts. Answers are not logged.
- **Be careful:** customers type personal details (names, account numbers) into chat boxes. Those
  60 characters may contain **PII** (personally identifiable information) and end up in your
  logs.
- **How you'd extend it at work:**
  - Write a **logging policy**: what is logged (ticket number, tokens, model, time), what is
    **masked** (card numbers, emails), and how long logs are kept.
  - **Redact** PII before logging, and before sending prompts to the provider if your rules say
    so.
  - Check each provider's **data retention** terms (how long they keep your prompts) with your
    legal and security teams before sending customer data.
  - Keep an **audit trail** of who changed the system prompt and when (it's in git, so code
    review gives you this).

### 5. Safe change

The system prompt is part of your product. Changing one sentence changes every answer.
**Implemented here:** prompt changes go through git and a new image, and `--atomic` rolls back a
release that doesn't start. **At work:** keep a small **test set** of questions with expected
behaviour ("declines soup recipes", "answers in two paragraphs") and run it before every release,
then use Chapter 14's canary to send a small share of traffic to the new prompt first.

### 6. Runbook

This chapter has no alert rules (Chapter 18 adds error and cost alerts), so the runbook starts
from what users or `test.sh 3` report.

| Symptom | What it means | First 3 commands | How to fix |
|---|---|---|---|
| ExternalSecret `READY False`, status `SecretSyncedError` | External Secrets couldn't copy the key from the vault | `kubectl -n zero2ai describe externalsecret llm-api`<br>`aws secretsmanager describe-secret --secret-id zero2ai/dev/llm-api-keys`<br>`kubectl -n external-secrets logs deploy/external-secrets --tail=30` | Usually the key name isn't in the vault JSON. Export the key and rerun `put-llm-secret.sh dev`, then force-sync (see "Rotate a key") |
| Pods `CreateContainerConfigError` (`secret "llm-api-secrets" not found`) | The ExternalSecret hasn't made its Secret yet | `kubectl -n zero2ai get externalsecret llm-api`<br>`kubectl -n zero2ai get secret llm-api-secrets`<br>`kubectl -n zero2ai get pods` | Fix the ExternalSecret first (row above); the pods start by themselves once the Secret exists |
| `/chat` returns `500`, `/health` is fine | The app reached the provider and got an error | `kubectl -n zero2ai logs deploy/llm-api --tail=30`<br>`kubectl -n zero2ai get pods`<br>`helm history llm-api -n zero2ai` | `AuthenticationError` / `API key not valid`: rotate the key. `429`: wait, then add rate limits or more quota. `404 model`: update the model name in the code and release. Started after a release: `helm rollback llm-api -n zero2ai` |
| Public address times out | The load balancer can't reach healthy pods | `kubectl -n zero2ai get ingress llm-api`<br>`kubectl -n zero2ai get pods -o wide`<br>`kubectl -n zero2ai describe ingress llm-api` | New ALB: wait 2-4 minutes for DNS. Pods not `Running`: fix them first. See also PLATFORM.md's "If something breaks" |
| The bill jumps | Someone (or a script) is calling the public endpoint a lot | `kubectl -n zero2ai logs deploy/llm-api --tail=200 \| grep "tokens in/out"`<br>`kubectl -n zero2ai get hpa llm-api`<br>`kubectl -n zero2ai get ingress llm-api` | Run `bash down.sh` to stop spending now. Then rotate the key and lock the address down (`ingress.allowedCidrs` or `ingress.scheme: internal`) before deploying again |

---

## Production readiness checklist

Run each command from `chapter-16-llm/cloud` after `bash deploy.sh 3`.

- [ ] All tests pass: `bash test.sh 3` ends with `[OK] Phase 3 checks passed`
- [ ] The key comes from the vault: `kubectl -n zero2ai get externalsecret llm-api` shows `READY True`
- [ ] The old terminal-made Secret is gone: `kubectl -n zero2ai get secret llm-api-keys` says `NotFound`
- [ ] The pod holds only its provider's key: `kubectl -n zero2ai describe secret llm-api-secrets` lists exactly one key name
- [ ] No key in the release settings: `helm get values llm-api -n zero2ai` shows no key values
- [ ] No real key in git: `git grep -nE "sk-ant-[A-Za-z0-9_-]{20,}|sk-proj-[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{30,}"` (from the top of the repo) prints nothing
- [ ] At least 2 copies: `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=llm-api`
- [ ] Autoscaling is on (2 to 4): `kubectl -n zero2ai get hpa llm-api`
- [ ] A disruption budget exists: `kubectl -n zero2ai get pdb llm-api`
- [ ] Network rules exist: `kubectl -n zero2ai get networkpolicy llm-api`
- [ ] The container runs as non-root: `kubectl -n zero2ai get deploy llm-api -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'` prints `true`
- [ ] You know how to rotate the key, and you've done it once (see "Rotate a key")
- [ ] A budget alert is set in your provider's billing console (check it on their website)

## Career corner

**Roles that do this work:** AI Engineer, LLM Engineer, AI Platform Engineer, ML Platform
Engineer, Cloud Security Engineer, FinOps Engineer.

Practice questions you might hear in an interview:

1. Why should an API key never be in the code, the container image or git? Where should it live,
   and how does your app get it at run time?
2. Walk me through rotating a leaked LLM API key with zero downtime.
3. How would you estimate the monthly cost of a chat feature that gets 10,000 questions a day?
4. The LLM provider starts returning `429` errors. What do you do right now, and what do you
   change so it hurts less next time?
5. What would you log for each LLM request, and what would you make sure *not* to log?

## Clean up

From `chapter-16-llm/cloud`:

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 16 removed (...)`. This removes the public address, so it
can't spend money any more. The key stays in Secrets Manager for Chapters 17 and 18.

Done for the day? Destroy the platform. From `chapter-16-llm/cloud`:

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

**What you should see:** Terraform destroying everything, ending with
`[OK] Everything for dev is destroyed.` (In `dev`, the vault entry is deleted immediately too, so
you'll run `put-llm-secret.sh` again next time.)

## Where to next

[Chapter 17 — Give the robot your own notes to read (RAG)](../../chapter-17-rag/README.md). Your
front desk will look up answers in your own notes before asking the robot, using the same vault
for its key.
