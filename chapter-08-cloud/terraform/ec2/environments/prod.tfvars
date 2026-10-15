# Prod: the "real" environment. Two servers in two Availability Zones, so one
# data center going down doesn't take everything down.
environment = "prod"

vpc_cidr = "10.30.0.0/16"

instance_type  = "t3.small"
instance_count = 2

# Prod can pin a more specific AMI pattern than dev/qa if you want fewer surprises:
# ami_name_filter = "al2023-ami-2023.6.*-x86_64"

allowed_ssh_cidrs = []
