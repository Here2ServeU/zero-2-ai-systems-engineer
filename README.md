# Zero 2 AI Systems Engineer

The companion repository to *Zero 2 AI Systems Engineer: The Complete Beginner's Playbook* by Rev. Emmanuel Naweji (T2S Mentorship Program, 2026).

This repo contains the working codebase for the book's capstone project — the **Nawex AI Reliability Platform** — built up week by week across all 8 layers.

## The 8 Layers

1. **Foundation & Mindset** — Weeks 1, 2 (Chapters 1, 2, 3)
2. **Data & Models** — Week 3 (Chapter 4)
3. **APIs & Containers** — Weeks 4, 5 (Chapters 5, 6)
4. **Cloud Infrastructure** — Weeks 6, 7 (Chapters 7, 8)
5. **Automation & Orchestration** — Weeks 8, 9 (Chapters 9, 10)
6. **Observability & Operations** — Weeks 10, 11 (Chapters 11, 12)
7. **Continuous Delivery & Safe Deployment** — Weeks 12, 13, 14 (Chapters 13, 14, 15)
8. **Modern AI · LLMs & RAG** — Weeks 15, 16, 17 (Chapters 16, 17, 18)
9. **Capstone** — Nawex AI Reliability Platform (15 milestones)

## What I Am Building

- Fraud detection model (FinTech) with MLflow experiment tracking
- Healthcare anomaly detection model
- Flask APIs for model serving
- Dockerized services
- Terraform infrastructure on AWS
- Kubernetes deployment with Helm
- Prometheus + Grafana monitoring
- AIOps for predictive operations
- Automated retraining on drift
- Canary and blue-green safe deployment
- LLM customer-service feature with Anthropic Claude
- RAG pipeline grounded in a private knowledge base via ChromaDB

## Repository Layout

```
course/                      # Week-by-week implementation
  week-01-foundations/
  week-02-regulated-environments/
  week-03-classical-ml-and-mlflow/
  week-04-serving-models-via-apis/
  week-05-containerization-with-docker/
  week-06-infrastructure-as-code-terraform/
  week-07-cloud-deployment/
  week-08-ci-cd-for-mlops/
  week-09-kubernetes-and-orchestration/
  week-10-observability-and-monitoring/
  week-11-aiops/
  week-12-advanced-ci-cd-and-retraining-pipelines/
  week-13-advanced-deployment-and-model-promotion/
  week-14-observability-deep-dive-and-dashboards/
  week-15-llm-customer-service/
  week-16-rag-pipeline/
  week-17-production-llm-systems/
capstone-nawex-ai-reliability-platform/   # All 8 layers wired together
fintech/                     # FinTech vertical notes
healthcare/                  # Healthcare vertical notes
```

Each week follows the same pattern: `README.md`, `src/`, `data/` (where applicable), and supporting infrastructure assets.

## Start Here

- [course/README.md](course/README.md) — week-by-week overview
- [COURSE_INDEX.md](COURSE_INDEX.md) — full course index
- [PROJECT_WEEKS.md](PROJECT_WEEKS.md) — chapter-to-week roadmap
- [course/week-01-foundations/README.md](course/week-01-foundations/README.md) — first lab
- [capstone-nawex-ai-reliability-platform/README.md](capstone-nawex-ai-reliability-platform/README.md) — capstone milestones

## Local Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 course/week-01-foundations/src/train_model.py
```

For the LLM and RAG weeks (15-17), you also need an Anthropic API key:

```bash
export ANTHROPIC_API_KEY=...
```

## Goal

To become a top-tier AI Systems Engineer capable of designing, deploying, and operating production AI platforms across classical ML, MLOps, AIOps, large language models, and retrieval-augmented generation.
