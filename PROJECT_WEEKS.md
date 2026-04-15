# Project Weeks Roadmap

This roadmap organizes the provided chapters into a practical weekly build sequence for the NAWEX Production AI Systems Platform.

## Note

The source set provided includes Chapters `1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15`.

Chapter `4` was not included in the materials, so this plan skips it and keeps momentum on the implementation path.

## Week 1 - Foundations of Production AI Systems

- Chapters: `1` and `2`
- Focus: production AI mindset, system thinking, MLOps + DevOps + AIOps foundations
- Project outcome: baseline repository, Week 1 dataset, first system health prediction model

## Week 2 - AI in Regulated Environments

- Chapter: `3`
- Focus: FinTech and Healthcare constraints, compliance-aware system design, reliability expectations
- Project outcome: document risk, governance, and environment assumptions for both verticals

## Week 3 - Serving Models via APIs

- Chapter: `5`
- Focus: expose the Week 1 model through a Flask or FastAPI service
- Project outcome: prediction API with `/predict` and `/health` endpoints

## Week 4 - Containerization with Docker

- Chapter: `6`
- Focus: package the API as a container
- Project outcome: `Dockerfile`, container run instructions, local image build workflow

## Week 5 - Infrastructure as Code with Terraform

- Chapter: `7`
- Focus: define cloud infrastructure as code
- Project outcome: initial Terraform modules for networking, compute, and deployment support

## Week 6 - Cloud Deployment

- Chapter: `8`
- Focus: deploy the application stack to AWS
- Project outcome: cloud deployment plan for the API and supporting infrastructure

## Week 7 - CI/CD for MLOps

- Chapter: `9`
- Focus: automate testing, packaging, and deployment workflows
- Project outcome: CI pipeline for linting, dependency install, model script validation, and image build

## Week 8 - Kubernetes and Orchestration

- Chapter: `10`
- Focus: orchestration, scaling, resilience, and service exposure
- Project outcome: Kubernetes manifests and Helm-based deployment path

## Week 9 - Observability and Monitoring

- Chapter: `11`
- Focus: metrics, health checks, logging, and monitoring design
- Project outcome: observability baseline with Prometheus and Grafana integration points

## Week 10 - AIOps

- Chapter: `12`
- Focus: intelligent operations, anomaly detection, alerting signals, and operational automation
- Project outcome: initial AIOps use case for system health anomaly detection

## Week 11 - Advanced CI/CD and Retraining Pipelines

- Chapter: `13`
- Focus: retraining workflows, scheduled jobs, and model lifecycle automation
- Project outcome: retraining pipeline design for continuous improvement

## Week 12 - Advanced Deployment and Model Promotion

- Chapter: `14`
- Focus: model versioning, promotion strategy, rollback planning, and release controls
- Project outcome: staged deployment strategy for development, staging, and production

## Week 13 - Observability Deep Dive and Dashboards

- Chapter: `15`
- Focus: dashboards, deep metrics visibility, and decision-ready reporting
- Project outcome: platform dashboard plan for API, model, infrastructure, and operations views

## Course Structure

- `week-01-foundations/`
- `week-02-regulated-environments/`
- `week-03-serving-models-via-apis/`
- `week-04-containerization-with-docker/`
- `week-05-infrastructure-as-code-terraform/`
- `week-06-cloud-deployment/`
- `week-07-ci-cd-for-mlops/`
- `week-08-kubernetes-and-orchestration/`
- `week-09-observability-and-monitoring/`
- `week-10-aiops/`
- `week-11-advanced-ci-cd-and-retraining-pipelines/`
- `week-12-advanced-deployment-and-model-promotion/`
- `week-13-observability-deep-dive-and-dashboards/`

Each week follows the same pattern:

- `lab/` hands-on implementation
- `data/` datasets or sample inputs
- `notebooks/` exploration notebooks
- `src/` source code
- `README.md` weekly overview and deliverables

## Mapped Assets

- Week 5 contains Terraform assets in `week-05-infrastructure-as-code-terraform/terraform/`
- Week 8 contains Kubernetes and Helm assets in `week-08-kubernetes-and-orchestration/kubernetes/`
- Week 13 contains dashboards in `week-13-observability-deep-dive-and-dashboards/dashboards/`
