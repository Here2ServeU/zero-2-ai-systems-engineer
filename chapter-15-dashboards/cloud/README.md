# Chapter 15 — Cloud track: dashboards as code on EKS

> On your laptop, docker-compose started the app, Prometheus and Grafana together, and you
> built the dashboard by clicking. On EKS, Prometheus and Grafana already run for the whole
> cluster; your app ships **its own dashboard as code** in its Helm release.
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

## New words

- **Dashboard as code** — The dashboard saved as a JSON file in git
  ([`dashboard.json`](dashboard.json)), so it's reviewed, versioned, and recreated automatically.
- **Grafana sidecar** — A helper next to Grafana that loads any ConfigMap labelled
  `grafana_dashboard: "1"`.

```bash
cd chapter-15-dashboards/cloud
bash deploy.sh build        # uses this chapter's existing Dockerfile
```

## Phase 1 — The app + a ServiceMonitor

The ServiceMonitor replaces `prometheus.yml`'s `scrape_configs`.

```bash
bash deploy.sh 1
bash test.sh 1              # sends traffic from inside the cluster, checks Prometheus has the numbers
```

## Phase 2 — Helm, with the dashboard included

`deploy.sh 2` runs `helm upgrade --install ... --set-file grafanaDashboard.json=dashboard.json`.
The chart turns it into a labelled ConfigMap; Grafana loads it within seconds.

```bash
bash deploy.sh 2
bash test.sh 2              # ... and checks Grafana has the "Zero2AI Fraud API" dashboard
bash load.sh 300            # 5 minutes of traffic to watch
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  user: admin
# password: terraform -chdir=../../chapter-08-cloud/terraform/eks-addons output -raw grafana_admin_password
```

Panels: predictions/second (fraud vs legit), latency p50/p95, fraud share, requests in progress,
healthy copies, CPU per copy.

## Phase 3 — Alerts

| Alert | Fires when |
|---|---|
| `FraudShareHigh` | More than 20% of payments flagged for 10 minutes (attack — or drift, Chapter 13) |
| `ModelLatencyHigh` | p95 model latency above 50 ms for 5 minutes |
| `MonitoredApiDown` | No copy reachable for 2 minutes |

Plus HPA, PDB, zone spreading, NetworkPolicy and an ALB, like every Phase 3.

```bash
bash deploy.sh 3
bash test.sh 3
```

> Grafana stays private (port-forward). Putting it on the internet needs single sign-on first;
> that's a good stretch goal.

## Clean up / next

`bash down.sh` · Next: [Chapter 16's cloud track](../../chapter-16-llm/cloud/README.md).
