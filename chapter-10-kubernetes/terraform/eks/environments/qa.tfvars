# QA: looks like prod (private nodes, logs on) but smaller.
environment = "qa"
vpc_cidr    = "10.50.0.0/16"

private_nodes = true

node_capacity_type  = "SPOT"
node_instance_types = ["t3.medium", "t3a.medium"]
node_min_size       = 2
node_desired_size   = 2
node_max_size       = 4

cluster_log_types         = ["api", "audit", "authenticator"]
log_retention_days        = 7
enable_secrets_encryption = true
