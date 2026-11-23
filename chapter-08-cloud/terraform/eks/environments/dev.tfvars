# Dev: learn and break things. Cheapest setup that still runs every chapter.
#   - nodes in PUBLIC subnets (no NAT gateway, saves ~$32/month)
#   - 2 x t3.medium on SPOT (cheapest; nodes may be replaced, Kubernetes copes)
#   - no control-plane logs, no KMS
environment = "dev"
vpc_cidr    = "10.40.0.0/16"

private_nodes = false

node_capacity_type  = "SPOT"
node_instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
node_min_size       = 2
node_desired_size   = 2
node_max_size       = 4

cluster_log_types         = []
enable_secrets_encryption = false
