# NexaGuard — FinTech AI Fraud Detection Platform

**Book:** Capstone 1 (Signature Projects). Wires all eight layers together for a fictional
bank, *First National Digital*. Real-time transaction scoring (XGBoost, sub-50ms),
streaming, MLflow registry, EKS/Kubernetes, CI/CD quality gates, Prometheus + Grafana,
an AIOps engine, canary/blue-green deploys, an LLM fraud-summary endpoint, and a RAG
pipeline over PCI-DSS docs.

> This is a **capstone scaffold**: each milestone reuses the scripts and patterns you
> already built in the `chapter-XX-*` labs. Build it in the order below.

## Eight-layer structure

| Folder | Layer | Built with skills from |
|---|---|---|
| `data/` | Feature engineering over `fintech_transactions.csv` | chapter-03-models |
| `models/` | XGBoost fraud classifier + Isolation Forest, MLflow registry | chapter-03, chapter-04 |
| `api/` | Flask `/score`, `/health`, `/info`, `/explain` (Prometheus) | chapter-05, chapter-11 |
| `streaming/` | Kafka consumer, feature enrichment, batch scorer | chapter-06, chapter-10 |
| `docker/` | Multi-stage Dockerfile, compose, non-root user | chapter-06 |
| `terraform/` | EKS, VPC, S3 model bucket, IAM roles | chapter-07, chapter-08 |
| `kubernetes/` | Deployment, autoscaler, canary rollout | chapter-10, chapter-14 |
| `observability/` | Prometheus rules, Grafana dashboards, AIOps engine | chapter-11, chapter-12, chapter-15 |
| `llm/` | Claude wrapper: cache, budget, retry, safety, metrics | chapter-16, chapter-18 |
| `rag/` | ChromaDB over PCI-DSS docs, `/qa` with citations | chapter-17 |

## The ten milestones

1. **Data pipeline** — velocity, geo-distance, device, merchant-risk features → 42 columns.
2. **Model training** — XGBoost; 3 MLflow runs; register `nexaguard-fraud-classifier v1`
   (AUC-ROC > 0.97, false-positive rate < 0.5%).
3. **Scoring API** — `/score` returns `fraud_score`, decision (APPROVE/REVIEW/BLOCK),
   top-5 SHAP contributions, `request_id`; Prometheus counters + latency histogram (p95 < 50ms).
4. **Streaming layer** — Kafka consumer enriches + scores; KEDA-scaled pod (e2e < 80ms @ 1k msg/s).
5. **Container & cloud** — Docker image → ECR; EKS via Terraform; reachable at LoadBalancer IP.
6. **CI/CD with quality gates** — lint, test, build, push, sync; reject recall < 95% or FP > 0.5%.
7. **Observability & AIOps** — 6-panel Grafana dashboard; auto-scale on TPS/latency thresholds.
8. **Safe deployment** — canary 5/20/50/100 with SLO analysis; weekly KS drift → auto-retrain; blue/green.
9. **LLM fraud summary** — `/explain` turns SHAP values into a plain-English analyst summary
   (cache, per-analyst budget, retry, safety filter, token metrics).
10. **RAG compliance** — ChromaDB over PCI-DSS §6/§8/§10 + runbooks; `/qa` with citations.

## Deliverables

Public GitHub repo + README + architecture diagram; `/score` APPROVE/REVIEW/BLOCK
screenshots; MLflow 3-run comparison with registered model; live Grafana dashboard;
Terraform-deployed EKS; CI/CD quality-gate run; `/explain` and `/qa` responses; a
500-word written reflection.
