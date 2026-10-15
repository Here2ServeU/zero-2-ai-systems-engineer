# QA: where changes are tested before prod. Same shape as prod, smaller size.
environment = "qa"

vpc_cidr = "10.20.0.0/16"

instance_type  = "t3.micro"
instance_count = 1

allowed_ssh_cidrs = []
