# Chapter 07 — Rent a computer with a wish-list (Terraform)

> Matches **Chapter 07** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 👀 Read-along · 💳 Needs an account that may cost money

---

## The big idea (in plain words)

So far, every program you wrote ran on your own laptop. But real systems often run on
computers you *rent* over the internet. That rented-computers world is called the **cloud**.

How do you get a rented computer? You could log into a website and click lots of buttons.
But there's a tidier way. Imagine a **robot builder**: you hand it a *wish-list* written in a
file — "I'd like one small computer, in this part of the world, with this name" — and the
robot goes and builds exactly that for you. That robot builder is called **Terraform**.

Writing down the computers you want in a file (instead of clicking buttons by hand) is called
**infrastructure as code**. The big win: the file is repeatable. Run it again and you get the
same thing, every time, with no forgotten clicks.

> 👀 **This is a read-along chapter.** Building real cloud computers needs an account that can
> cost money. You do **not** have to run anything here. Reading it carefully and understanding
> *what* the wish-list says is the whole goal. You lose nothing by reading instead of running.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Cloud** — Renting someone else's computers over the internet instead of buying your own.
- **AWS** — Amazon's cloud, one popular place to rent computers.
- **EC2** — A single rented computer in AWS.
- **Terraform** — The "robot builder." You write a wish-list of cloud computers; it builds them.
- **Infrastructure as code** — Writing down the computers you want in a file, instead of
  clicking buttons by hand.
- **Free tier** — A small amount of cloud use that's free for new accounts. Stay inside it to
  avoid charges.

## What you will understand

A single small file called `main.tf`. It is a wish-list that asks the robot builder to rent
**one small computer** in Amazon's cloud, give it a name, and then tell you its internet
address. By the end you'll be able to read that file and explain, in plain words, what every
block asks for.

---

## ⚠️ Money and safety — read this box first

Renting cloud computers is not free play money. Before anyone (a pro, a mentor, or you) runs
real Terraform against AWS:

- 💳 **AWS asks for a credit card** when you sign up. That alone means real money is involved.
- 🧾 **It can cost money** if you leave computers running. A forgotten computer keeps charging.
- 🧹 **ALWAYS run `terraform destroy` when done.** This tells the robot builder to take the
  computer back down so it stops costing anything. This is the single most important habit.
- 🔔 **Set a small billing alarm** (for example, $5) so AWS warns you before any surprise bill.
- 🆓 **Stay in the Free Tier.** The size used here, `t2.micro`, is free for new accounts.
- 🙋 **Get permission first if the account isn't yours.** Never spend someone else's money or
  use their account without a clear "yes."

If any of that feels like a lot — good instinct. That's exactly why this chapter is read-along.

## Watch how it's done (read-along)

Here is the entire wish-list, `main.tf`. Don't worry about typing it. We'll walk through it
block by block right below.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "zero2ai_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name        = "zero2ai-ai-server"
    Environment = "dev"
    Owner       = "T2S-Mentorship"
  }
}

output "server_ip" {
  value = aws_instance.zero2ai_server.public_ip
}
```

### Block 1 — pick the right toolbox

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

This tells the robot builder *which toolbox* to use. We pick the **AWS** toolbox (because we
want to build in Amazon's cloud), and we ask for version 5 or newer. Think of it like saying,
"Grab the Amazon toolkit, the recent edition."

### Block 2 — choose *where* in the world to build

```hcl
provider "aws" {
  region = "us-east-1"
}
```

A **region** is a giant computer warehouse in one part of the world. `us-east-1` is a big one
on the east coast of the United States. This line says, "Build my computer in that warehouse."

### Block 3 — the actual wish: one small computer

```hcl
resource "aws_instance" "zero2ai_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name        = "zero2ai-ai-server"
    Environment = "dev"
    Owner       = "T2S-Mentorship"
  }
}
```

This is the heart of the file. `aws_instance` means "a rented computer" (an **EC2** instance).
The plain-words read:

- `ami = "ami-0c55b159cbfafe1f0"` — the **starting picture** for the computer's disk. It's
  like choosing which operating system the computer boots up with.
- `instance_type = "t2.micro"` — the **size** of the computer. `t2.micro` is the smallest,
  cheapest size, and it's free for new accounts (Free Tier).
- `tags = { ... }` — sticky **name labels** so you can recognize this computer later: its
  name, that it's for "dev" (practice) work, and who owns it.

### Block 4 — ask the robot to report back the address

```hcl
output "server_ip" {
  value = aws_instance.zero2ai_server.public_ip
}
```

An **output** is just an answer the robot reports when it's finished. This one says, "After
you build it, tell me the computer's public internet address (its **IP**)," so you'd know how
to reach it.

## What a pro types (the real commands)

A professional would run four commands, in order. You're just reading to understand them:

```bash
terraform init      # download the AWS toolbox (do this once)
terraform plan      # preview what will be built — changes nothing yet
terraform apply     # actually build it (you must type "yes")
terraform destroy   # take it all back down (you must type "yes")
```

- **`init`** — fetch the toolbox the wish-list asked for.
- **`plan`** — a dry run. The robot shows you what it *would* build. Nothing real happens. This
  is the safe "let me see first" step.
- **`apply`** — the robot really builds it. Money can start counting from here.
- **`destroy`** — the robot takes the computer back down so it stops costing anything. Pros run
  this the moment they're done. Always.

> It is completely fine to just read and understand these. Knowing *what* `plan` and `destroy`
> do — and *why* `destroy` matters — already puts you ahead of many beginners.

---

## Try it yourself (mini challenges)

These are *thinking* challenges — no account needed. Just read the file and answer.

- 🔎 **Find the size.** Which line sets how big the computer is? If you wanted a bigger
  computer, which value would you change? (Careful: bigger usually means *not* free.)
- 🔎 **Find the location.** Which line decides *where* in the world the computer gets built?
  What word would you change to build somewhere else?
- 🔎 **Find the safety net.** Which of the four pro commands takes the computer back down so it
  stops costing money? Why would forgetting it lead to a surprise bill?
- 🔎 **Spot the preview.** Which command lets a pro *see* what will happen before anything real
  is built? Why is that a good habit?

## If something breaks

(For when you, a mentor, or a pro actually runs it — with permission and a billing alarm set.)

- **`No valid credential sources found`** → AWS doesn't know who you are. The pro needs to run
  `aws configure` and enter their account keys first.
- **`terraform: command not found`** → Terraform isn't installed. It's a separate download from
  terraform.io.
- **A bill appears / a computer is still running** → Something wasn't torn down. Run
  `terraform destroy` and confirm in the AWS console that the computer is gone.
- **`Error: creating EC2 Instance ... InvalidAMIID`** → The starting-picture (`ami`) code is
  old or wrong for that region. AMI codes change over time and differ per region.

## What you just learned

- The **cloud** means renting someone else's computers over the internet.
- **Terraform** is a robot builder: you hand it a wish-list file and it builds cloud computers.
- Writing computers down in a file is **infrastructure as code** — repeatable, no forgotten
  clicks.
- You can read a `main.tf` and explain each block: which toolbox, which location, what computer,
  and what to report back.
- The four pro commands are `init`, `plan`, `apply`, `destroy` — and **`destroy` is the habit
  that keeps you from a surprise bill**.
- Cloud work needs an account that can cost money, so reading to understand is a fine, safe
  choice.

## Where to next

➡ [Chapter 08 — Build bigger in the cloud](../chapter-08-cloud). You'll see how pros split the
wish-list into reusable building blocks and keep their notes safely online.
