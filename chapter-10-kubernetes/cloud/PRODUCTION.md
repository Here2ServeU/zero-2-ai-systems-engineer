# Chapter 10 — Phase 3: Run it like a Fortune 500 company

> Phase 2 proved the app runs in the cloud. Phase 3 makes it **survive real life**: busy hours,
> server upgrades, a broken data center, a bad release, and attackers. Same Helm release, one
> more values file on top.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

- Finish Phase 2 ([README.md](README.md)), with the platform still running.
- Run every command from this folder: `cd chapter-10-kubernetes/cloud`.

## Deploy and test Phase 3

```bash
bash deploy.sh 3
bash test.sh 3
```

**What you should see:** `deploy.sh 3` ends with `[OK] Phase 3 deployed`. `test.sh 3` runs
`helm test`, then calls `/health`, `/info` and `/predict` through the **shared platform load
balancer on port 8010** (`http://k8s-zero2ai-....elb.amazonaws.com:8010`), then lists the
autoscaler (HPA), disruption budget (PDB) and NetworkPolicy, and ends with
`[OK] Phase 3 checks passed`. Open the same address in your browser (add `/health`), or run
`bash ../scripts/urls.sh` to list every address.

## What changes in production, and why

Everything below is in [`phase3-production/values.yaml`](phase3-production/values.yaml) (plus
[`values-prod.yaml`](phase3-production/values-prod.yaml) when `ENV=prod`) and the `3)` step of
[`deploy.sh`](deploy.sh).

| Setting | What it does | Why production needs it |
|---|---|---|
| `command: gunicorn ...` | A real web server: 2 processes x 4 threads per copy | Flask's built-in server is for practice only |
| `resources` | Each copy asks for 250m CPU and 384Mi memory, and may never use more than 768Mi | The cloud can place copies safely; one copy can't eat a whole server |
| `autoscaling` (HPA) | 2 to 6 copies, aiming for 70% CPU (3 to 10 in prod) | Handles busy hours without paying for idle copies |
| `pdb.minAvailable: 1` | PodDisruptionBudget (2 in prod) | Server upgrades never take every copy down at once |
| `topologySpread` | Spread copies across zones and servers | One data center going dark doesn't take the app down |
| `networkPolicy` | Only the load balancer and this namespace may connect | Limits the damage if something else is broken into |
| chart `securityContext` | Runs as a normal user (not root), read-only disk, no extra Linux powers | Hardening; passes the Kubernetes "restricted" security level |
| `ingress` on port 8010 | Joins the shared **platform ALB**, with health checks; HTTPS once you add a certificate | One stable public address, no extra load balancer to pay for |
| `--atomic` (in deploy.sh) | If the upgrade fails, Helm rolls back by itself | No half-broken releases |
| prod ECR repo, immutable tags | A tag can never be overwritten in prod | The image you tested is exactly the image that runs |

### Watch autoscaling work

In a second terminal: `kubectl -n zero2ai get hpa fraud-api -w`. Then make some traffic:

```bash
kubectl -n zero2ai run load --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s -o /dev/null -X POST http://fraud-api/predict \
  -H "Content-Type: application/json" \
  -d "{\"amount\":950,\"hour\":3,\"is_weekend\":0,\"amount_vs_avg\":2.8,\"is_large_txn\":1,\"is_late_night\":1,\"merch_txn_ct\":4}"; done'
```

**What you should see:** the HPA's CPU number climbs past 70% and `REPLICAS` grows. Press
Ctrl+C to stop; about 5 minutes later the extra copies are removed.

### Roll back with one command

```bash
helm history fraud-api -n zero2ai                      # find the Phase 2B revision number
helm rollback fraud-api <phase-2b-revision> -n zero2ai
```

That's the point of Helm: a bad change is one command away from undone.

---

## How big companies run this

Large companies add a few habits on top of the settings above. Some are built into this
chapter; the rest are how you'd extend it at work.

### 1. Promise a level of service: SLIs and SLOs (how you'd extend it at work)

- An **SLI** (service level indicator) is a number that shows if users are happy, like "the
  percentage of `/predict` calls that answer in under 300 ms".
- An **SLO** (service level objective) is the promise, like "99.9% of calls succeed each month".
- The **error budget** is the 0.1% you're allowed to fail. When it's used up, the team stops
  shipping new features and fixes reliability first.

You start measuring these in Chapter 11 (metrics) and Chapter 15 (dashboards).

### 2. Write a runbook for every alert (how you'd extend it at work)

A **runbook** is a recipe that anyone on call can follow at 3 a.m. Here is one for this app:

| | |
|---|---|
| **Alert** | `fraud-api` health check failing on the load balancer |
| **What it means** | Visitors may be getting errors |
| **First 3 commands** | `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=fraud-api` · `kubectl -n zero2ai describe pod <pod>` · `kubectl -n zero2ai logs deployment/fraud-api --tail=50` |
| **Fix** | Crashing after a release → `helm rollback fraud-api <previous> -n zero2ai`. Not enough copies → check the HPA (`kubectl -n zero2ai get hpa`). Image missing → `bash deploy.sh build`. |

### 3. Security in layers (built in)

Non-root containers, read-only disks, no extra Linux powers, a NetworkPolicy, and AWS access
through Pod Identity instead of stored keys. At work you'd also scan every image for known
security holes before release, and turn on HTTPS with a certificate.

### 4. Reliability (built in)

Two or more copies, spread across zones, an autoscaler, a disruption budget, and health checks
on the load balancer. Together they mean no single failure takes the app offline.

### 5. Safe change (built in)

Every release is a numbered Helm revision, `--atomic` undoes failed upgrades on its own, and
prod images can't be overwritten. Chapter 14 goes further with blue/green and canary releases.

### 6. Cost control, or "FinOps" (partly built in)

Resource requests let the cluster pack copies tightly; the autoscaler removes copies when it's
quiet; one shared load balancer serves every chapter. At work, teams also tag every resource
(this platform tags them with `Project`, `Environment` and `Owner`) and review the bill weekly.
**Your biggest saving: tear the platform down when you're not using it.**

## Production readiness checklist

Tick each box by running the command next to it.

- [ ] At least 2 copies are Ready: `kubectl -n zero2ai get deploy fraud-api`
- [ ] The autoscaler exists and shows a CPU number: `kubectl -n zero2ai get hpa fraud-api`
- [ ] A disruption budget protects the app: `kubectl -n zero2ai get pdb`
- [ ] Copies sit in different zones: `kubectl -n zero2ai get pods -o wide` (compare the NODE column with `kubectl get nodes -L topology.kubernetes.io/zone`)
- [ ] Network access is limited: `kubectl -n zero2ai get networkpolicy`
- [ ] The app answers through the public load balancer: `bash test.sh 3`
- [ ] You can roll back: `helm history fraud-api -n zero2ai` shows more than one revision
- [ ] You know how to turn it all off: `bash ../scripts/platform-down.sh dev`

## Career corner

What you just built is what **Platform Engineers**, **DevOps Engineers** and **Site Reliability
Engineers** do every day. You can now answer interview questions like:

1. What's the difference between a Deployment, a Pod and a Service?
2. Why do you set resource requests and limits on a container?
3. How does a PodDisruptionBudget protect an app during a node upgrade?
4. What happens when a Helm upgrade fails with `--atomic`, and how do you roll back by hand?
5. Why should a container not run as root?

## The same thing in qa and prod

```bash
bash ../scripts/platform-up.sh prod     # once (costs more: see ../PLATFORM.md)
ENV=prod bash deploy.sh build
ENV=prod bash deploy.sh 3
ENV=prod bash test.sh 3
```

Same chart, same values, plus `values-prod.yaml` (3 to 10 copies, `minAvailable: 2`).

## If something breaks

- **`Error: UPGRADE FAILED` and the release rolled back** → `--atomic` did its job. See why with
  `kubectl -n zero2ai get events --sort-by=.lastTimestamp | tail -20`, fix it, deploy again.
- **HPA shows `<unknown>/70%`** → The metrics service needs about 1 minute after pods start.
  `kubectl top pods -n zero2ai` should show numbers first.
- **The ALB address on :8010 doesn't answer yet** → New ALB rules take a couple of minutes.
  `bash test.sh 3` waits for it; run it again if it times out.
- **Pods `CreateContainerConfigError: container has runAsNonRoot and image has non-numeric
  user`** → You're using an old image. Run `bash deploy.sh build` and `bash deploy.sh 3` again.

## Clean up

```bash
bash down.sh                                # remove this chapter's app
bash ../scripts/platform-down.sh dev        # when you're done for the day
```

## Where to next

[Chapter 11 — Watch your program's health](../../chapter-11-monitoring/README.md). You'll add an
**observability platform** on top of this one: every copy reports its own numbers, and the
cluster's Prometheus collects them.
