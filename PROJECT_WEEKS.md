# Project Weeks Roadmap

This roadmap maps the chapters of *Zero 2 AI Systems Engineer* to the week-by-week build sequence in this repository. Every chapter from 1 to 18 has a corresponding week, plus the capstone.

## Week 1 — Foundations of Production AI Systems

- Chapters: `1`, `2`
- Focus: production AI mindset, system thinking, MLOps + DevOps + AIOps foundations
- Outcome: baseline repository, system health prediction model

## Week 2 — AI in Regulated Environments

- Chapter: `3`
- Focus: FinTech and Healthcare constraints, compliance-aware system design
- Outcome: documented risk, governance, and environment assumptions for both verticals

## Week 3 — Classical ML and Experiment Tracking with MLflow

- Chapter: `4`
- Focus: train fraud detection and anomaly detection models; track every run in MLflow
- Outcome: reproducible model artifacts plus MLflow run history

## Week 4 — Serving Models via APIs

- Chapter: `5`
- Focus: expose the Week 3 models through a Flask service
- Outcome: prediction API with `/predict` and `/health` endpoints

## Week 5 — Containerization with Docker

- Chapter: `6`
- Focus: package the API as a container
- Outcome: `Dockerfile`, container run instructions, local image build workflow

## Week 6 — Infrastructure as Code with Terraform

- Chapter: `7`
- Focus: define cloud infrastructure as code
- Outcome: Terraform modules for networking, compute, and deployment support

## Week 7 — Cloud Deployment

- Chapter: `8`
- Focus: deploy the application stack to AWS
- Outcome: cloud deployment plan for the API and supporting infrastructure

## Week 8 — CI/CD for MLOps

- Chapter: `9`
- Focus: automate testing, packaging, and deployment workflows
- Outcome: CI pipeline for linting, dependency install, model validation, image build

## Week 9 — Kubernetes and Orchestration

- Chapter: `10`
- Focus: orchestration, scaling, resilience, service exposure
- Outcome: Kubernetes manifests and Helm-based deployment path

## Week 10 — Observability and Monitoring

- Chapter: `11`
- Focus: metrics, health checks, logging, monitoring design
- Outcome: observability baseline with Prometheus and Grafana integration

## Week 11 — AIOps

- Chapter: `12`
- Focus: intelligent operations, anomaly detection, alerting signals
- Outcome: initial AIOps use case for system health anomaly detection

## Week 12 — Advanced CI/CD and Retraining Pipelines

- Chapter: `13`
- Focus: retraining workflows, scheduled jobs, model lifecycle automation
- Outcome: retraining pipeline triggered by drift signals

## Week 13 — Advanced Deployment and Model Promotion

- Chapter: `14`
- Focus: model versioning, canary and blue-green deployment, rollback planning
- Outcome: staged deployment strategy for development, staging, and production

## Week 14 — Observability Deep Dive and Dashboards

- Chapter: `15`
- Focus: dashboards, deep metrics visibility, decision-ready reporting
- Outcome: platform dashboards covering API, model, infrastructure, operations

## Week 15 — LLM-Powered Customer Service with Claude

- Chapter: `16`
- Focus: integrate Anthropic Claude behind production-grade controls
- Outcome: chat endpoint with structured logging, prompt versioning, recorded-response tests

## Week 16 — RAG Pipeline with ChromaDB

- Chapter: `17`
- Focus: ground the LLM in a private knowledge base via retrieval-augmented generation
- Outcome: ingestion script, persistent ChromaDB collection, RAG-augmented chat endpoint

## Week 17 — Production LLM Systems

- Chapter: `18`
- Focus: prompt caching, evaluation harness, output validation, cost guardrails, fallbacks, PII handling
- Outcome: hardened LLM platform fit for production operation

## Capstone — Nawex AI Reliability Platform

- See [capstone-nawex-ai-reliability-platform/README.md](capstone-nawex-ai-reliability-platform/README.md)
- Wires all 8 layers and 15 milestones into one runnable platform

## Course Structure

Every week folder follows the same pattern:

- `lab/` hands-on implementation
- `data/` datasets or sample inputs
- `notebooks/` exploration notebooks
- `src/` source code
- `README.md` weekly overview and deliverables

## Mapped Assets

- Week 6 contains Terraform assets in `course/week-06-infrastructure-as-code-terraform/terraform/`
- Week 9 contains Kubernetes and Helm assets in `course/week-09-kubernetes-and-orchestration/kubernetes/`
- Week 14 contains dashboards in `course/week-14-observability-deep-dive-and-dashboards/dashboards/`
- Week 16 persists vector embeddings in `course/week-16-rag-pipeline/chroma/`
