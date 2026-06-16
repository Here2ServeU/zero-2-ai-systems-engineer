# Zero to AI Systems Engineer

Companion code for **_Zero to AI Systems Engineer: Build, Deploy, and Scale Real ML
Systems_** by Rev. Dr. Emmanuel Naweji (T2S — Transformed 2 Succeed, Professional Edition,
2026).

This repository **is** the book's `ai-ml-engineer` workspace. Each chapter maps to one
`chapter-XX-*` folder containing that chapter's exact lab scripts, plus the book's two
industry capstones, **NexaGuard** (FinTech) and **ClarityAI** (Healthcare). The folder
names, scripts, and run commands match the book verbatim, so you can `cd chapter-XX-...` and
follow along.

## The flagship project: Zero2AI fraud detection

Layer by layer, the chapter labs build one production AI system — a fraud detection
platform that generates data, trains a model, serves it behind a Flask API, runs in
Docker and Kubernetes, deploys to AWS with Terraform, monitors itself with Prometheus +
Grafana, predicts its own failures with AIOps, retrains on drift, deploys safely with
canary/blue-green, and answers questions with an LLM grounded by RAG.

## Chapter map

| Folder | Book chapter(s) | Topic | Key scripts |
|---|---|---|---|
| [chapter-01-setup](chapter-01-setup) | 0, 1 | Toolkit + dev environment | `hello.py` |
| [chapter-02-data](chapter-02-data) | 2 | First ML experiment (manual logging) | `generate_data.py`, `train_model.py` |
| [chapter-03-models](chapter-03-models) | 3 | Fraud + healthcare anomaly models | `create_fintech_data.py`, `fraud_detection.py`, `anomaly_detection.py` |
| [chapter-04-mlflow](chapter-04-mlflow) | 4 | Experiment tracking with MLflow | `train_with_tracking.py`, `register_best_model.py` |
| [chapter-05-api](chapter-05-api) | 5 | Serving models via APIs | `app/model.py`, `app/api.py` |
| [chapter-06-docker](chapter-06-docker) | 6 | Containerization with Docker | `Dockerfile`, `docker-compose.yml` |
| [chapter-07-terraform](chapter-07-terraform) | 7 | Infrastructure as Code | `main.tf` |
| [chapter-08-cloud](chapter-08-cloud) | 8 | Cloud deployment, modules, SSH | `modules/ec2/`, `environments/dev/` |
| [chapter-09-cicd](chapter-09-cicd) | 9 | CI/CD with GitHub Actions | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) |
| [chapter-10-kubernetes](chapter-10-kubernetes) | 10 | Kubernetes & orchestration | `deployment.yaml`, `service.yaml` |
| [chapter-11-monitoring](chapter-11-monitoring) | 11 | Observability with Prometheus | `app_with_metrics.py`, `anomaly_detection.py` |
| [chapter-12-aiops](chapter-12-aiops) | 12 | AIOps engine | `aiops_engine.py`, `automated_response.py` |
| [chapter-13-retraining](chapter-13-retraining) | 13 | Drift detection + retraining | `drift_detector.py`, `retrain_pipeline.py`, [`retrain.yml`](.github/workflows/retrain.yml) |
| [chapter-14-deployment](chapter-14-deployment) | 14 | Canary, feature flags, blue/green | `src/router.py`, `src/feature_flag.py`, `src/switch.py` |
| [chapter-15-dashboards](chapter-15-dashboards) | 15 | Prometheus + Grafana stack | `monitored_api.py`, `docker-compose.yml` |
| [chapter-16-llm](chapter-16-llm) | 16 | LLM foundations (Claude) | `verify_api.py`, `llm_api.py` |
| [chapter-17-rag](chapter-17-rag) | 17 | RAG pipeline (ChromaDB) | `index_corpus.py`, `retrieval.py`, `rag_query.py` |
| [chapter-18-prodllm](chapter-18-prodllm) | 18 | Production LLM systems | `production_llm.py` |
| [nexaguard](nexaguard) | Capstone 1 | FinTech fraud platform | scaffold + 10 milestones |
| [clarityai](clarityai) | Capstone 2 | Healthcare clinical platform | scaffold + 10 milestones |

## The eight-layer stack

1. **Foundation & Mindset** — Chapters 1–3
2. **Data & Models** — Chapters 4–5
3. **APIs & Containers** — Chapters 5–6
4. **Cloud Infrastructure** — Chapters 7–8
5. **Automation & Orchestration** — Chapters 9–10
6. **Observability & Operations** — Chapters 11–12
7. **Continuous Delivery & Safe Deployment** — Chapters 13–15
8. **Modern AI · LLMs & RAG** — Chapters 16–18

## Getting started

```bash
# Per the book, each chapter's lab uses its own virtual environment and installs
# only the packages it needs. To set up one environment for the whole workspace:
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Run the first program:
python3 chapter-01-setup/hello.py
```

For the LLM/RAG chapters (16–18) you also need an Anthropic API key:

```bash
export ANTHROPIC_API_KEY='your-key-here'
```

> **Model id note:** the book's LLM labs use `model='claude-opus-4-7'`. Set this to a
> currently available Claude model for your account (e.g. `claude-opus-4-8` or
> `claude-sonnet-4-6`).

## The professional workflow (Appendix A)

Every lab follows the same loop: create folder → create venv → activate → write code →
`git add` → `git commit` → push → `deactivate`. See
[APPENDIX_A_github_workflow.md](APPENDIX_A_github_workflow.md) for the full GitHub setup
and push workflow.

— *Soli Deo gloria.*
