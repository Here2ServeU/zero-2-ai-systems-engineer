output "grafana_admin_password" {
  value       = random_password.grafana_admin.result
  sensitive   = true
  description = "Show it with: terraform output -raw grafana_admin_password"
}

output "platform_alb_hostname" {
  value       = kubernetes_ingress_v1.platform.status[0].load_balancer[0].ingress[0].hostname
  description = "DNS name of the shared ALB."
}

output "platform_url" {
  value       = "http://${kubernetes_ingress_v1.platform.status[0].load_balancer[0].ingress[0].hostname}"
  description = "Open in a browser: links to Grafana, Prometheus and every chapter app. New ALBs need 1-3 minutes for DNS."
}

output "grafana_url" {
  value = var.enable_monitoring ? "http://${kubernetes_ingress_v1.platform.status[0].load_balancer[0].ingress[0].hostname}:3000   (user: admin)" : "monitoring disabled"
}

output "prometheus_url" {
  value = var.enable_monitoring && length(var.alb_admin_cidrs) > 0 ? "http://${kubernetes_ingress_v1.platform.status[0].load_balancer[0].ingress[0].hostname}:9090" : "not exposed (alb_admin_cidrs is empty): kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
}

output "open_grafana" {
  value = "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80   # then http://localhost:3000 (user: admin)"
}

output "open_prometheus" {
  value = "kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090   # then http://localhost:9090"
}

output "app_namespace" {
  value = kubernetes_namespace_v1.apps.metadata[0].name
}
