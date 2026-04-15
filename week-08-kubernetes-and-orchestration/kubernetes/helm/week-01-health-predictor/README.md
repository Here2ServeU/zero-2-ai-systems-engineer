# Week 1 Health Predictor Helm Chart

This Helm chart packages the Week 1 prediction service for Kubernetes deployment.

## Install

```bash
helm install week-01 week-08-kubernetes-and-orchestration/kubernetes/helm/week-01-health-predictor
```

## Override Image

```bash
helm install week-01 week-08-kubernetes-and-orchestration/kubernetes/helm/week-01-health-predictor \
  --set image.repository=<your-registry>/week-01-health-predictor \
  --set image.tag=<image-tag>
```

## Render Templates

```bash
helm template week-01 week-08-kubernetes-and-orchestration/kubernetes/helm/week-01-health-predictor
```
