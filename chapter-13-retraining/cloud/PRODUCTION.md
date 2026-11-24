# Chapter 13 — Phase 3: Run it like a Fortune 500 company

> Phase 2 proved retraining runs by itself in the cloud. Phase 3 makes it **trustworthy**: model
> files that survive restarts, AWS access with no keys anywhere, upgrades that undo themselves if
> they fail, and an alarm that wakes a human when a new model fails its quiz. Same two Helm
> releases, one more values file on top of each.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

- Finish Phase 2 ([README.md](README.md)), with the platform still running.
- Run every command from this folder: `cd chapter-13-retraining/cloud`.

## Deploy and test Phase 3

```bash
bash deploy.sh 3
bash test.sh 3
```

**What you should see:** `deploy.sh 3` first prints the bucket it will use, like
`==> MLflow artifacts bucket: s3://zero2ai-eks-dev-mlflow-123456789012`, upgrades `mlflow` and
`retrain`, and ends with `[OK] Phase 3 deployed. Test it: bash test.sh 3`.

`test.sh 3` does everything `test.sh 2b` did (helm test, a retraining run right now, the list of
registered models), then lists the newest model files **in S3** (your dates, sizes and run IDs
will differ), and ends with `[OK] Phase 3 checks passed`:

```
==> Model files in S3 (s3://zero2ai-eks-dev-mlflow-123456789012/artifacts)
2026-11-24 10:15:02        125 artifacts/1/4f0c.../artifacts/model/python_env.yaml
2026-11-24 10:15:02      58641 artifacts/1/4f0c.../artifacts/model/model.pkl
2026-11-24 10:15:02        234 artifacts/1/4f0c.../artifacts/model/requirements.txt
...
[OK] Phase 3 checks passed
```

> The upgrade restarts the MLflow pod, so the version count starts again at `"1"`. That's the
> honest limit described below: the *list* of runs still lives on the pod's disk. The model
> *files* are now safe in S3.

## What changes in production, and why

Everything below is in [`phase3-production/mlflow-values.yaml`](phase3-production/mlflow-values.yaml),
[`phase3-production/values.yaml`](phase3-production/values.yaml), and the `3)` step of
[`deploy.sh`](deploy.sh). Both are layered on top of the Phase 2B files.

| Setting | What it does | Why production needs it |
|---|---|---|
| `--artifacts-destination s3://zero2ai-eks-<env>-mlflow-<account>/artifacts` | MLflow saves every model file in the S3 bucket Chapter 10's Terraform made. `deploy.sh` fills in the real bucket name | Model files survive pod restarts and node failures. The bucket is encrypted and blocks all public access |
| **EKS Pod Identity** for the `mlflow` service account | AWS gives the MLflow pod short-lived permissions, because its service account is exactly `mlflow` in namespace `zero2ai` | No AWS keys in the image, in Git or in Kubernetes. Nothing to leak, nothing to rotate |
| Least-privilege S3 policy (in Chapter 10's Terraform) | The pod may only list, read, write and delete objects **in this one bucket** | If MLflow were broken into, the damage stops at this bucket |
| `--serve-artifacts` (kept from 2B) | Retraining jobs upload files **through** MLflow, not straight to S3 | Only one program needs S3 access, so only one program can misuse it |
| `env.AWS_DEFAULT_REGION` (`--set` in `deploy.sh`) | Tells MLflow's S3 helper which AWS region the bucket is in | Without it, S3 calls fail or go to the wrong region |
| `--atomic` on both releases | If an upgrade doesn't become healthy, Helm rolls back by itself | A bad change never leaves MLflow half-broken |
| `successfulJobsHistoryLimit: 5`, `failedJobsHistoryLimit: 5` | Keeps the last 5 good and 5 failed runs (the chart default is 3) | More evidence to look at when something goes wrong |
| Alert `RetrainingRejectedModel` (warning, after 1 minute) | Fires when any `retrain-...` Job has failed: the model was rejected or the run crashed | The quality gate should never fail silently; a human decides what to do |
| Alert `MlflowDown` (critical, after 5 minutes) | Fires when the MLflow Deployment has no healthy copy | No runs can be recorded and no models registered while it's down |
| Kept from 2B: `backoffLimit: 0` and the chart's `concurrencyPolicy: Forbid` | A failed run is never retried, and two runs never overlap | A weak model can't sneak through on a lucky retry; two runs can't race to register |
| Kept from 2B: the chart's security settings | Non-root user 1000, read-only root disk, all extra Linux powers dropped, no Kubernetes API token in the pod | Hardening; passes the Kubernetes "restricted" security level |
| Kept from 2B: no public address | MLflow is only a `ClusterIP` Service; you reach it with `port-forward` | MLflow has no login, so it must not be on the internet |

**Honest limits** (not built here, and why it matters):

- **The run list is in SQLite on the pod's disk.** Restart the pod and MLflow forgets the
  experiments and the registry (the S3 files stay). Real teams point `--backend-store-uri` at a
  managed database such as **Amazon RDS for PostgreSQL**, then run 2 or more MLflow copies.
- **One MLflow copy.** No autoscaling, disruption budget or zone spreading for MLflow yet.
- **Retraining runs every Monday, drift or not.** `drift_detector.py` always exits `0`, so the
  `&&` only stops retraining if the drift check *crashes*. At work, the drift check would exit
  non-zero (or write a flag) to skip retraining when nothing changed.
- **Registering is not releasing.** A new version on the registry shelf doesn't change what any
  app serves. Moving a model into live traffic safely is Chapter 14.
- **The `retrain` service account also has S3 permissions** from Terraform, but with
  `--serve-artifacts` it never uses them. Least privilege at work would remove them.

## How big companies run this

Big companies add a few habits on top of the settings above. Each one is labeled **built in**
(this chapter really does it) or **how you'd extend it at work**.

### 1. Promise a level of service: SLIs and SLOs (how you'd extend it at work)

- An **SLI** (service level indicator) is a number that shows if things are healthy. For a
  continuous-training platform, good SLIs are: **model freshness** (how many days since the last
  approved version), **retraining success rate** (the share of weekly runs that finish), and
  **model quality** (recall on the hidden test set).
- An **SLO** (service level objective) is the promise, for example "an approved model is never
  more than 8 days old" and "recall never drops below 0.70".
- The **error budget** is how much you may miss, for example "at most 2 missed weekly runs per
  quarter". When it's used up, the team stops adding features and fixes the pipeline first.

You already have the raw numbers: Kubernetes reports every Job's result to Prometheus (that's
what the alert reads), and MLflow records every run's recall.

### 2. Alerts and a runbook (built in: the alerts. At work: write the runbook down)

See the alerts on the platform's Prometheus: run
`bash ../../chapter-10-kubernetes/scripts/urls.sh`, open the `prometheus` address and click
**Alerts**. A **runbook** is a recipe anyone on call can follow at 3 a.m.:

| | `RetrainingRejectedModel` |
|---|---|
| **What it means** | A retraining run failed. Either the quality gate said `REJECTED` (recall below 0.70), or the run crashed. Nothing new was registered; the last approved version is still the latest on the shelf |
| **First 3 commands** | `kubectl -n zero2ai get jobs` (find the one with `Failed` / `0/1`) · `kubectl -n zero2ai logs job/<name>` · `kubectl -n zero2ai describe job <name>` |
| **How to fix** | Log says `REJECTED` → the gate worked. Look at what changed in the data before doing anything. Don't lower `RECALL_THRESHOLD` just to make it pass. Log shows `Connection refused ... mlflow` → follow the `MlflowDown` runbook. `describe` shows `OOMKilled` → raise `resources.limits.memory` in `phase2b-helm/values.yaml` and run `bash deploy.sh 3`. When fixed, run it again with `kubectl -n zero2ai create job retrain-manual-1 --from=cronjob/retrain`. The alert clears when the failed Job is removed (`kubectl -n zero2ai delete job <name>`) or tidied away after a day |

| | `MlflowDown` |
|---|---|
| **What it means** | MLflow has no healthy copy. Runs can't be recorded and models can't be registered |
| **First 3 commands** | `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=mlflow` · `kubectl -n zero2ai describe pod <pod>` · `kubectl -n zero2ai logs deployment/mlflow --tail=50` |
| **How to fix** | Logs mention `AccessDenied` or `NoCredentialsError` → check Pod Identity: `aws eks list-pod-identity-associations --cluster-name zero2ai-eks-dev --namespace zero2ai` must list `mlflow`. Broke after an upgrade → `helm history mlflow -n zero2ai`, then `helm rollback mlflow <good-revision> -n zero2ai`. `ImagePullBackOff` → `bash deploy.sh build`, then `bash deploy.sh 3` |

### 3. Security in layers (built in)

No AWS keys anywhere (Pod Identity), S3 access limited to one encrypted, private bucket, only
MLflow talks to S3, MLflow has no public address, and every container runs as a normal user with
a read-only disk and no extra powers. At work you'd also: turn on MLflow's login, add a
NetworkPolicy so only the retraining pods may reach MLflow, remove the unused `retrain` S3
permissions, and scan both images for known security holes before release.

### 4. Reliability (partly built in)

Built in: health checks on MLflow (`/health`), `helm test`, no overlapping runs, no blind
retries, and `--atomic` upgrades. At work: MLflow on RDS PostgreSQL with 2+ copies across zones,
a disruption budget, and S3 versioning so a deleted model file can be brought back.

### 5. Safe change (built in)

Two gates protect you. The **quality gate** in `retrain_pipeline.py` stops a weak *model*, and
`--atomic` plus `helm rollback` stop a bad *setting*. Every change is a numbered Helm revision
(`helm history retrain -n zero2ai`). The next step, releasing a new model to only a few users
first (canary), is Chapter 14.

### 6. Cost control, or "FinOps" (partly built in)

The retraining pod only exists for about a minute a week, there's no load balancer, and S3
storage for small models costs pennies. At work you'd add an **S3 lifecycle rule** that deletes
files of rejected or very old runs, and you'd tag spending by team. **Your biggest saving: tear
the platform down when you're not using it.**

### 7. Audit and compliance: model lineage (partly built in)

Banks and insurers must be able to answer: *"Which model made this decision, how was it trained,
and who approved it?"* That chain of answers is called **lineage**.

- **Built in:** every registry version points back to the MLflow run that made it, with its
  `recall` and `f1` scores, the time it ran, and the exact model file in S3. Rejected runs are
  recorded too, so you can show what was tried and why it was refused.
- **How you'd extend it at work:** also record the training data's version (for example a hash
  of the file), the code version (the image tag, which is your git commit), the drift result, and
  who approved the release, plus a short **model card** (what the model is for, and its limits).

## Production readiness checklist

Tick each box by running the command next to it, from `chapter-13-retraining/cloud`.

- [ ] MLflow has a healthy copy: `kubectl -n zero2ai get deploy mlflow` shows `READY 1/1`
- [ ] MLflow saves model files in S3: `helm get values mlflow -n zero2ai` shows `s3://zero2ai-eks-dev-mlflow-...`
- [ ] Model files really are in S3: `bash test.sh 3` ends with a list of `artifacts/...` files
- [ ] Permissions come from Pod Identity, not keys: `aws eks list-pod-identity-associations --cluster-name zero2ai-eks-dev --namespace zero2ai` lists `mlflow` and `retrain`
- [ ] Retraining is on a timetable: `kubectl -n zero2ai get cronjob retrain` shows `0 2 * * 1`
- [ ] Runs never overlap and never retry: `kubectl -n zero2ai get cronjob retrain -o jsonpath='{.spec.concurrencyPolicy} {.spec.jobTemplate.spec.backoffLimit}{"\n"}'` prints `Forbid 0`
- [ ] The alerts are loaded: `kubectl -n zero2ai get prometheusrule` lists `retrain`
- [ ] Pods run as a normal user: `kubectl -n zero2ai get deploy mlflow -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}{"\n"}'` prints `true`
- [ ] MLflow is not on the internet: `kubectl -n zero2ai get svc mlflow` shows `TYPE ClusterIP`
- [ ] You can roll back: `helm history mlflow -n zero2ai` shows more than one revision
- [ ] You know how to turn it all off: `bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev`

## Career corner

What you just built is what **MLOps Engineers**, **ML Platform Engineers** and **Machine
Learning Engineers** do every day. You can now answer interview questions like:

1. What is data drift, and how would you detect it automatically?
2. Why should a retraining pipeline have a quality gate, and what should happen when a new model
   fails it?
3. What's the difference between experiment tracking and a model registry?
4. How can a pod read and write S3 without any AWS keys stored anywhere?
5. Why is SQLite on a pod's disk not good enough for a production MLflow, and what would you
   use instead?

## If something breaks

- **`deploy.sh 3` fails with `UPGRADE FAILED` and the release rolled back** → `--atomic` did
  its job. See why: `kubectl -n zero2ai get events --sort-by=.lastTimestamp | tail -20`, fix
  it, and run `bash deploy.sh 3` again.
- **MLflow logs show `AccessDenied` for S3** → Check the Pod Identity association:
  `aws eks list-pod-identity-associations --cluster-name zero2ai-eks-dev --namespace zero2ai`.
  The service account must be exactly `mlflow` in namespace `zero2ai`. If it's missing, rerun
  `bash ../../chapter-10-kubernetes/scripts/platform-up.sh dev`.
- **`aws s3 ls` says `NoSuchBucket`** → The platform was built for a different `ENV` or account.
  Use the same `ENV` (for example `ENV=dev`) for `platform-up.sh`, `deploy.sh` and `test.sh`.
- **The S3 list in `test.sh 3` is empty** → The retraining run didn't log a model (look for
  `PROMOTED` or `REJECTED` in its log above), or MLflow wasn't restarted with the S3 setting.
  Check with `helm get values mlflow -n zero2ai`.
- **The `RetrainingRejectedModel` alert stays on after you fixed things** → It looks at failed
  Jobs that still exist. Delete the old failed one: `kubectl -n zero2ai get jobs`, then
  `kubectl -n zero2ai delete job <name>`.

## Clean up

```bash
bash down.sh                                                 # remove this chapter's releases and jobs
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # when you're done for the day
```

**What you should see:** `[OK] Chapter 13 removed (S3 model files stay until platform-down.sh)`.
`platform-down.sh` then deletes everything, including the bucket and its model files.

## Where to next

[Chapter 14 — Release changes without scary surprises](../../chapter-14-deployment/README.md).
You'll build a **progressive delivery platform**: blue/green switches, canary releases through
the load balancer, and instant rollback. A freshly approved model from this chapter is exactly
the kind of change you'd release that way.
