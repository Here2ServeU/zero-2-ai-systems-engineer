# Chapter 13 — Phase 2: Promote it to the cloud (AWS EKS)

> In Phase 1 you ran the drift check and retraining on your laptop, then packed them in a
> container whose MLflow notebook vanished when the box stopped. Now you move the **same
> container** to a real cloud cluster, in two small steps: **2A** runs it once as a Kubernetes
> Job, then **2B** adds a shared **MLflow server** and runs retraining **every Monday** with
> Helm. Phase 3 ([PRODUCTION.md](PRODUCTION.md)) hardens it for production.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

1. **Finish Phase 1** ([../README.md](../README.md)). Everything here builds on it.
2. **Build the shared cloud platform once:**
   [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md). Its
   Terraform also creates two things this chapter needs: an S3 bucket for model files, and AWS
   permissions for the `mlflow` and `retrain` service accounts (used in Phase 3).
3. **Costs money.** The platform costs roughly **$0.10/hour** plus servers. This chapter adds no
   load balancer, so it adds almost nothing on top. Get permission if the AWS account isn't
   yours, and **tear everything down when you finish** (see "Clean up" at the bottom).

**Run every command on this page from this folder:**

```bash
cd chapter-13-retraining/cloud
```

## What changes from your laptop to the cloud

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| `docker build` on your laptop | Image pushed to **ECR**, your private image shelf in AWS | Cloud servers can't see your laptop |
| You type `docker run` | A Kubernetes **Job** runs the box once (2A), then a **CronJob** runs it every Monday at 02:00 UTC (2B) | Nobody has to remember to retrain |
| MLflow notebook in a local `mlruns` folder, gone with the box | One shared **MLflow tracking server** that every run writes to (2B) | The history and the model registry survive between runs |
| `echo $?` shows `1` for a rejected model | The Job is marked **Failed**, and is never retried (`backoffLimit: 0`) | A weak model fails loudly instead of trying again until it sneaks through |
| No size limits | Each pod says how much CPU and memory it needs (**resources**) | So the cloud can pick a server with room |
| Plain YAML (2A) | A **Helm chart** with values (2B) | One command installs, upgrades and rolls back |

## New words

- **Job** — A Kubernetes task that runs to the end once, like `docker run --rm`.
- **CronJob** — A Job on a timetable. `"0 2 * * 1"` means "minute 0, hour 2, any day of the
  month, any month, day 1 of the week (Monday)".
- **MLflow tracking server** — Your Phase 1 MLflow notebook, as a shared website that every run
  writes to.
- **Model registry** — MLflow's shelf of *approved* models (`FraudDetectionModel` v1, v2, ...).
- **Release** — One installed copy of a Helm chart. Here there are two: `mlflow` and `retrain`.
- **port-forward** — A private tunnel from your laptop to something inside the cluster.

## Step 0 — Build the images and push them to ECR

```bash
bash deploy.sh build
```

This builds **two** images for `linux/amd64` (the kind of computer EKS uses, even on a newer Mac)
and pushes them to ECR:

- `retrain` — your Phase 1 container ([`../Dockerfile`](../Dockerfile)): drift check + retraining.
- `mlflow` — an MLflow 2.22.0 server that can also store files in S3
  ([`../mlflow-server/Dockerfile`](../mlflow-server/Dockerfile)).

**What you should see:** two lines like `[OK] Pushed ...zero2ai-dev/retrain:3f9c2ab` and
`[OK] Pushed ...zero2ai-dev/mlflow:3f9c2ab` (the last part is your git commit).

---

## Phase 2A — The laptop routine, once, as a Job

[`phase2a-yaml/job.yaml`](phase2a-yaml/job.yaml) is a plain Kubernetes Job: run the box once,
never retry (`backoffLimit: 0`), and tidy the Job away an hour after it finishes.

```bash
bash deploy.sh 2a
bash test.sh 2a
```

**What you should see:** `deploy.sh 2a` ends with
`[OK] Phase 2A job started. See its report: bash test.sh 2a`. `test.sh 2a` waits for the Job to
finish (about a minute), then prints its log, which looks just like your laptop:

```
{'drift_detected': np.True_, 'ks_statistic': np.float64(0.61), 'p_value': np.float64(0.0), 'interpretation': 'DRIFT DETECTED: retrain required'}
...
Created version '1' of model 'FraudDetectionModel'.
PROMOTED: recall=1.000
[OK] Phase 2A checks passed
```

Explore it yourself:

```bash
kubectl -n zero2ai get jobs                 # retrain-demo   Complete   1/1
kubectl -n zero2ai get pods                 # the pod that ran it: STATUS Completed
kubectl -n zero2ai logs job/retrain-demo    # the same log again
```

**The problem 2A leaves:** the run was recorded in the pod's own `/tmp/mlruns`, which vanished
with the pod, exactly like `docker run --rm` on your laptop. Run it again and it says version 1
again. Phase 2B fixes that.

---

## Phase 2B — A shared MLflow server and a weekly CronJob, with Helm

Two Helm releases from the **same shared chart** (Chapter 10's
[`zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app)), each with its own values file:

| Release | Values file | What it runs |
|---|---|---|
| `mlflow` | [`phase2b-helm/mlflow-values.yaml`](phase2b-helm/mlflow-values.yaml) | The MLflow tracking server (a Deployment + a Service called `mlflow`). Runs and model files live on the pod's scratch disk for now |
| `retrain` | [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml) | A CronJob, Mondays 02:00 UTC (the same timetable as [`../retrain.yml`](../retrain.yml)), with `MLFLOW_TRACKING_URI=http://mlflow` so every run writes to the shared server. No Deployment, no Service: it only runs on schedule |

```bash
bash deploy.sh 2b
bash test.sh 2b
```

`deploy.sh 2b` removes the 2A Job, installs `mlflow`, waits for it to be healthy, then installs
`retrain`. `test.sh 2b` does three things:

1. `helm test mlflow`: a tiny pod calls MLflow's `/health` from inside the cluster.
2. Starts a retraining run **right now** (`kubectl create job --from=cronjob/retrain`), instead of
   waiting for Monday, and prints its log.
3. Opens a port-forward to MLflow and asks it which models are registered.

**What you should see:** `deploy.sh 2b` ends with `[OK] Phase 2B deployed. Test it: bash test.sh 2b`.
`test.sh 2b` ends like this:

```
PROMOTED: recall=1.000
GET http://localhost:5050/health
OK
Registered models in MLflow:
"name": "FraudDetectionModel"
"version": "1"
See it yourself: kubectl -n zero2ai port-forward svc/mlflow 5050:80   ->  http://localhost:5050
[OK] Phase 2B checks passed
```

Run `bash test.sh 2b` a second time and the version becomes `"2"` (MLflow lists the latest version). The history now survives
between runs, because it lives in the server, not in the job's box.

### Open the MLflow website

```bash
kubectl -n zero2ai port-forward svc/mlflow 5050:80
```

**What you should see:** `Forwarding from 127.0.0.1:5050 -> 5000`. Open **http://localhost:5050**
in your browser: the same MLflow website as Phase 1 Step 7, but now it's the cloud's notebook.
Press **Ctrl+C** in the terminal to close the tunnel.

### Useful commands to explore

```bash
helm list -n zero2ai                              # mlflow and retrain, with their revision numbers
kubectl -n zero2ai get cronjob retrain            # SCHEDULE 0 2 * * 1, and when it LAST ran
kubectl -n zero2ai get jobs                       # every run: retrain-now-... from test.sh, retrain-... from the schedule
kubectl -n zero2ai get pods -l app.kubernetes.io/instance=mlflow
kubectl -n zero2ai logs deployment/mlflow --tail=20
helm get values retrain -n zero2ai                # the settings Helm used
helm history mlflow -n zero2ai                    # every change, ready to roll back
```

### Try it yourself

- **Change the timetable.** Make it run every 15 minutes, watch, then put it back:

  ```bash
  helm upgrade retrain ../../chapter-10-kubernetes/helm/zero2ai-app -n zero2ai --reuse-values --set cronJob.schedule="*/15 * * * *"
  kubectl -n zero2ai get cronjob retrain
  helm rollback retrain -n zero2ai
  ```

  **What you should see:** `SCHEDULE */15 * * * *` after the upgrade, and `Rollback was a
  success!` at the end.

---

## If something breaks

- **`[ERROR] Cluster zero2ai-eks-dev not found`** → The shared platform isn't built (or was torn
  down). Run `bash ../../chapter-10-kubernetes/scripts/platform-up.sh dev` first.
- **`[ERROR] No image recorded for 'retrain'`** (or `'mlflow'`) → Run `bash deploy.sh build`
  first.
- **Pod shows `ImagePullBackOff`** → The image isn't in ECR for this environment. Run
  `bash deploy.sh build` again, then the `deploy.sh` step you were on.
- **`REJECTED: recall=...` and the Job fails** → That's the safety gate working. The old model is
  untouched. Read `RECALL_THRESHOLD` and `max_depth` in `../retrain_pipeline.py`. Note that
  `test.sh` waits up to 10 minutes for a Job that will never complete before showing the log;
  check sooner in another terminal with `kubectl -n zero2ai get jobs`.
- **`test.sh 2a` says `[ERROR] Job failed` but the log is empty or `job not found`** → The 2A Job
  tidies itself away one hour after it finishes. Run `bash deploy.sh 2a` again, then
  `bash test.sh 2a`.
- **The retraining log says `Connection refused` or `Max retries exceeded ... mlflow`** → The
  MLflow server isn't ready. Check `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=mlflow`
  and wait for `1/1 Running`, then run `bash test.sh 2b` again.
- **`port-forward` says `address already in use`** → Something on your laptop already uses door
  5050 (maybe the Phase 1 `mlflow ui`). Stop it with Ctrl+C, or use another door:
  `kubectl -n zero2ai port-forward svc/mlflow 5051:80`.
- **The registered version went back to `"1"`** → The MLflow pod restarted. In Phase 2B its
  notebook lives on the pod's scratch disk, so a restart forgets it. Phase 3 moves the model
  files to S3.

## Clean up

```bash
bash down.sh                                                 # remove this chapter's releases and jobs
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # when you're done for the day
```

**What you should see:** `[OK] Chapter 13 removed (S3 model files stay until platform-down.sh)`.
`platform-down.sh` deletes the whole platform, including the S3 bucket and every model file in it.

## Next: Phase 3

Your retraining runs by itself and its history survives between runs. Now make it production
grade: model files in S3 with no keys, automatic rollback and alerts when a model is rejected.
Go to **[PRODUCTION.md](PRODUCTION.md)**.
