###############################################################################
# EKS add-ons stack: the shared software every chapter's app relies on,
# installed into the cluster with HELM (Kubernetes' package manager).
#
#   aws-load-balancer-controller  turns Ingress / LoadBalancer Services into
#                                 real AWS load balancers (Chapters 10, 14, 18)
#   metrics-server                CPU/memory numbers for `kubectl top` and the
#                                 HorizontalPodAutoscaler (Phase 3 everywhere)
#   kube-prometheus-stack         Prometheus + Grafana + Alertmanager
#                                 (Chapters 11, 12, 15, 18)
#   external-secrets              copies AWS Secrets Manager values into
#                                 Kubernetes Secrets (Chapters 16-18, Phase 3)
#   cluster-autoscaler            adds/removes nodes when pods don't fit
#
# Run AFTER ../eks for the same environment. It finds the cluster by name, so
# the two stacks never read each other's state.
###############################################################################

terraform {
  required_version = ">= 1.5"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Stack       = "eks-addons"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  cluster_name = "${var.project_name}-eks-${var.environment}"
  is_prod      = var.environment == "prod"
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

# Both providers log in to the cluster the same way kubectl does: by asking
# the AWS CLI for a short-lived token. No long-lived credentials are stored.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region]
    }
  }
}

# ----------------------------------------------------------------------------
# Namespaces and the default disk type.
# ----------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "apps" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/part-of" = "zero2ai"
      # Pod Security Standards: warn (don't block) on anything less than
      # "restricted". Our chart is written to pass.
      "pod-security.kubernetes.io/warn"    = "restricted"
      "pod-security.kubernetes.io/enforce" = "baseline"
    }
  }
}

# gp3 disks: cheaper and faster than gp2. Marked default so any
# PersistentVolumeClaim without a storageClassName gets one.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

# ----------------------------------------------------------------------------
# AWS Load Balancer Controller. Its IAM role is attached by Pod Identity in
# ../eks (service account kube-system/aws-load-balancer-controller).
# ----------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_versions.aws_load_balancer_controller
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  values = [yamlencode({
    clusterName  = local.cluster_name
    region       = var.aws_region
    vpcId        = data.aws_eks_cluster.this.vpc_config[0].vpc_id
    replicaCount = local.is_prod ? 2 : 1
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
    }
    # Off: with it on, creating ANY Service fails while the controller is
    # starting. Our LoadBalancer Services opt in with annotations instead.
    enableServiceMutatorWebhook = false
  })]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server
  namespace  = "kube-system"

  values = [yamlencode({
    replicas = local.is_prod ? 2 : 1
  })]
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.chart_versions.cluster_autoscaler
  namespace  = "kube-system"

  values = [yamlencode({
    cloudProvider = "aws"
    awsRegion     = var.aws_region
    autoDiscovery = {
      clusterName = local.cluster_name
    }
    rbac = {
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler"
      }
    }
    extraArgs = {
      balance-similar-node-groups = true
      skip-nodes-with-system-pods = false
      scale-down-unneeded-time    = "5m"
    }
  })]
}

resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_versions.external_secrets
  namespace        = "external-secrets"
  create_namespace = true

  wait    = true
  timeout = 600

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
    }
  })]
}

# ----------------------------------------------------------------------------
# Prometheus + Grafana + Alertmanager.
# ----------------------------------------------------------------------------
resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_monitoring ? 1 : 0

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_versions.kube_prometheus_stack
  namespace        = "monitoring"
  create_namespace = true

  wait    = true
  timeout = 900

  values = [yamlencode({
    grafana = {
      adminPassword = random_password.grafana_admin.result
      persistence = {
        enabled = local.is_prod
        size    = "5Gi"
      }
      sidecar = {
        # Any ConfigMap labelled grafana_dashboard=1 in ANY namespace becomes
        # a dashboard. Chapter 15's chart ships one this way.
        dashboards = {
          enabled         = true
          label           = "grafana_dashboard"
          labelValue      = "1"
          searchNamespace = "ALL"
        }
      }
    }
    prometheus = {
      prometheusSpec = {
        # Pick up ServiceMonitors / PrometheusRules from every Helm release,
        # not just this one. This is how each chapter's app gets scraped.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        retention                               = var.prometheus_retention
        resources = {
          requests = { cpu = "200m", memory = "512Mi" }
          limits   = { memory = "1536Mi" }
        }
        storageSpec = local.is_prod ? {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp3"
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "20Gi" } }
            }
          }
        } : null
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        replicas = local.is_prod ? 2 : 1
      }
    }
  })]

  depends_on = [kubernetes_storage_class_v1.gp3, helm_release.aws_load_balancer_controller]
}
