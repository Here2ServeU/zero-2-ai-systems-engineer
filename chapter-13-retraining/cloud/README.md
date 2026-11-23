# Chapter 13 — Cloud track: scheduled retraining with MLflow on EKS

> On your laptop, `retrain_pipeline.py` wrote its notebook to a local `mlruns` folder. On EKS,
> retraining runs on a **schedule**, records every run in an **MLflow server**, and (Phase 3)
> keeps model files in **S3**, with permissions given to the pod — no AWS keys anywhere.
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

## New words

- **MLflow tracking server** — The Chapter 04 notebook, as a shared website every job writes to.
- **Model registry** — MLflow's shelf of *approved* models (`FraudDetectionModel` v1, v2, ...).
- **EKS Pod Identity** — AWS permissions for a pod, tied to its service account. Terraform
  created two: `mlflow` and `retrain` may read/write *only* the course's MLflow bucket.

## Step 0 — Build and push two images

```bash
cd chapter-13-retraining/cloud
bash deploy.sh build     # retrain (drift + retrain) and mlflow (server with S3 support)
```

## Phase 1 — The laptop routine, once, as a Job

```bash
bash deploy.sh 1
bash test.sh 1           # drift result, then PROMOTED: recall=0.xxx
```

The run is recorded inside the pod's own `/tmp/mlruns` and disappears with it. That's the
problem Phase 2 solves.

## Phase 2 — MLflow server + weekly CronJob

Two Helm releases from the same chart:

- `mlflow` ([`phase2/mlflow-values.yaml`](phase2/mlflow-values.yaml)) — the tracking server.
- `retrain` ([`phase2/values.yaml`](phase2/values.yaml)) — a CronJob, Mondays 02:00 UTC (like
  this chapter's GitHub Actions workflow), with `MLFLOW_TRACKING_URI=http://mlflow`.
  `backoffLimit: 0`: a rejected model fails the run loudly instead of retrying.

```bash
bash deploy.sh 2
bash test.sh 2           # runs retraining now, then lists registered models in MLflow
kubectl -n zero2ai port-forward svc/mlflow 5000:80    # http://localhost:5000
```

## Phase 3 — Model files in S3, alerts on rejected models

- MLflow stores artifacts in `s3://zero2ai-eks-<env>-mlflow-<account>/artifacts`
  (`--serve-artifacts`: jobs upload *through* MLflow, so only MLflow needs S3 access).
- Alerts: `RetrainingRejectedModel` (a run failed or recall < 0.70 — the old model keeps
  serving, a human should look) and `MlflowDown`.

```bash
bash deploy.sh 3
bash test.sh 3           # ... and lists the model files in S3
```

> **Honest limit:** MLflow's run list is in SQLite on the pod's disk, so it resets if the pod
> restarts (the S3 model files survive). Real teams point `--backend-store-uri` at a managed
> database such as Amazon RDS for PostgreSQL. Try it as a stretch goal.

## If something breaks

- **`REJECTED: recall=...` and the job fails** → That's the safety gate working. Read
  `retrain_pipeline.py`'s `RECALL_THRESHOLD`.
- **Phase 3 MLflow logs `AccessDenied` for S3** → Check the Pod Identity association:
  `aws eks list-pod-identity-associations --cluster-name zero2ai-eks-dev`. The service account
  must be exactly `mlflow` in namespace `zero2ai`.

## Clean up / next

`bash down.sh` · Next: [Chapter 14's cloud track](../../chapter-14-deployment/cloud/README.md).
