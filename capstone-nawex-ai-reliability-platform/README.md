# Capstone — Nawex AI Reliability Platform

> The capstone project of *Zero 2 AI Systems Engineer*. Wires all eight layers of the book into one runnable platform.

## What You Are Building

A production-style AI platform that integrates every technique covered in the book:

- Classical ML models (fraud detection, healthcare anomaly detection)
- Model serving via a single Flask process
- Container packaging with Docker
- Cloud infrastructure on AWS, defined in Terraform
- CI/CD via GitHub Actions
- Orchestration on Kubernetes with Helm
- Observability with Prometheus and Grafana
- AIOps for predictive failure detection
- Automated retraining when drift is detected
- Safe deployment with canary, blue-green, and feature flags
- LLM-powered customer service backed by Anthropic Claude
- Retrieval-augmented generation grounded in a private knowledge base via ChromaDB

## The 15 Milestones

| # | Milestone | Built in |
|---|---|---|
| 1 | Repository, environment, and architecture diagram | Week 1 |
| 2 | Compliance and regulated-environment notes for FinTech & Healthcare | Week 2 |
| 3 | Fraud and anomaly models trained and tracked in MLflow | Week 3 |
| 4 | Models exposed behind a Flask API with `/predict` and `/health` | Week 4 |
| 5 | Service containerized with Docker | Week 5 |
| 6 | AWS infrastructure provisioned via Terraform | Weeks 6, 7 |
| 7 | CI pipeline (lint, test, build, push image) | Week 8 |
| 8 | Kubernetes deployment with Helm chart | Week 9 |
| 9 | Prometheus + Grafana observability stack | Week 10 |
| 10 | AIOps anomaly detection on platform telemetry | Week 11 |
| 11 | Automated retraining triggered by drift signal | Week 12 |
| 12 | Canary + blue-green deploy with model promotion | Week 13 |
| 13 | Production dashboards covering API, model, infra, ops | Week 14 |
| 14 | LLM customer-service feature with Claude | Week 15 |
| 15 | RAG pipeline grounded in private knowledge base | Weeks 16, 17 |

## Layout

```
capstone-nawex-ai-reliability-platform/
  data/
    transactions.csv          # Fraud detection seed data
    vitals.csv                # Healthcare anomaly seed data
    drift_sample.csv          # Shifted slice used by drift_check.py
    eval_set.json             # Question / must-contain pairs for the LLM eval
    knowledge_base/*.md       # Source documents for the RAG pipeline
  src/
    paths.py                  # Filesystem paths used across all scripts
    train_models.py           # Layer 2 — trains fraud + anomaly, logs to MLflow
    ingest_kb.py              # Layer 8 — embeds knowledge base into ChromaDB
    serve.py                  # Layers 2-3-6-8 — single Flask app, all endpoints
    drift_check.py            # Layer 7 — exits non-zero when drift is detected
    promote_model.py          # Layer 7 — staging -> canary -> production registry
    aiops_anomaly.py          # Layer 6 — anomaly detection on platform telemetry
    eval.py                   # Layer 8 — RAG eval harness, gates CI
    demo.sh                   # End-to-end demo runbook
  Dockerfile                  # Layer 3 — packages the whole platform
  .dockerignore
  .gitignore                  # Excludes artifacts/, chroma/, mlruns/
  README.md                   # This file
```

## Prerequisites

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r ../requirements.txt
export ANTHROPIC_API_KEY=...   # for /chat, /chat-rag, eval.py
```

## Running the Platform

The fastest path is the demo runbook:

```bash
./src/demo.sh
```

Or step by step:

```bash
# Layer 2 — train models
python src/train_models.py

# Layer 8 — ingest the knowledge base
python src/ingest_kb.py

# Layer 7 — drift check (expect exit code 1 on the shifted sample)
python src/drift_check.py

# Layer 7 — promote a model version
python src/promote_model.py --model fraud --stage canary --version v1

# Layer 6 — AIOps on synthetic platform telemetry
python src/aiops_anomaly.py

# Layers 2 + 3 + 6 + 8 — start the platform
python src/serve.py
```

Once `serve.py` is running, exercise the endpoints:

```bash
# Health check
curl http://localhost:8080/health

# Prometheus scrape target
curl http://localhost:8080/metrics

# Fraud prediction
curl -X POST http://localhost:8080/predict/fraud \
  -H 'Content-Type: application/json' \
  -d '{"amount": 1820.0, "hour": 2, "merchant_risk": 0.95, "country_risk": 0.85}'

# Healthcare anomaly
curl -X POST http://localhost:8080/predict/anomaly \
  -H 'Content-Type: application/json' \
  -d '{"heart_rate": 130, "systolic_bp": 165, "oxygen_sat": 89, "temperature": 38.9}'

# LLM customer service
curl -X POST http://localhost:8080/chat \
  -H 'Content-Type: application/json' \
  -d '{"message": "How does the platform detect fraud?"}'

# RAG-grounded chat
curl -X POST http://localhost:8080/chat-rag \
  -H 'Content-Type: application/json' \
  -d '{"message": "Which deployment strategies does the platform support?"}'
```

## Containerized Run

From the repository root:

```bash
docker build -f capstone-nawex-ai-reliability-platform/Dockerfile -t nawex/capstone:latest .
docker run --rm -p 8080:8080 -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY nawex/capstone:latest
```

## Deliverables

- A single repository (this one) with all 15 milestones runnable end-to-end
- A one-page architecture diagram showing all eight layers
- The `demo.sh` runbook above, used to walk a reviewer through the platform
- A short write-up explaining one production trade-off you made and why

## Grading Rubric (for instructors)

The book ships a 10-criterion rubric for community-college and university adoption. Add the rubric here when running this as a graded course.
