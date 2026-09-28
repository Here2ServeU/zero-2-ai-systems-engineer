# Chapter 07 — Set up AWS and build your first cloud server (Terraform)

> Matches **Chapter 07** in the book. The runnable file for this chapter, `main.tf`, is in this folder.

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet · 🧑‍🤝‍🧑 Easier with a helper the first time

---

## The big idea (in plain words)

So far, every program you wrote ran on your own laptop. Real companies usually run their
programs on computers they **rent** from a big provider over the internet. This is called
**the cloud**. The biggest cloud provider is **Amazon Web Services (AWS)**.

You can rent a computer from AWS by clicking buttons on its website. But professionals
usually do it a different way. They write down what they want in a text file, for example
"one small computer, in this region, with this name", and a tool reads that file and
creates everything for them. That tool is **Terraform**. Describing your setup in files
like this is called **infrastructure as code**.

Why bother with a file instead of clicking?

- **It repeats exactly.** Run the same file tomorrow and you get the same result.
- **It shows exactly what exists.** Anyone can read the file and see what was built.
- **It cleans up.** One command deletes everything the file created, so nothing gets forgotten
  and keeps charging you.

In this chapter you will do the whole thing yourself, today:

1. Create an AWS account.
2. Protect it with a second login step.
3. Set a **budget** so AWS emails you before you spend money.
4. Create a safer everyday user for your tools.
5. Install the AWS command-line tool and Terraform.
6. Build a real server in the cloud, check it, and then delete it.

Plan for about **60–90 minutes**. You can stop after any part and come back later.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Cloud**: Using computers you rent over the internet instead of computers you own.
- **AWS (Amazon Web Services)**: Amazon's cloud. You pay only for what you use.
- **AWS Console**: The AWS website where you manage your account by clicking.
- **Root user**: The first login you create. It has full control of the account, including
  billing. Use it only for account settings.
- **IAM user**: An extra login you create inside your account with only the permissions you give
  it. IAM stands for *Identity and Access Management*.
- **MFA (multi-factor authentication)**: A second login step. After your password, you also enter
  a 6-digit code from an app on your phone.
- **Access key**: A pair of secret codes that lets tools on your laptop (like Terraform) act as
  your IAM user. Treat it like a password.
- **Budget**: A spending limit you set in AWS. When your costs get close to it, AWS emails you.
- **Region**: A group of AWS data centers in one part of the world, for example `us-east-1`
  (Northern Virginia, USA).
- **EC2 instance**: One rented computer (a server) in AWS.
- **Free Tier**: A set of AWS services and credits that new accounts can use for free, within limits.
- **Terraform**: A tool that reads a text file describing cloud resources and creates, changes,
  or deletes them for you.
- **Infrastructure as code**: Describing your servers and settings in files instead of setting
  them up by hand.

---

## ⚠️ Money and safety: read this before you start

AWS is a real paid service. If you follow this guide exactly, it should cost **$0**. Here's
why, and how to keep it that way:

- 💳 **AWS asks for a credit or debit card** when you sign up. You may see a small temporary charge
  (about $1) that is returned. It is only a check that the card works.
- 👤 **You must be 18 or older to own an AWS account.** If you are younger, a parent or guardian
  must create the account and enter the card details. They should sit with you for
  **Parts 1–3**. After that you can do most of the work while they check in.
- 🆓 **New accounts get free credits.** AWS gives new accounts credits to spend on eligible
  services. The small server in this chapter (`t3.micro`) is eligible. Running it for an hour
  costs about one cent, which the credits cover.
- 🔔 **You will set a budget alert (Part 3) before you build anything.** A budget sends you an
  email. **It does not stop spending by itself.** You still have to delete what you build.
- 🧹 **Always run `terraform destroy` when you finish.** A server you forget about keeps running,
  and keeps costing money, until you delete it.
- 🔑 **Never share your password, MFA codes, or access keys.** Never paste them into chat
  messages, screenshots, or GitHub. Anyone who has your access keys can spend money on your
  account.

> The AWS website changes its look from time to time. If a button in this guide has moved,
> look for the **same words** nearby, or type the service name (like "Budgets" or "IAM") into
> the search bar at the top of the AWS Console.

## What you need before you start

- [ ] A computer with Chapter 01 set up (you can open a terminal)
- [ ] An **email address** you can check right now
- [ ] A **mobile phone** that can receive a text message or call
- [ ] A **credit or debit card** (owned by the adult who is responsible for the account)
- [ ] An **authenticator app** on the phone. Free options: **Google Authenticator**,
      **Microsoft Authenticator**, or **Authy**. Install one now from your phone's app store.
- [ ] A way to **save a password safely**, like a password manager or a written note kept at home.
      Don't use a sticky note on your screen.

---

## Part 1: Create your AWS account

1. Open your web browser and go to **https://aws.amazon.com**.
2. Click **Create an AWS account** (or **Sign up**) in the top-right corner.
3. Fill in the first page:
   - **Root user email address**: the email you'll use for this account.
   - **AWS account name**: anything you like, for example `zero2ai-learning`.
   - Click **Verify email address**.
4. Check your email inbox for a message from AWS with a **verification code**. Type the code into
   the page and click **Verify**.
5. Create a **root user password**. Make it long (at least 12 characters) and don't use it
   anywhere else. Save it somewhere safe now. Click **Continue**.
6. **Choose a plan**, if AWS asks:
   - Pick the **Free plan**. On the Free plan, AWS doesn't charge your card. You use your free
     credits, and some expensive services are blocked. You can upgrade later if you ever need to.
7. **Contact information**:
   - For "How do you plan to use AWS?", choose **Personal**.
   - Enter the account owner's full name, phone number, and address.
   - Tick the box to accept the AWS Customer Agreement, then click **Continue**.
8. **Billing information**: enter the card details and billing address. Click **Verify and
   continue**. Your bank may show a pop-up asking you to approve. Approve it.
9. **Confirm your identity**: choose **Text message (SMS)** or **Voice call**, enter the phone
   number, and complete the security check. Type the code you receive and click **Continue**.
10. **Select a support plan**: choose **Basic support – Free**. Click **Complete sign up**.

**What you should see:** a page saying your account is being set up. You'll get an email when
it is ready. This usually takes a few minutes, but it can take up to 24 hours.

11. When the account is ready, go to **https://console.aws.amazon.com**, choose
    **Root user**, and sign in with your email and password.

**What you should see:** the **Console Home** page, with a search bar at the top and your
account name in the top-right corner.

---

## Part 2: Protect the root user with MFA

The root user controls everything, including billing. If someone learned the password, they
could run up a large bill. MFA means a password alone is not enough to sign in.

1. In the top-right corner, click your **account name**, then click **Security credentials**.
2. Find the section **Multi-factor authentication (MFA)** and click **Assign MFA device**.
3. **Device name**: type something like `my-phone`. Select **Authenticator app**. Click **Next**.
4. Click **Show QR code**. Open your authenticator app on your phone, tap **Add** (or **+**),
   and scan the QR code.
5. The app now shows a 6-digit code that changes every 30 seconds.
   - Type the current code into **MFA code 1**.
   - **Wait for the code to change**, then type the new code into **MFA code 2**.
6. Click **Add MFA**.

**What you should see:** your device listed under Multi-factor authentication. From now on,
signing in as root asks for your password **and** a code from your phone.

> ⚠️ Don't delete the authenticator app or the account entry in it. You need it to sign in.

---

## Part 3: Set a budget so you never get a surprise bill

A budget tells AWS: "Email me if my spending gets close to this amount." You will create two:

- A **zero-spend budget**, which emails you the moment you spend even 1 cent beyond the free allowance.
- A **monthly cost budget of $5**, as a second safety net.

### 3a. Create the zero-spend budget

1. In the search bar at the top of the Console, type **Budgets** and click **Budgets**
   (it's part of *Billing and Cost Management*).
2. Click **Create budget**.
3. Under **Budget setup**, choose **Use a template (simplified)**.
4. Under **Templates**, choose **Zero spend budget**.
5. **Budget name**: leave the default, or type `zero-spend-alert`.
6. **Email recipients**: type your email address (and the parent or guardian's email, separated
   by a comma, if you like).
7. Click **Create budget**.

### 3b. Create the $5 monthly budget

1. Click **Create budget** again.
2. Choose **Use a template (simplified)**, then choose **Monthly cost budget**.
3. **Budget name**: `monthly-5-dollars`.
4. **Enter your budgeted amount**: `5.00`.
5. **Email recipients**: your email address.
6. Click **Create budget**.

**What you should see:** both budgets listed on the Budgets page. AWS will email you when
actual or forecast costs pass the limits.

### 3c. Turn on Free Tier usage alerts

1. In the search bar, type **Billing** and open **Billing and Cost Management**.
2. In the left menu, click **Billing preferences**.
3. Find **Alert preferences**, click **Edit**, and tick **Receive AWS Free Tier alerts**.
   Confirm your email address and click **Update**.

> 📌 **Remember:** budgets and alerts **warn** you. They don't delete anything or stop charges.
> If you ever get an alert email, sign in and delete whatever is running. Part 8 shows how to check.

---

## Part 4: Create an everyday user for your tools (IAM)

You should not use the root user for daily work, and you should **never** create access keys
for it. Instead, you'll create an IAM user that can only manage EC2 servers. Even if its keys
leaked, it could not change your billing, your password, or your MFA.

### 4a. Create the user

1. In the search bar, type **IAM** and open it.
2. In the left menu, click **Users**, then click **Create user**.
3. **User name**: `terraform-student`. Leave **Provide user access to the AWS Management
   Console** **unticked** (this user is only for tools, not for signing in on the website).
   Click **Next**.
4. On **Set permissions**, choose **Attach policies directly**.
5. In the search box under **Permissions policies**, type `AmazonEC2FullAccess` and tick the box
   next to it. This lets the user create and delete EC2 servers, and nothing else.
6. Click **Next**, then **Create user**.

### 4b. Create an access key for the user

1. In the Users list, click **terraform-student**.
2. Open the **Security credentials** tab.
3. Scroll to **Access keys** and click **Create access key**.
4. Choose **Command Line Interface (CLI)**. Tick the confirmation box at the bottom and click
   **Next**.
5. **Description tag** (optional): `my-laptop`. Click **Create access key**.
6. You now see two values:
   - **Access key ID**: looks like `AKIAIOSFODNN7EXAMPLE`
   - **Secret access key**: a longer string that AWS shows **only once**
7. Click **Download .csv file** and keep it somewhere private on your computer (not inside this
   project folder). Then click **Done**.

> 🔑 **The secret access key works like a password.** Never put it in a code file, never commit
> it to GitHub, never share it in a screenshot. If you think it has leaked, return to this page,
> click **Actions → Deactivate**, then **Delete**, and create a new one.

---

## Part 5: Install the AWS command-line tool and connect it

The **AWS CLI** lets your terminal talk to your AWS account. Terraform uses the keys you save
with it.

### 5a. Install

**On a Mac:**

1. Download the installer: **https://awscli.amazonaws.com/AWSCLIV2.pkg**
2. Open the downloaded file and click through the installer (Continue → Install).

**On Windows:**

1. Download the installer: **https://awscli.amazonaws.com/AWSCLIV2.msi**
2. Open the downloaded file and click through the installer (Next → Install → Finish).
3. **Close your terminal and open a new one** so it finds the new tool.

**Check it worked:**

```bash
aws --version
```

**What you should see:** something like `aws-cli/2.x.x Python/3.x.x ...`.

### 5b. Save your access key on your laptop

```bash
aws configure
```

It asks four questions. Type your answer and press **Enter** after each one:

```text
AWS Access Key ID [None]: <paste your Access key ID>
AWS Secret Access Key [None]: <paste your Secret access key>
Default region name [None]: us-east-1
Default output format [None]: json
```

(When you paste the secret key, it may not appear on screen. That is normal.)

### 5c. Check that AWS recognizes you

```bash
aws sts get-caller-identity
```

**What you should see:** something like this, with your own numbers:

```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-student"
}
```

If the last line ends in `user/terraform-student`, your laptop is connected to AWS as your
everyday user. 🎉

---

## Part 6: Install Terraform

**On a Mac** (uses Homebrew, which you may have installed in Chapter 01):

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**On Windows** (in PowerShell):

```powershell
winget install Hashicorp.Terraform
```

Then **close and reopen your terminal**.

> No Homebrew or winget? Download Terraform from **https://developer.hashicorp.com/terraform/install**
> and follow the instructions for your system.

**Check it worked:**

```bash
terraform -version
```

**What you should see:** something like `Terraform v1.x.x`.

---

## Part 7: Read the file before you run it

Go to this chapter's folder:

```bash
cd chapter-07-terraform
```

Open `main.tf` in your editor. It has five blocks. Here's what each one does.

### Block 1: which provider Terraform should use

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

Terraform works with many clouds. A **provider** is the plugin that lets it talk to one of
them. This block says, "Use the official AWS provider, version 5."

### Block 2: which region to build in

```hcl
provider "aws" {
  region = "us-east-1"
}
```

Build everything in the `us-east-1` region (Northern Virginia, USA). It's the same region you
typed into `aws configure`.

### Block 3: find the operating system image

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```

Every server needs an operating system. An **AMI** (Amazon Machine Image) is a ready-made copy
of one. A `data` block **looks something up** without creating anything. This one asks AWS for
the newest official *Amazon Linux 2023* image. Image IDs change over time and are different in
each region, so looking the ID up is safer than typing it in.

### Block 4: the server itself

```hcl
resource "aws_instance" "zero2ai_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name        = "zero2ai-ai-server"
    Environment = "dev"
    Owner       = "T2S-Mentorship"
  }
}
```

A `resource` block **creates** something. `aws_instance` is an EC2 server.

- `ami = data.aws_ami.amazon_linux.id` uses the image found in Block 3.
- `instance_type = "t3.micro"` sets the size: 2 small processors and 1 GB of memory. It is one of
  the smallest sizes and is covered by the Free Tier.
- `tags` are labels. They make the server easy to find in the AWS Console. `Name` is the name
  shown in the list of servers.

### Block 5: print the result

```hcl
output "server_ip" {
  value = aws_instance.zero2ai_server.public_ip
}
```

An `output` prints a value when Terraform finishes. This one prints the server's public
**IP address**, which is its address on the internet.

---

## Part 8: Build it, check it, delete it

You'll run four commands, in this order. Stay in the `chapter-07-terraform` folder.

### Step 1: `terraform init` (set up the folder)

```bash
terraform init
```

This downloads the AWS provider into a hidden `.terraform` folder. You only need to run it once
per folder.

**What you should see:** `Terraform has been successfully initialized!`

### Step 2: `terraform plan` (preview only, changes nothing)

```bash
terraform plan
```

Terraform compares the file with what exists in your account and lists what it **would** do.
Nothing is created yet.

**What you should see:** a list with a `+` next to `aws_instance.zero2ai_server`, and at the end:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Read the plan. Check that it says **1 to add** and that the `instance_type` is `t3.micro`.

### Step 3: `terraform apply` (build it for real)

```bash
terraform apply
```

Terraform shows the plan again and asks `Enter a value:`. Type **`yes`** and press Enter.
(Anything other than `yes` cancels.)

**What you should see,** after about 30–60 seconds:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

server_ip = "54.123.45.67"
```

Your IP address will be different. **You now have a real server running in an AWS data center.**

**Check it in the AWS Console:**

1. Go to the Console. In the top-right corner, make sure the region says **N. Virginia**
   (`us-east-1`). If it doesn't, click it and choose **US East (N. Virginia)**.
2. Search for **EC2** and open it. Click **Instances** in the left menu.
3. You should see **zero2ai-ai-server** with **Instance state: Running**.

### Step 4: `terraform destroy` (delete it, and never skip this)

```bash
terraform destroy
```

Terraform lists what it will delete and asks `Enter a value:`. Type **`yes`** and press Enter.

**What you should see:**

```text
Destroy complete! Resources: 1 destroyed.
```

**Check in the Console:** refresh the EC2 **Instances** page. The server's state should change
to **Shutting-down** and then **Terminated**. Terminated servers stay in the list for about an
hour and then disappear. They don't cost anything.

> ✅ You just used infrastructure as code to create and delete a cloud server. Many professional
> cloud engineers do exactly these four steps every day.

---

## Your daily AWS safety checklist

Every time you use AWS from now on:

- [ ] Before building: run `terraform plan` and read what it will create.
- [ ] After you finish: run `terraform destroy` and type `yes`.
- [ ] Check the EC2 **Instances** page in the correct region. Nothing should say **Running**
      unless you meant it to.
- [ ] Once a week, open **Billing and Cost Management** and look at your costs for this month.
      It should be $0.00, or a few cents covered by credits.
- [ ] If a budget alert email arrives, sign in right away and delete what's running.

---

## Try it yourself (mini challenges)

Do each one, then **run `terraform destroy` before moving on.**

- 🏷️ **Rename the server.** Change `Name = "zero2ai-ai-server"` to a name of your choice. Run
  `terraform apply`. Look at the plan: does Terraform replace the server or update it in place?
  Check the new name in the EC2 console. Then destroy.
- 📤 **Add a second output.** Under the existing output, add:

  ```hcl
  output "server_id" {
    value = aws_instance.zero2ai_server.id
  }
  ```

  Run `terraform apply`. You'll see the server's ID (it starts with `i-`) printed as well.
  Then destroy.
- 🔎 **Read without building.** Run `terraform plan` after you have destroyed everything. Why
  does it say `1 to add` again?
- 🧠 **Think it through.** You forgot to run `destroy` and left a `t3.micro` server running.
  It costs about $0.01 per hour. How much would it cost after one month (about 730 hours)?
  Which of your safety nets from Part 3 would warn you first?

---

## If something breaks

- **`aws: command not found`** or **`terraform: command not found`**: The tool isn't installed,
  or your terminal was open during the install. Close the terminal, open a new one, and try
  again. If it still fails, repeat the install step.
- **`Unable to locate credentials`** or **`No valid credential sources found`**: Your laptop
  doesn't have your access key yet. Run `aws configure` again (Part 5b) and paste the key from
  your downloaded `.csv` file.
- **`InvalidClientTokenId`** or **`SignatureDoesNotMatch`**: The access key was typed or pasted
  incorrectly (often with an extra space). Run `aws configure` again and paste carefully.
- **`UnauthorizedOperation`** or **`not authorized to perform: ec2:...`**: Your IAM user is
  missing its permission. Go to IAM → Users → terraform-student → **Permissions** and check
  that `AmazonEC2FullAccess` is attached.
- **An error that mentions the Free plan or says the instance type isn't eligible**: Check that
  `instance_type` is exactly `t3.micro`.
- **Your account isn't ready yet**, or AWS says it's still being verified: New accounts can take
  up to 24 hours to activate. Wait for the "Welcome" email, then try again.
- **You can't see your server in the EC2 console**: You're probably looking at the wrong region.
  Switch the region (top-right corner) to **US East (N. Virginia)**.
- **You got a budget alert email**: Sign in, check EC2 → Instances in `us-east-1`, and run
  `terraform destroy` in this folder. Then open **Billing and Cost Management → Bills** to see
  what caused the cost.
- **You lost your phone or authenticator app**: On the root sign-in page, choose
  **Troubleshoot MFA** and follow the steps. AWS will verify you by email and phone.

---

## What you just learned

- **The cloud** means renting computers over the internet. **AWS** is the largest provider.
- How to **create an AWS account**, protect the root user with **MFA**, and use the root user only
  for account settings.
- How to set **budgets** and **Free Tier alerts**, and that budgets warn you but don't stop charges.
- Why you create an **IAM user** with limited permissions and an **access key** for your tools,
  and why that key must stay secret.
- How to install and connect the **AWS CLI** and **Terraform**.
- How to read a `main.tf` file: `provider`, `data`, `resource`, and `output` blocks.
- The four Terraform commands: `init` (set up), `plan` (preview), `apply` (build), and
  `destroy` (delete). **`destroy` is the habit that prevents surprise bills.**

## Where to next

➡ [Chapter 08 — Build bigger in the cloud](../chapter-08-cloud). You'll see how professionals
split Terraform files into reusable pieces and store Terraform's records safely online.
