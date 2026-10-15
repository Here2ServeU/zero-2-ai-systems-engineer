# Look up the AMI at plan time instead of hardcoding an ID. AMI IDs differ per
# region and change every time AWS publishes a patched image, so a hardcoded
# ID goes stale. The search pattern and owners come in as variables, so each
# environment (or a later chapter) can pick a different OS without editing
# this module.
data "aws_ami" "selected" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Firewall for the instances. Outbound is open (package installs, updates);
# inbound SSH only from the CIDRs you list. Empty list = no SSH at all.
resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-sg"
  description = "Access rules for ${var.name_prefix} instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "SSH from ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Register your public key with AWS so you can SSH in. Skipped when no key is
# given; the instances still launch, you just can't log in to them.
resource "aws_key_pair" "this" {
  count = var.public_key == "" ? 0 : 1

  key_name   = "${var.name_prefix}-key"
  public_key = var.public_key
}

resource "aws_instance" "this" {
  count = var.instance_count

  ami           = data.aws_ami.selected.id
  instance_type = var.instance_type

  # Spread instances across the subnets (and therefore across AZs).
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.public_key == "" ? null : aws_key_pair.this[0].key_name
  user_data              = var.user_data

  # Require IMDSv2 tokens: blocks a common credential-theft trick.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name_prefix}-${count.index + 1}"
  }
}
