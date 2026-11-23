###############################################################################
# The platform's front door: ONE AWS Application Load Balancer (ALB) for the
# whole cluster, so you can reach everything from a browser or with curl,
# without port-forward.
#
#   http://<alb>/        landing page with a link to every service below
#   http://<alb>:3000    Grafana                         (anyone, password-protected)
#   http://<alb>:9090    Prometheus                      (alb_admin_cidrs only)
#   http://<alb>:9093    Alertmanager                    (alb_admin_cidrs only)
#   http://<alb>:80NN    Chapter NN's Phase 3 app        (joins in deploy.sh 3)
#
# How: every Ingress with the annotation group.name = var.alb_group_name is
# merged by the AWS Load Balancer Controller into the SAME ALB. Each service
# gets its own listener port, so the apps keep their normal paths (/health,
# /predict) and no path rewriting is needed. One ALB (~$0.0225/hour) instead
# of one per chapter.
#
# Prometheus and Alertmanager have no login, so they are only opened to the
# IP ranges in alb_admin_cidrs. platform-up.sh fills that in with YOUR public
# IP automatically. Empty list = not exposed (use port-forward).
###############################################################################

locals {
  alb_common_annotations = {
    "alb.ingress.kubernetes.io/scheme"        = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"   = "ip"
    "alb.ingress.kubernetes.io/group.name"    = var.alb_group_name
    "alb.ingress.kubernetes.io/success-codes" = "200"
    "alb.ingress.kubernetes.io/tags"          = "Project=${var.project_name},Environment=${var.environment},ManagedBy=aws-load-balancer-controller"
  }

  expose_admin = length(var.alb_admin_cidrs) > 0

  # Links on the landing page: name => [port, path].
  landing_links = merge(
    var.enable_monitoring ? { "Grafana (user admin)" = [3000, "/"] } : {},
    var.enable_monitoring && local.expose_admin ? {
      "Prometheus (admin IPs)"   = [9090, "/"]
      "Alertmanager (admin IPs)" = [9093, "/"]
    } : {},
    { for name, port in var.app_ports : name => [port, "/health"] },
  )

  # The ALB answers "/" itself with this small page (an ALB fixed response may
  # be at most 1024 bytes). The links are built in the browser from the
  # address you opened, so the page doesn't need to know its own DNS name.
  landing_html = join("", [
    "<!doctype html><meta charset=utf-8><title>${var.project_name}-${var.environment}</title>",
    "<body style='font:16px sans-serif;margin:2em'><h2>${var.project_name} ${var.environment} platform</h2><p>Chapter apps answer once you run their <code>deploy.sh 3</code>.<ul id=l></ul>",
    "<script>var L=${jsonencode(local.landing_links)},h=location.hostname,o='';",
    "for(var k in L)o+='<li><a href=\"http://'+h+':'+L[k][0]+L[k][1]+'\">'+k+'</a> :'+L[k][0];",
    "document.getElementById('l').innerHTML=o</script>",
  ])
}

# ---- Landing page (port 80): creates the ALB --------------------------------
resource "kubernetes_ingress_v1" "platform" {
  metadata {
    name      = "zero2ai-platform"
    namespace = "kube-system"
    annotations = merge(local.alb_common_annotations, {
      "alb.ingress.kubernetes.io/listen-ports"  = jsonencode([{ HTTP = 80 }])
      "alb.ingress.kubernetes.io/inbound-cidrs" = join(",", var.alb_allowed_cidrs)
      "alb.ingress.kubernetes.io/actions.landing" = jsonencode({
        type = "fixed-response"
        fixedResponseConfig = {
          contentType = "text/html"
          statusCode  = "200"
          messageBody = local.landing_html
        }
      })
    })
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "landing"
              port {
                name = "use-annotation"
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  # Destroyed BEFORE the controller, so the controller is still alive to
  # delete the real ALB in AWS (otherwise it would be left behind, costing
  # money and blocking the VPC delete).
  depends_on = [helm_release.aws_load_balancer_controller]

  lifecycle {
    precondition {
      condition     = length(local.landing_html) <= 1024
      error_message = "The landing page is ${length(local.landing_html)} bytes; an ALB fixed response allows 1024. Remove some app_ports."
    }
  }
}

# ---- Monitoring UIs ----------------------------------------------------------
locals {
  monitoring_ui = {
    grafana = {
      service = "kube-prometheus-stack-grafana"
      port    = 80
      listen  = 3000
      health  = "/api/health"
      cidrs   = var.alb_allowed_cidrs
      enabled = var.enable_monitoring
    }
    prometheus = {
      service = "kube-prometheus-stack-prometheus"
      port    = 9090
      listen  = 9090
      health  = "/-/ready"
      cidrs   = var.alb_admin_cidrs
      enabled = var.enable_monitoring && local.expose_admin
    }
    alertmanager = {
      service = "kube-prometheus-stack-alertmanager"
      port    = 9093
      listen  = 9093
      health  = "/-/ready"
      cidrs   = var.alb_admin_cidrs
      enabled = var.enable_monitoring && local.expose_admin
    }
  }
}

resource "kubernetes_ingress_v1" "monitoring" {
  for_each = { for k, v in local.monitoring_ui : k => v if v.enabled }

  metadata {
    name      = "zero2ai-${each.key}"
    namespace = "monitoring"
    annotations = merge(local.alb_common_annotations, {
      "alb.ingress.kubernetes.io/listen-ports"     = jsonencode([{ HTTP = each.value.listen }])
      "alb.ingress.kubernetes.io/inbound-cidrs"    = join(",", each.value.cidrs)
      "alb.ingress.kubernetes.io/healthcheck-path" = each.value.health
    })
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = each.value.service
              port {
                number = each.value.port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_ingress_v1.platform,
    helm_release.kube_prometheus_stack,
    helm_release.aws_load_balancer_controller,
  ]
}
