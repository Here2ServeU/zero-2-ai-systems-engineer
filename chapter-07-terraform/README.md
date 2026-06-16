# Chapter 07 — Infrastructure as Code with Terraform

**Book:** Chapter 7 (Infrastructure as Code with Terraform) · Lab 7.3
**Layer:** 4 · Cloud Infrastructure · **You build:** A real EC2 instance, defined as code

## What you build

A single `main.tf` declaring the AWS provider and one `t2.micro` EC2 instance with tags.
You exercise the full Terraform workflow: init, plan, apply, destroy.

## Run

```bash
terraform init      # download AWS provider plugin
terraform plan      # preview changes
terraform apply     # create the infrastructure (type yes)
terraform destroy   # ALWAYS tear down when done (type yes)
```

> Requires AWS credentials (`aws configure`). `t2.micro` is Free-Tier eligible.
> Set a $5 billing alarm and always run `terraform destroy` at the end of the lab.

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. In this
chapter we use **Terraform**, which is like a robot builder. You hand the robot a
wish-list written in a file, and it goes and builds computers for you in the **cloud**
(the cloud just means renting someone else's computers over the internet). Writing down
the computers you want in a file, instead of clicking lots of buttons, is called
**infrastructure as code**.

### `main.tf` — the wish-list for the robot builder

**In one sentence:** This file is the wish-list that tells the Terraform robot to rent one
small computer in the cloud for us.

**What it does, step by step:**

1. The `terraform { required_providers ... }` block — Tells the robot which toolbox to
   use. Here it picks the **AWS** toolbox (AWS is Amazon's cloud, where we rent computers),
   version 5 or newer.
2. `provider "aws" { region = "us-east-1" }` — Tells the robot *where* in the world to
   build. `us-east-1` is a big computer warehouse on the east coast of the United States.
3. `resource "aws_instance" "nawex_server" { ... }` — This is the main wish. It asks for
   one rented computer (an **EC2** instance; EC2 just means "a rented computer"):
   - `ami = "ami-0c55b159cbfafe1f0"` — The starting picture for the computer's disk,
     like choosing which operating system it boots up with.
   - `instance_type = "t2.micro"` — The size of the computer. `t2.micro` is the smallest,
     cheapest size, and it is free for new accounts (Free-Tier).
   - `tags = { ... }` — Sticky name labels so we can recognize our computer later
     (its name, that it is for "dev" work, and who owns it).
4. `output "server_ip" { ... }` — After building, the robot tells us back the computer's
   public address (its **IP**), so we know how to reach it. An **output** is just an answer
   the robot reports back when it is done.

**What you get:** One small, free-tier rented computer in the Amazon cloud, built
automatically from a single file, with its address printed out for you at the end.

➡ Next: [chapter-08-cloud](../chapter-08-cloud) — modular Terraform + remote state + SSH.
