# Chapter 08 — Build bigger in the cloud

> Matches **Chapter 08** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 👀 Read-along · 💳 Needs an account that may cost money

---

## The big idea (in plain words)

In [Chapter 07](../chapter-07-terraform) you met the **robot builder** (**Terraform**) and its
wish-list for renting *one* computer. That's great for a quick test. But real teams build the
same kind of computer over and over — one for practice, one for testing, one for the real
thing. Copying the same wish-list again and again gets messy.

So pros do two smart things:

1. **They make reusable building blocks (modules).** A **module** is like a single LEGO brick:
   build it once, then snap it in wherever you need that piece, filling in a few blanks each
   time (the name, the size, and so on).
2. **They keep their notes in a shared online folder.** Terraform writes down what it has built
   so it doesn't lose track. Instead of keeping those notes on one person's laptop, the team
   stores them online — in an **S3** bucket (a giant online folder) — so everyone shares the
   same memory.

This is the jump from "one quick computer" to "a tidy, team-ready way to build many."

> 👀 **This is a read-along chapter.** Like Chapter 07, doing this for real needs an account that
> can cost money. You do **not** have to run anything. Understanding *how the pieces fit
> together* is the whole goal.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Cloud** — Renting someone else's computers over the internet.
- **AWS** — Amazon's cloud.
- **EC2** — A single rented computer in AWS.
- **S3** — A giant online folder for files. One folder is called a "bucket."
- **Terraform** — The robot builder that reads your wish-list and builds cloud computers.
- **Module** — A reusable building block (a "LEGO brick") you can snap in again and again.
- **Variable** — A labeled blank to fill in later (you met these back in Chapter 01).
- **Output** — An answer the robot reports back when it's done.

## What you will understand

How a real cloud project is split into small files that work together:

```
backend/s3.tf              # a shared online folder for Terraform's notes
modules/ec2/               # the reusable LEGO brick (one computer)
  ├── main.tf              #   what the brick builds
  ├── variables.tf         #   the blanks the brick needs filled in
  └── outputs.tf           #   the answer the brick hands back
environments/dev/main.tf   # the real wish-list that snaps in the brick
```

By the end you'll be able to point at each file and say what its job is.

---

## ⚠️ Money and safety — read this box first

Same rules as Chapter 07. Before anyone runs this for real against AWS:

- 💳 **AWS asks for a credit card** at sign-up — real money is involved.
- 🧾 **It can cost money** if computers (or storage) are left running.
- 🧹 **ALWAYS run `terraform destroy` when done** so the rented computer comes back down.
- 🔔 **Set a small billing alarm** (for example, $5) for early warning.
- 🆓 **Stay in the Free Tier.** The size here, `t2.micro`, is free for new accounts.
- 🙋 **Get permission first if the account isn't yours.**

Reading to understand is a perfectly good, safe way to do this chapter.

## Watch how it's done (read-along)

Let's walk through the files one at a time, in plain words.

### File 1 — `backend/s3.tf` — a safe online folder for the robot's notes

```hcl
provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "tf_state" {
  bucket = "zero2ai-terraform-state-12345"
  tags   = { Name = "T2S-Terraform-State" }
}
```

- `provider "aws" { region = "us-east-1" }` — build in Amazon's east-coast warehouse.
- `aws_s3_bucket "tf_state"` — ask for an **S3** bucket (a giant online folder).
  - `bucket = "zero2ai-terraform-state-12345"` — the folder's unique name.
  - `tags = { ... }` — a sticky label so the team recognizes it.

**Why it matters:** this folder becomes the team's shared memory of what's been built, so two
people don't accidentally trip over each other.

### File 2 — `modules/ec2/main.tf` — the reusable LEGO brick

```hcl
resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  tags = { Name = var.name }
}
```

This asks for one rented computer (an **EC2** instance) — but notice it uses **blanks** instead
of fixed values. Each `var.something` means "fill this in later":

- `ami = var.ami` — the disk starting-picture, filled in later.
- `instance_type = var.instance_type` — the computer size, filled in later.
- `key_name = var.key_name` — the name of the **SSH key** (a secret password-key for logging
  in), filled in later.
- `tags = { Name = var.name }` — the computer's name label, filled in later.

**Why it matters:** because the values are blanks, you can reuse this one brick to build many
different computers — just fill the blanks differently each time.

### File 3 — `modules/ec2/variables.tf` — the list of blanks

```hcl
variable "ami" {}
variable "instance_type" {}
variable "key_name" {}
variable "name" { default = "zero2ai-server" }
```

This simply *lists* the blanks the brick needs. The last one has a `default`: if you don't fill
in `name`, it quietly uses `"zero2ai-server"`.

### File 4 — `modules/ec2/outputs.tf` — the answer the brick gives back

```hcl
output "public_ip" {
  value = aws_instance.this.public_ip
}
```

After the brick builds the computer, it hands back the computer's public internet address (its
**IP**), so whoever used the brick knows how to reach it.

### File 5 — `environments/dev/main.tf` — the real wish-list

```hcl
terraform {
  backend "s3" {
    bucket = "zero2ai-terraform-state-12345"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" { region = "us-east-1" }

module "ec2" {
  source        = "../../modules/ec2"
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = "aws-key"
}

output "server_ip" {
  value = module.ec2.public_ip
}
```

This is where everything snaps together — the "dev" (practice) wish-list:

1. `terraform { backend "s3" { ... } }` — keep the robot's notes in the S3 folder we made in
   File 1, under the file `dev/terraform.tfstate`.
2. `provider "aws" { region = "us-east-1" }` — build in the east-coast warehouse.
3. `module "ec2" { ... }` — snap in the reusable brick from `../../modules/ec2` and **fill in
   its blanks**: the disk picture (`ami`), the free-tier size (`t2.micro`), and the login key
   name (`aws-key`).
4. `output "server_ip" { ... }` — print the new computer's public address that the brick
   handed back.

**The big picture:** the brick (Files 2–4) is built once and reused; the wish-list (File 5)
just fills in the blanks. That's how teams build many computers without copy-paste mess.

## What a pro types (the real commands)

You're reading to understand — no need to run these. A pro would:

```bash
# 1. Create the shared online notes folder, once
cd backend && terraform init && terraform apply && cd ..

# 2. Make a login key, and register it with AWS
ssh-keygen -t rsa -b 2048 -f aws-key

# 3. Build the dev computer
cd environments/dev && terraform init && terraform apply

# 4. Log in to check it, then ALWAYS tear it down
chmod 400 ../../aws-key
ssh -i ../../aws-key ec2-user@YOUR_PUBLIC_IP
terraform destroy
```

In plain words:

- **Step 1** makes the shared notes folder once.
- **`ssh-keygen`** creates a secret key-pair so you can safely log in to the computer later.
  **SSH** just means "log in to a remote computer securely."
- **`terraform apply`** builds the computer (money can start counting here).
- **`ssh -i ...`** logs in to the freshly built computer using your key.
- **`terraform destroy`** takes it back down so it stops costing money. Pros always end here.

> It is completely fine to just read and understand. Knowing how a module, an S3 backend, and a
> dev wish-list fit together is real cloud knowledge, account or no account.

---

## Try it yourself (mini challenges)

Thinking challenges — no account needed.

- 🔎 **Spot the reuse.** Which file is the reusable brick, and which file *uses* it? Find the
  line in the wish-list that snaps the brick in.
- 🔎 **Trace one blank.** The brick asks for `var.instance_type`. Find where that blank is
  *listed*, and find where it's actually *filled in*. What size does it get filled with?
- 🔎 **Follow the notes.** Which file creates the shared online folder, and which line tells the
  wish-list to *store its notes there*? What's the folder's name?
- 🔎 **Find the safety net.** Which command takes the computer back down so it stops costing
  money? (Same hero as Chapter 07.)

## If something breaks

(For when a pro or mentor runs it for real, with permission and a billing alarm.)

- **`BucketAlreadyExists`** → S3 bucket names must be unique across all of AWS. The pro needs a
  different name than `zero2ai-terraform-state-12345`.
- **`Backend initialization required`** → They changed the backend settings; running
  `terraform init` again fixes it.
- **`Permission denied (publickey)` when SSH-ing** → The key wasn't registered with AWS, or
  `chmod 400 aws-key` was skipped. The key file must be private.
- **A bill appears** → A computer was left running. Run `terraform destroy` and confirm in the
  AWS console that it's gone.

## What you just learned

- Pros split cloud wish-lists into reusable **modules** (LEGO bricks) instead of copy-pasting.
- A module has three parts: what it builds (`main.tf`), its blanks (`variables.tf`), and the
  answer it hands back (`outputs.tf`).
- **Variables** are blanks filled in later; **outputs** are answers reported back.
- Terraform keeps **notes** about what it built, and teams store those notes online in an **S3**
  bucket so everyone shares the same memory.
- **SSH** means securely logging in to a remote computer.
- And, once more: **`terraform destroy`** is the habit that prevents surprise bills.

## Where to next

➡ [Chapter 09 — A robot helper that checks your work (CI/CD)](../chapter-09-cicd). Good news: the
next chapter needs only a *free* GitHub account — no credit card — so you can actually try it.
