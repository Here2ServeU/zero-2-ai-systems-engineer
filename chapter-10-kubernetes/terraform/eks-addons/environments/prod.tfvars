environment          = "prod"
prometheus_retention = "15d"

# The platform ALB: in prod, replace with your office / VPN ranges, e.g.
# alb_allowed_cidrs = ["203.0.113.0/24"]
alb_allowed_cidrs = ["0.0.0.0/0"]
