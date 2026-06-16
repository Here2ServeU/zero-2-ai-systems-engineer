# Chapter 08 — Cloud Deployment with Modules & SSH

**Book:** Chapter 8 (Cloud Deployment on AWS) · Lab 8.2
**Layer:** 4 · Cloud Infrastructure · **You build:** Modular infra, remote state, SSH access

## Layout

```
backend/s3.tf              # S3 bucket for remote Terraform state
modules/ec2/               # reusable EC2 module (main/variables/outputs)
environments/dev/main.tf   # dev environment, uses the module + S3 backend
```

## Run

```bash
# 1. Create the remote-state bucket once
cd backend && terraform init && terraform apply && cd ..

# 2. Generate an SSH key pair and import the .pub into AWS (EC2 -> Key Pairs)
ssh-keygen -t rsa -b 2048 -f aws-key

# 3. Deploy the dev environment
cd environments/dev && terraform init && terraform apply

# 4. Connect, then tear down
chmod 400 ../../aws-key
ssh -i ../../aws-key ec2-user@YOUR_PUBLIC_IP
terraform destroy
```

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. We are still
using **Terraform**, the robot builder that reads our wish-list and builds computers in
the **cloud** (renting Amazon's computers over the internet). This time we break the
wish-list into reusable pieces called **modules** — think of a module as one LEGO brick
you can snap in again and again.

### `backend/s3.tf` — a safe online folder to remember our work

**In one sentence:** This file asks the robot to make a giant online folder where Terraform
can store its notes about what it has built.

**What it does, step by step:**

1. `provider "aws" { region = "us-east-1" }` — Tells the robot to build in Amazon's east-coast
   warehouse.
2. `resource "aws_s3_bucket" "tf_state" { ... }` — Asks for an **S3** bucket. S3 is a giant
   online folder for files, and a "bucket" is just one such folder.
   - `bucket = "nawex-terraform-state-12345"` — The folder's unique name.
   - `tags = { Name = "T2S-Terraform-State" }` — A sticky label so we recognize it.

**What you get:** A safe online folder (an S3 bucket) where Terraform keeps its memory of
what it built, so the whole team shares the same notes.

### `modules/ec2/main.tf` — the reusable LEGO brick for one computer

**In one sentence:** This is a reusable building block that rents one computer, using blanks
that get filled in later.

**What it does, step by step:**

1. `resource "aws_instance" "this" { ... }` — Asks for one rented computer (an **EC2**
   instance, meaning a rented computer). But instead of fixed values, it uses blanks:
   - `ami = var.ami` — the disk starting picture, filled in later.
   - `instance_type = var.instance_type` — the computer size, filled in later.
   - `key_name = var.key_name` — the name of the SSH key (a secret password-key) used to
     log in, filled in later.
   - `tags = { Name = var.name }` — a name label, filled in later.

**What you get:** A reusable LEGO brick that can build a computer over and over, just by
filling in different blanks each time.

### `modules/ec2/variables.tf` — the blanks to fill in

**In one sentence:** This file lists the blanks (**variables**) that the LEGO brick above
needs you to fill in.

**What it does, step by step:**

1. `variable "ami" {}` — a blank for the disk starting picture.
2. `variable "instance_type" {}` — a blank for the computer size.
3. `variable "key_name" {}` — a blank for the login key name.
4. `variable "name" { default = "nawex-server" }` — a blank for the computer's name; if you
   leave it empty, it uses "nawex-server" by default.

**What you get:** A clear list of the blanks the building block needs, so you know exactly
what to fill in.

### `modules/ec2/outputs.tf` — the answer the brick gives back

**In one sentence:** This file says what answer (**output**) the building block hands back
after it builds the computer.

**What it does, step by step:**

1. `output "public_ip" { value = aws_instance.this.public_ip }` — After building, it reports
   the computer's public address (its IP) so you can reach it.

**What you get:** The new computer's public address, handed back to whoever used the brick.

### `environments/dev/main.tf` — the real wish-list that uses the brick

**In one sentence:** This is the actual "dev" (practice) wish-list that fills in the blanks
and snaps in the LEGO brick to build a real computer.

**What it does, step by step:**

1. `terraform { backend "s3" { ... } }` — Tells the robot to keep its memory notes in the S3
   online folder we made earlier (`nawex-terraform-state-12345`), under the file
   `dev/terraform.tfstate`, in the `us-east-1` warehouse.
2. `provider "aws" { region = "us-east-1" }` — Build in the east-coast warehouse.
3. `module "ec2" { ... }` — Snap in the reusable EC2 brick from `../../modules/ec2` and fill
   in its blanks:
   - `ami = "ami-0c55b159cbfafe1f0"` — the disk starting picture.
   - `instance_type = "t2.micro"` — the smallest, free-tier computer size.
   - `key_name = "aws-key"` — the login key named "aws-key".
4. `output "server_ip" { value = module.ec2.public_ip }` — Print the new computer's public
   address that the brick handed back.

**What you get:** One small, free-tier computer built from the reusable brick, with its
memory stored safely online and its address printed out so you can SSH (log in) to it.

➡ Next: [chapter-09-cicd](../chapter-09-cicd) — automate test + build with GitHub Actions.
