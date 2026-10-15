# Dev: where you experiment. Smallest and cheapest. Break it freely.
environment = "dev"

# Each env gets its own non-overlapping range, so they could be connected later.
vpc_cidr = "10.10.0.0/16"

instance_type  = "t3.micro"
instance_count = 1

# To SSH in, put your public IP here (find it with: curl https://checkip.amazonaws.com)
# Example: allowed_ssh_cidrs = ["203.0.113.10/32"]
allowed_ssh_cidrs = []
