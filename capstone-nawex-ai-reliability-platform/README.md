# Capstone — Nawex AI Reliability Platform

> The capstone project of *Zero 2 AI Systems Engineer*. Wires all eight layers of the book into a single working platform.

## What You Are Building

A production-style AI platform that integrates every technique covered in the book:

- Classical ML models (fraud detection, healthcare anomaly detection)
- Model serving via Flask APIs
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
| 6 | AWS infrastructure provisioned via Terraform | Week 6, 7 |
| 7 | CI pipeline (lint, test, build, push image) | Week 8 |
| 8 | Kubernetes deployment with Helm chart | Week 9 |
| 9 | Prometheus + Grafana observability stack | Week 10 |
| 10 | AIOps anomaly detection on platform telemetry | Week 11 |
| 11 | Automated retraining triggered by drift signal | Week 12 |
| 12 | Canary + blue-green deploy with model promotion | Week 13 |
| 13 | Production dashboards covering API, model, infra, ops | Week 14 |
| 14 | LLM customer-service feature with Claude | Week 15 |
| 15 | RAG pipeline grounded in private knowledge base | Week 16, 17 |

## Deliverables

- A single repository (this one) with all 15 milestones runnable end-to-end
- A one-page architecture diagram showing all eight layers
- A demo script that walks a reviewer through the platform in under 10 minutes
- A short write-up explaining one production trade-off you made and why

## Grading Rubric (for instructors)

The book ships a 10-criterion rubric for community-college and university adoption. Add the rubric here when running this as a graded course.
