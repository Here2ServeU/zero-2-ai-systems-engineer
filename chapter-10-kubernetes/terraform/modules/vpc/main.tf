# One VPC per environment. By default: public subnets only and no NAT gateway,
# because NAT costs ~$32/month per env even when idle.
#
# Chapter 10's production EKS environment turns on private subnets + one NAT
# gateway (private_subnet_count > 0 and enable_nat_gateway = true), so worker
# nodes get no public IPs. Chapter 08's ec2 stack leaves both off: unchanged.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Public subnets across N AZs. /24 each, carved out of the VPC CIDR by index
# so the layout is the same in every env: 10.x.1.0/24, 10.x.2.0/24, ...
resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  # subnet_tags lets other stacks add their own discovery tags. Chapter 10's
  # EKS stack passes kubernetes.io/cluster/<name> and kubernetes.io/role/elb.
  tags = merge(
    { Name = "${var.name_prefix}-public-${count.index + 1}" },
    var.subnet_tags,
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Optional private subnets + NAT (off by default; used by EKS qa/prod).
###############################################################################

locals {
  create_private = var.private_subnet_count > 0
  create_nat     = local.create_private && var.enable_nat_gateway
}

# Private subnets: 10.x.101.0/24, 10.x.102.0/24, ... so they never overlap the
# public ones (10.x.1.0/24, ...). No public IPs are handed out here.
resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 101)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    { Name = "${var.name_prefix}-private-${count.index + 1}" },
    var.private_subnet_tags,
  )
}

# One NAT gateway in the first public subnet: lets private servers reach the
# internet (to pull images, call AWS APIs) without being reachable from it.
# One NAT is a cost trade-off; a NAT per AZ survives an AZ outage.
resource "aws_eip" "nat" {
  count  = local.create_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count = local.create_nat ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  count  = local.create_private ? 1 : 0
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = local.create_nat ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}
