output "grafana_admin_password" {
  value       = random_password.grafana_admin.result
  sensitive   = true
  description = "Show it with: terraform output -raw grafana_admin_password"
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
