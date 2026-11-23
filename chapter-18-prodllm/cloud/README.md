# Chapter 18 — Cloud track: the production LLM service, fully fledged

> Everything from Chapters 10–17 at once: Helm, autoscaling, disruption budgets, zone
> spreading, network policy, a public ALB, secrets from the vault, Prometheus metrics, and
> **alerts on errors, latency, and spend**.
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

```bash
cd chapter-18-prodllm/cloud
export ANTHROPIC_API_KEY=sk-ant-...
bash deploy.sh build
```

## Phase 1 — Same service, on EKS

```bash
bash deploy.sh 1
bash test.sh 1
```

`test.sh` checks each grown-up feature you built: a real answer, the **cache** (second identical
question says `"cached": true`), the **safety filter** (`"my ssn: ..."` → `422`), and the
`llm_calls_total` / `llm_tokens_total` metrics.

## Phase 2 — Helm + Prometheus scraping

```bash
bash deploy.sh 2
bash test.sh 2
```

## Phase 3 — Production

```bash
bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev
bash deploy.sh 3
bash test.sh 3
```

| Piece | From chapter |
|---|---|
| Helm release, `--atomic` upgrades, rollback | 10, 14 |
| HPA 2–6 copies, PDB, zone spread, NetworkPolicy, ALB | 10 |
| ServiceMonitor | 11, 15 |
| Keys from Secrets Manager via External Secrets | 16 |

Alerts ([`phase3/values.yaml`](phase3/values.yaml)):

| Alert | Fires when |
|---|---|
| `LLMErrorRateHigh` | > 5% of calls fail for 5 minutes |
| `LLMLatencyHigh` | p95 latency > 15 s for 10 minutes |
| `LLMTokenSpendHigh` | > 500k tokens in an hour (your **cost** alarm) |
| `LLMBudgetRejectionsSpiking` | many users hitting the daily budget |
| `LLMSafetyFilterBlocks` | 20+ blocked messages in 15 minutes (possible abuse) |

> **Honest limits, and the real fixes**
> - `CACHE` and `USER_BUDGETS` live in each copy's memory; with 2+ copies each has its own.
>   Fix: a shared Redis (Amazon ElastiCache).
> - The endpoint is public with no login. Fix: authentication in front (Amazon Cognito / API
>   Gateway) or `ingress.scheme: internal`, plus HTTPS with `ingress.certificateArn`.
> - Fire alerts somewhere humans see them: configure Alertmanager receivers (Slack, email,
>   PagerDuty) in `eks-addons`.

## You finished the cloud track

```bash
bash down.sh
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev     # stop paying
```

Repeat any chapter in `qa` or `prod` with `ENV=prod`; the code doesn't change, only the values.
