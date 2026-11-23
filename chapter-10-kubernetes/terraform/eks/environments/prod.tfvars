# Prod: the "fully fledged" platform.
#   - nodes in PRIVATE subnets across 3 AZs, internet via one NAT gateway
#   - ON_DEMAND nodes (never taken back), room to autoscale to 6
#   - control-plane audit logs kept 30 days, Secrets encrypted with KMS
#   - immutable image tags: v1.0 always means the same image
environment = "prod"
vpc_cidr    = "10.60.0.0/16"
az_count    = 3

private_nodes = true

node_capacity_type  = "ON_DEMAND"
node_instance_types = ["t3.large"]
node_min_size       = 3
node_desired_size   = 3
node_max_size       = 6

cluster_log_types         = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
log_retention_days        = 30
enable_secrets_encryption = true
ecr_immutable_tags        = true

# Lock the Kubernetes API to your own address(es) in real production:
# api_public_access_cidrs = ["203.0.113.10/32"]
