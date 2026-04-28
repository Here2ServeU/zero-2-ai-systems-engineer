# Nawex AI Reliability Platform — Overview

The Nawex AI Reliability Platform is the capstone project of *Zero 2 AI Systems Engineer*. It integrates classical machine learning, modern generative AI, and the operational disciplines of MLOps, DevOps, and AIOps into a single deployable system.

The platform serves two regulated verticals: FinTech (fraud detection on transaction streams) and Healthcare (anomaly detection on patient vitals). Both verticals share the same infrastructure backbone — model serving, observability, retraining, and safe deployment — so a single operations team can run both with the same tools.

The platform is built on AWS, containerized with Docker, orchestrated by Kubernetes, monitored by Prometheus and Grafana, and deployed via Terraform-managed infrastructure with GitHub Actions handling CI/CD. The generative AI layer is powered by Anthropic's Claude, augmented by retrieval-augmented generation grounded in this knowledge base.
