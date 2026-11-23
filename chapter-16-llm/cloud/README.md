# Chapter 16 — Cloud track: the chat API on EKS, keys handled properly

> Same chat API, now on EKS. The real lesson is **where the API key lives**: your shell
> (Phase 1–2), then **AWS Secrets Manager** with automatic syncing (Phase 3).
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

> ### ⚠️ Money & secrets
> Every question costs a little. Keys are **never** put in images, values files, or git.
> Pick **one** provider with `LLM_PROVIDER=anthropic|openai|gemini` (default `anthropic`);
> Gemini has a free tier.

## New words

- **Kubernetes Secret** — Kubernetes' locked drawer for small secrets; pods read it as
  environment variables.
- **AWS Secrets Manager** — AWS's vault. Terraform made an empty one: `zero2ai/<env>/llm-api-keys`.
- **External Secrets Operator** — Copies values from the vault into a Kubernetes Secret, and
  re-copies every hour, so rotating a key needs no redeploy.

```bash
cd chapter-16-llm/cloud
bash deploy.sh build                       # one image with all three providers' code
export ANTHROPIC_API_KEY=sk-ant-...        # or OPENAI_API_KEY / GEMINI_API_KEY (and LLM_PROVIDER)
```

The apps now have a `GET /health` route so Kubernetes can check each copy.

## Phase 1 — Key from your shell into a Kubernetes Secret

`deploy.sh 1` runs `kubectl create secret generic llm-api-keys --from-literal=...` from your
environment variables (never a file), then applies [`phase1/`](phase1).

```bash
bash deploy.sh 1
bash test.sh 1         # /health, then one real question
```

## Phase 2 — Helm

[`phase2/values.yaml`](phase2/values.yaml) uses `envFromSecrets: ["llm-api-keys"]`.

```bash
LLM_PROVIDER=gemini bash deploy.sh 2    # example: switch provider with one setting
bash test.sh 2
```

## Phase 3 — Keys from AWS Secrets Manager

```bash
bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh dev   # copies your exported key(s) into the vault
bash deploy.sh 3
bash test.sh 3         # shows ExternalSecret Ready=True, then asks through the public ALB
```

[`phase3/values.yaml`](phase3/values.yaml) turns on `externalSecret`: the chart creates a
**SecretStore** (where: Secrets Manager) and an **ExternalSecret** (what: which keys). The
External Secrets controller reads the vault with its own Pod Identity role, which can read
**only** `zero2ai/<env>/*`. Your shell's copy (`llm-api-keys`) is deleted.

Rotate a key the production way: update it with `put-llm-secret.sh`, then
`kubectl -n zero2ai annotate externalsecret llm-api force-sync=$(date +%s) --overwrite` and
`kubectl -n zero2ai rollout restart deploy/llm-api`.

> **A public chat endpoint spends your money.** Before sharing the ALB address, put
> authentication in front of it, or set `ingress.scheme: internal`.

## If something breaks

- **Pod `CreateContainerConfigError: secret "llm-api-keys" not found`** → Export a key and rerun
  `deploy.sh 1` or `2`.
- **ExternalSecret `SecretSyncedError`** → The key name isn't in the vault JSON. Check with
  `aws secretsmanager get-secret-value --secret-id zero2ai/dev/llm-api-keys --query SecretString`
  (careful: that prints the key) and rerun `put-llm-secret.sh`.
- **`503` / provider error in logs** → Wrong key, no credit, or wrong `LLM_PROVIDER`.

## Clean up / next

`bash down.sh` · Next: [Chapter 17's cloud track](../../chapter-17-rag/cloud/README.md).
