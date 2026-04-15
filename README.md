# NAWEX Production AI Systems Platform

This repository documents my journey building production-grade AI systems across FinTech and Healthcare.

## What I Am Building

- Fraud detection system (FinTech)
- Healthcare anomaly detection system
- ML APIs (Flask/FastAPI)
- Dockerized services
- Terraform infrastructure
- Kubernetes deployment (EKS)
- Helm charts for Kubernetes packaging
- Monitoring and AIOps (Prometheus, Grafana)

## Architecture

Data -> Model -> API -> Infrastructure -> Monitoring -> Automation

## Weekly Progress

- `course/week-01-foundations`
- `course/week-02-regulated-environments`
- `course/week-03-serving-models-via-apis`
- `course/week-04-containerization-with-docker`
- `course/week-05-infrastructure-as-code-terraform`
- `course/week-06-cloud-deployment`
- `course/week-07-ci-cd-for-mlops`
- `course/week-08-kubernetes-and-orchestration`
- `course/week-09-observability-and-monitoring`
- `course/week-10-aiops`
- `course/week-11-advanced-ci-cd-and-retraining-pipelines`
- `course/week-12-advanced-deployment-and-model-promotion`
- `course/week-13-observability-deep-dive-and-dashboards`

## Goal

To become a top-tier AI Systems Engineer capable of designing, deploying, and operating production AI platforms.

## Deployment Assets

- Terraform infrastructure under `course/week-05-infrastructure-as-code-terraform/terraform/`
- Kubernetes and Helm deployment assets under `course/week-08-kubernetes-and-orchestration/kubernetes/`
- Dashboards under `course/week-13-observability-deep-dive-and-dashboards/dashboards/`
- Full chapter-to-week roadmap in `PROJECT_WEEKS.md`
- Full course index in `COURSE_INDEX.md`

## Course Layout

Each week is organized as its own module with:

- `lab/`
- `data/`
- `notebooks/`
- `src/`
- `README.md`

## Start Here

- Course folder: [course/README.md](/Users/emmanuelnaweji/nawex-mlops-aiops-plaftorm/course/README.md)
- Course index: [COURSE_INDEX.md](/Users/emmanuelnaweji/nawex-mlops-aiops-plaftorm/COURSE_INDEX.md)
- Weekly roadmap: [PROJECT_WEEKS.md](/Users/emmanuelnaweji/nawex-mlops-aiops-plaftorm/PROJECT_WEEKS.md)
- Current implemented lab: [week-01-foundations](/Users/emmanuelnaweji/nawex-mlops-aiops-plaftorm/course/week-01-foundations/README.md)

## Local Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 course/week-01-foundations/src/train_model.py
```
