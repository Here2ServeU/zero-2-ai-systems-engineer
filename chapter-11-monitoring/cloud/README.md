# Chapter 11 — Cloud track: metrics collected by Prometheus on EKS

> On your laptop you visited `/metrics` yourself. In the cloud, **Prometheus** (already running
> on the cluster from `eks-addons`) collects every copy's numbers, all the time.
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

## New words

- **ServiceMonitor** — A small wish-file that tells Prometheus "collect from the copies behind
  this Service, on the `metrics` port." It replaces `scrape_configs` in `prometheus.yml`.
- **PrometheusRule** — Alert rules: "if this number looks bad for N minutes, raise an alert."
- **Target** — One copy Prometheus collects from. `up = 1` means it answered.

## Step 0 — Build and push

This chapter now has a `Dockerfile` (packing `app_with_metrics.py` the Chapter 06 way).

```bash
cd chapter-11-monitoring/cloud
bash deploy.sh build
```

## Phase 1 — Same app, same checks, plus a ServiceMonitor

[`phase1/`](phase1) holds a Deployment (two doors per copy: `5000` app, `8000` metrics), a
Service, and a **ServiceMonitor**.

```bash
bash deploy.sh 1
bash test.sh 1
```

`test.sh 1` does what you did on your laptop — calls `/predict` a few times and reads
`/metrics` through port-forward — then asks the cluster's Prometheus whether it sees the app:
`up{service="metrics-api-p1"}`.

## Phase 2 — Helm

[`phase2/values.yaml`](phase2/values.yaml) sets `metricsPort: 8000` and
`serviceMonitor.enabled: true`; the chart adds the metrics port and the ServiceMonitor for you.

```bash
bash deploy.sh 2
bash test.sh 2
```

See it in Prometheus yourself:

```bash
bash ../../chapter-10-kubernetes/scripts/urls.sh     # Prometheus is on the platform ALB at :9090 (your IP only)
# or, without the ALB:
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# http://<platform-alb>:9090 or http://localhost:9090 -> Status > Targets:
#   look for serviceMonitor/zero2ai/metrics-api.  Graph: rate(api_requests_total[1m])
```

## Phase 3 — Production monitoring

[`phase3/values.yaml`](phase3/values.yaml) adds **alerts**, and the same safety nets as Chapter 10:

| Alert | Fires when |
|---|---|
| `MetricsApiDown` | No copy has answered Prometheus for 2 minutes |
| `MetricsApiCopyMissing` | Fewer than 2 healthy copies for 5 minutes |
| `MetricsApiSlowPredictions` | 95% of predictions take longer than 0.5 s, for 5 minutes |

Plus HPA, PDB, zone spreading, a NetworkPolicy (Prometheus may still reach port 8000 from the
`monitoring` namespace), and a public ALB.

```bash
bash deploy.sh 3
bash test.sh 3
```

Make an alert fire on purpose: `kubectl -n zero2ai scale deployment metrics-api --replicas=0`
(the HPA will fight back — that's the point; to really test, `kubectl -n zero2ai delete hpa
metrics-api` first). Watch Prometheus → **Alerts**. Then `bash deploy.sh 3` to restore.

> **Why one process per copy?** `start_http_server(8000)` runs inside the app. Several gunicorn
> workers would each try to open port 8000. That's fine: we scale with more *copies* instead.

## If something breaks

- **`Prometheus has no 'up' series`** → Wait a minute (scrapes every 15 s), then check Status >
  Targets. If the target is missing, the ServiceMonitor's labels don't match the Service:
  `kubectl -n zero2ai get servicemonitor,svc --show-labels`.
- **Target shows `DOWN` / `connection refused`** → The NetworkPolicy blocks it if the
  `monitoring` namespace label is missing: `kubectl get ns monitoring --show-labels`.

## Clean up / next

`bash down.sh` · Next: [Chapter 12's cloud track](../../chapter-12-aiops/cloud/README.md) — a
robot guard that reads these numbers and acts.
