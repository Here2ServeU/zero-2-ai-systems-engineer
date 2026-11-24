# Chapter 18 — Phase 3: Run it like a Fortune 500 company

> Phase 2 proved the service runs in the cloud. Phase 3 is the **finished LLMOps platform**:
> everything from Chapters 10 to 17 switched on at once. Several copies that grow with traffic,
> keys from a vault, a public address on the shared load balancer, and alerts on errors,
> latency and **spend**. Same Helm release, one more values file on top.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

- Finish Phase 2 ([README.md](README.md)), with the platform still running.
- Run every command from this folder: `cd chapter-18-prodllm/cloud`.
- **Put your key in the vault once.** Phase 3 does not read the key from your terminal. It
  reads it from **AWS Secrets Manager**, like a real company. From this folder, with
  `ANTHROPIC_API_KEY` exported:

```bash
bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev
```

**What you should see:** `[OK] Stored keys in zero2ai/dev/llm-api-keys: ANTHROPIC_API_KEY`.

> **Your service will have a public address.** Anyone who finds it can make it phone the
> robot on your bill. The per-user budget does not stop them, because callers choose their
> own `user_id`. Run the tests, look around, and **run `bash down.sh` when you're done**.

## Deploy and test Phase 3

```bash
bash deploy.sh 3
bash test.sh 3
```

**What you should see:**

- `deploy.sh 3` checks that `ANTHROPIC_API_KEY` is in Secrets Manager, runs
  `helm upgrade --install prod-llm ... --atomic`, prints the release history, and ends with
  `[OK] Phase 3 deployed. Test it: bash test.sh 3`.
- `test.sh 3` shows the ExternalSecret `prod-llm` (`STATUS SecretSynced`, `READY True`), prints
  `[OK] helm test prod-llm`, waits for the platform load balancer, prints
  `Public: http://k8s-zero2ai-....elb.amazonaws.com:8018`, runs the feature checks (health, a
  real question, the same question again, the safety filter `[OK] Blocked (HTTP 422)`), lists
  the production safety nets (HPA, PDB, NetworkPolicy, ServiceMonitor, PrometheusRule), and
  ends with `[OK] Phase 3 checks passed`.

With 2 or more copies behind the load balancer, the repeated question may say
`"cached":false`: it reached a different copy, which has its own memory box. That's expected
here; see "Honest limits" below.

## What changes in production, and why

Everything below is in [`phase3-production/values.yaml`](phase3-production/values.yaml),
added on top of [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml), and in the `3)` step of
[`deploy.sh`](deploy.sh).

| Setting | What it does | Why production needs it | From chapter |
|---|---|---|---|
| `externalSecret` (`keys: ["ANTHROPIC_API_KEY"]`) + `envFromSecrets: []` | The External Secrets Operator copies the key from AWS Secrets Manager (`zero2ai/<env>/llm-api-keys`) into a Kubernetes Secret, and refreshes it every hour | One safe place for keys; you rotate a key in the vault, not on laptops | 16 |
| key check in `deploy.sh 3` | Stops with `[ERROR] ANTHROPIC_API_KEY is not in Secrets Manager yet` if the vault is empty | Fails early with a clear message, instead of pods that can't start | 16 |
| `resources` | Each copy asks for 100m CPU and 192Mi memory, and may use at most 384Mi | Safe packing; one copy can't starve a server | 10 |
| `autoscaling` | HPA: 2 to 6 copies, aiming for 70% CPU | Busy hours get more copies; quiet hours cost less | 10 |
| `pdb.enabled` | PodDisruptionBudget: at least 1 copy stays up | Server upgrades never take every copy down | 10 |
| `topologySpread.enabled` | Spreads copies across availability zones and servers | One data center going dark doesn't take the service down | 10 |
| `networkPolicy.enabled` (+ VPC range from `deploy.sh`) | Only the load balancer and this namespace may reach port 5000; only Prometheus (the `monitoring` namespace) may reach port 8000 | If something else in the cluster is broken into, it can't reach your service | 10 |
| `ingress` on port `8018` | Joins the shared **platform ALB** with a health check on `/health` | One stable public address, no extra load balancer to pay for | 10 |
| `serviceMonitor` (from 2B) | Prometheus collects `/metrics` every 15 seconds | The alerts below need these numbers | 11, 15 |
| `prometheusRule` | Five alerts made for an LLM service (table below) | You hear about failures and big bills before users or the finance team do | 11 |
| `--atomic` (in `deploy.sh 3`) | If the upgrade fails, Helm rolls back by itself | No half-broken releases | 14 |
| chart `securityContext` | Runs as user 1000 (not root), read-only disk, no extra Linux powers | Hardening required by most company clusters | 10 |

### The five alerts

| Alert | Fires when | What it protects |
|---|---|---|
| `LLMErrorRateHigh` (critical) | More than 5% of calls fail for 5 minutes | Users getting errors |
| `LLMLatencyHigh` (warning) | The slowest 5% of robot calls (p95) take over 15 seconds, for 10 minutes | Users waiting too long |
| `LLMTokenSpendHigh` (warning) | More than 500,000 tokens in one hour | **Your bill** (the cost alarm) |
| `LLMBudgetRejectionsSpiking` (info) | More than 50 budget rejections in 15 minutes | Heavy users, or someone abusing one `user_id` |
| `LLMSafetyFilterBlocks` (info) | More than 20 blocked messages in 15 minutes | Possible abuse or a leaking upstream system |

See them in the cluster:

```bash
kubectl -n zero2ai get prometheusrule prod-llm -o yaml | grep 'alert:'
```

**What you should see:** five lines, `- alert: LLMErrorRateHigh` through
`- alert: LLMSafetyFilterBlocks`. In the Prometheus web page (address from
`bash ../../chapter-10-kubernetes/scripts/urls.sh`), the **Alerts** tab lists them as
*inactive* (green) while all is well.

### Watch the alert numbers move

Send ten blocked messages through the public address, then look at the metric the
`LLMSafetyFilterBlocks` alert reads. Run from this folder:

```bash
host=$(kubectl -n zero2ai get ingress prod-llm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in $(seq 1 10); do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST "http://$host:8018/llm" \
    -H 'Content-Type: application/json' -d '{"user_id":"tester","prompt":"password: hunter2"}'
done
```

**What you should see:** `422` ten times. These cost nothing: blocked messages never reach the
robot. About 30 seconds later, the Prometheus query
`sum(increase(llm_calls_total{service="prod-llm", status="blocked"}[15m]))` shows about 10.
Send 15 more and the alert turns *firing*.

### Roll back with one command

```bash
helm history prod-llm -n zero2ai                        # find the Phase 2B revision number
helm rollback prod-llm <phase-2b-revision> -n zero2ai
```

### Honest limits of this chapter's code

These are real gaps. Knowing them is part of the job.

- **`CACHE` and `USER_BUDGETS` live in each copy's memory.** With 2 or more copies, each copy
  has its own cache and its own budgets, and a restart empties both. The real fix is a shared
  store such as **Redis** (Amazon ElastiCache) that every copy reads and writes.
- **The budget trusts the caller.** `user_id` comes from the request, so anyone can pick a new
  one. Real platforms take the user from a login token instead.
- **The public endpoint has no login and no HTTPS.** Put authentication in front (for example
  Amazon Cognito or an API gateway), or keep it private with `ingress.scheme: internal`, and add
  HTTPS with `ingress.certificateArn` (both are settings in the shared chart).
- **The safety filter is a simple word list.** `"my ssn is 123-45-6789"` (no colon) gets
  through.
- **Flask's built-in server, one process per copy**, because the metrics server runs inside
  the app process (see Chapter 11). The HPA adds copies instead.
- **Alerts only show in Prometheus.** To page a human, configure Alertmanager receivers (Slack,
  email, PagerDuty) in `chapter-10-kubernetes/terraform/eks-addons`.

---

## How big companies run this

Large companies add habits on top of the settings above. Each one is labeled **built in**
(this chapter really does it) or **how you'd extend it at work**.

### 1. Promise a level of service: SLIs and SLOs

- An **SLI** (service level indicator) is a number that shows whether users are happy. This
  service already measures the raw data for three of them (**built in**):
  - *Success rate*: `llm_calls_total` by `status` (success and cache_hit vs error).
  - *Latency*: the `llm_latency_seconds` histogram.
  - *Cost per answer*: `llm_tokens_total` divided by successful calls.
- An **SLO** (service level objective) is the promise, like "99.5% of questions answered
  without error each month, and 95% of robot calls under 15 seconds". The two alerts
  `LLMErrorRateHigh` and `LLMLatencyHigh` are a first version of that promise (**built in**).
- The **error budget** is the 0.5% you may fail. When it's used up, the team pauses new
  features and fixes reliability first (**how you'd extend it at work**: an SLO dashboard in
  Grafana, Chapter 15).
- For LLMs, companies add an **answer quality** SLI: a sample of answers is scored every day
  by people or by a second "judge" model (**how you'd extend it at work**).

### 2. Write a runbook for every alert (how you'd extend it at work)

A **runbook** is a recipe anyone on call can follow at 3 a.m. Here are three for this service.

| | `LLMErrorRateHigh` |
|---|---|
| **What it means** | More than 5% of questions get `{"error":"LLM call failed"}` (HTTP 503) |
| **First 3 commands** | `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=prod-llm` · `kubectl -n zero2ai logs deployment/prod-llm --tail=50 \| grep Failed` · `kubectl -n zero2ai get externalsecret prod-llm` |
| **How to fix** | `AuthenticationError`/401 → the key was revoked or rotated: put the new one in the vault (`put-llm-secret.sh dev`) and restart: `kubectl -n zero2ai rollout restart deployment/prod-llm`. `RateLimitError`/429 → you hit the provider's limit: ask for a higher limit, or lower traffic. 5xx or connection errors → check the provider's status page; it's on their side. Started right after a release → `helm rollback prod-llm <previous> -n zero2ai`. |

| | `LLMTokenSpendHigh` |
|---|---|
| **What it means** | More than 500,000 tokens in an hour: the bill is climbing fast |
| **First 3 commands** | `kubectl -n zero2ai logs deployment/prod-llm --tail=200 \| grep Success` (who and how big) · `kubectl -n zero2ai get hpa prod-llm` (is traffic way up?) · Prometheus: `sum by (status) (increase(llm_calls_total{service="prod-llm"}[1h]))` (are cache hits low?) |
| **How to fix** | Real growth → raise the budget on purpose, after checking with the budget owner. Abuse from the public address → take it offline (`bash down.sh`) or restrict who can reach it. One heavy user → lower `DAILY_TOKEN_LIMIT` and redeploy. |

| | `LLMLatencyHigh` |
|---|---|
| **What it means** | The slowest robot calls take over 15 seconds |
| **First 3 commands** | Prometheus: `histogram_quantile(0.95, sum by (le) (rate(llm_latency_seconds_bucket{service="prod-llm"}[10m])))` · `kubectl -n zero2ai top pods` · `kubectl -n zero2ai logs deployment/prod-llm --tail=50` |
| **How to fix** | Usually the provider is slow: check its status page. Retries add waiting time (2 to 30 seconds per retry), so many retries in the logs point to provider errors. A smaller, faster model or a lower `max_tokens` cuts latency too (test it first, see section 5). |

### 3. Security in layers

- **Built in:** keys live in AWS Secrets Manager and reach pods through External Secrets, never
  in git or the image. Containers run as a normal user with a read-only disk. A NetworkPolicy
  limits who can connect. The safety filter blocks obvious private data before it leaves.
- **Key rotation (how you'd extend it at work):** make a new key in the provider console, put
  it in the vault with `put-llm-secret.sh`, wait for the hourly refresh (or run
  `kubectl -n zero2ai rollout restart deployment/prod-llm`), then delete the old key.
  Companies do this on a schedule, and immediately if a key may have leaked.
- **Prompt injection (how you'd extend it at work):** users can write text that tries to trick
  the robot ("ignore your rules and..."). Companies keep instructions in a system prompt, never
  give the robot powers it doesn't need, and check its output before acting on it.
- **PII (personal data) protection (how you'd extend it at work):** replace the word list with
  pattern matching (for example, any `123-45-6789` shape) or a managed PII detection service,
  and don't log full prompts.
- **Authentication and HTTPS (how you'd extend it at work):** see "Honest limits".

### 4. Reliability

- **Built in:** 2 to 6 copies across zones, a disruption budget, health checks on the load
  balancer, retry with backoff (3 tries) for short provider hiccups, and `max_tokens=512` so no
  single answer runs forever.
- **How you'd extend it at work:** a **provider fallback** (if Anthropic fails, try OpenAI or
  Gemini, using the Chapter 16 code), an explicit **timeout** on each robot call, and a
  **circuit breaker** that stops calling a provider that keeps failing.

### 5. Safe change

- **Built in:** every release is a numbered Helm revision, `--atomic` undoes a failed upgrade,
  and `helm rollback` takes you back in one command.
- **How you'd extend it at work:** treat a new **prompt or model** like new code. Before
  release, run a fixed set of test questions (an **evaluation set**) through the old and new
  versions, compare answers, cost and speed, and release only if the new one is at least as
  good. Then roll it out slowly with a canary (Chapter 14).

### 6. Cost control (FinOps)

- **Built in:** the cache (a repeated question costs zero tokens), per-user daily budgets,
  `max_tokens` capping each answer, the `llm_tokens_total` cost meter and the
  `LLMTokenSpendHigh` alarm, and an autoscaler that removes copies when it's quiet.
- **How you'd extend it at work:** a shared Redis cache so every copy benefits, a monthly
  **spending limit** set in the provider's console as a hard stop, cheaper models for easy
  questions, the provider's own **prompt caching** for long repeated instructions, and a weekly
  report of tokens per team or per feature. Your biggest saving in this course: **tear the
  platform down when you're not using it.**

### 7. Audit and compliance (partly built in)

- **Built in:** every request gets a `request_id` that appears in the answer and in the log,
  so a complaint can be traced to the exact log lines.
- **How you'd extend it at work:** ship logs to a central store with a retention period (EKS
  control-plane logs are already on in qa and prod, see PLATFORM.md), record which model and
  prompt version produced each answer, and keep the evaluation results from section 5 as
  evidence for auditors.

## Production readiness checklist

Tick each box by running the command next to it (from `chapter-18-prodllm/cloud`).

- [ ] The key comes from the vault: `kubectl -n zero2ai get externalsecret prod-llm` shows `SecretSynced`
- [ ] At least 2 copies are Ready: `kubectl -n zero2ai get deploy prod-llm`
- [ ] The autoscaler exists and shows a CPU number: `kubectl -n zero2ai get hpa prod-llm`
- [ ] A disruption budget protects it: `kubectl -n zero2ai get pdb prod-llm`
- [ ] Network access is limited: `kubectl -n zero2ai get networkpolicy prod-llm`
- [ ] Prometheus scrapes it: `kubectl -n zero2ai get servicemonitor prod-llm`
- [ ] The five alerts exist: `kubectl -n zero2ai get prometheusrule prod-llm -o yaml | grep -c 'alert:'` prints `5`
- [ ] It runs as a normal user: `kubectl -n zero2ai exec deploy/prod-llm -- id` shows `uid=1000`
- [ ] The safety filter works through the public address: `bash test.sh 3` shows `[OK] Blocked (HTTP 422)`
- [ ] You can roll back: `helm history prod-llm -n zero2ai` shows more than one revision
- [ ] You know how to turn it all off: `bash down.sh` and `bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev`

## Career corner

What you just built is the daily work of **LLMOps Engineers**, **AI Platform Engineers**,
**AI Engineers** and **ML Engineers**. You can now answer interview questions like:

1. Your LLM bill doubled last week. How would you find out why, and what three things would
   you put in place so it can't happen again?
2. Why does a cache that lives in each pod's memory stop working well when you scale to
   several pods? What would you use instead?
3. How do you keep an LLM API key safe from a developer's laptop all the way to production,
   and how do you rotate it without downtime?
4. The provider starts returning errors for 5% of calls. Walk me through your alert, your first
   commands, and your options.
5. How would you check that a new prompt or model is safe to release?

## If something breaks

- **`[ERROR] ANTHROPIC_API_KEY is not in Secrets Manager yet`** → Run
  `bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev` with the key exported, then
  `bash deploy.sh 3` again.
- **ExternalSecret shows `SecretSyncedError`** → `kubectl -n zero2ai describe externalsecret prod-llm`
  shows why. Usually the vault secret is empty or the platform's External Secrets add-on isn't
  running: `kubectl -n external-secrets get pods`.
- **`Error: UPGRADE FAILED` and the release rolled back** → `--atomic` did its job. See why with
  `kubectl -n zero2ai get events --sort-by=.lastTimestamp | tail -20`, fix it, deploy again.
- **The address on :8018 doesn't answer yet** → New ALB rules take a couple of minutes.
  `bash test.sh 3` waits; run it again if it times out.
- **HPA shows `<unknown>/70%`** → The metrics service needs about a minute after pods start.
- **The real question fails but health and the safety filter pass** → The robot call failed.
  Check `kubectl -n zero2ai logs deployment/prod-llm --tail=30` and use the `LLMErrorRateHigh`
  runbook above.

## Clean up

```bash
bash down.sh                                                   # remove this chapter's app and its Secret
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # delete the whole platform: you've finished the course
```

**What you should see:** `[OK] Chapter 18 removed. ...`, then later the platform destroy
finishing without errors. After `platform-down.sh`, nothing from this course costs money.
(In dev, destroying the platform also deletes the vault copy of your key straight away. If
you won't use the key again, delete it in the provider console too.)

## Where to next

You've built the whole platform. See "Where to next" in [../README.md](../README.md) for ideas
to extend it (join Chapter 17's RAG to these guardrails, share the cache with Redis, add a
fallback provider) and how to show it in your portfolio. Or go back to the
[course index](../../README.md) and run any chapter again in `qa` or `prod` with `ENV=prod`:
the code doesn't change, only the values.
