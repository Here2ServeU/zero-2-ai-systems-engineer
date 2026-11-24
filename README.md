# Start From Zero — The Beginner's Edition

Welcome. This edition teaches the **exact same skills** as the main book, but rewritten for
someone who has **never** written code, never used AI or machine learning, and has never
touched the cloud or DevOps. No experience needed. We start at *truly* zero.

> This is the beginner edition of *Zero to AI Systems Engineer*. Each chapter folder holds a
> gentle, tiny-step guide **and the runnable scripts** for that chapter, so you can read it,
> run it, and learn at your own pace — no prior experience needed.

## How this edition is different

- **Tiny steps.** Every chapter is broken into small steps. You always know the *one* thing
  to do next.
- **Plain words first.** We explain the idea with an everyday picture (a lunchbox, a robot
  builder, a pen pal) *before* showing any code.
- **Try-it-yourself.** Each chapter ends with little challenges so you *do*, not just read.
- **"If it breaks" help.** Beginners hit errors. We list the common ones and how to fix them.
- **No surprises about money.** Some chapters need accounts that can cost money. Those are
  clearly flagged so you never get a surprise bill.

## The labels you'll see at the top of each chapter

| Label | What it means |
|---|---|
| **Runs free on your laptop** | You can fully do this with just your computer. No account, no money. |
| **Needs the internet** | The chapter talks to something online. |
| **Needs an account that may cost money** | You must sign up somewhere, sometimes with a credit card. **Get permission first if the account isn't yours.** |
| **Easier with a helper the first time** | Setup is fiddly; a more experienced person nearby helps a lot. |
| **Read-along** | Hard or costly to run yourself. Read it to understand *what* the pros do, then move on. You lose nothing by reading instead of running. |

## The journey (18 chapters)

You'll build **one real system, one layer at a time**: a program that spots fake/fraudulent
payments, then learns to run anywhere, watch itself, heal itself, and even answer questions
in plain English.

### Part 1 — Get going (do every step yourself)
1. [Chapter 01 — Set up your computer and say hello](chapter-01-setup)
2. [Chapter 02 — Your very first tiny AI experiment](chapter-02-data)
3. [Chapter 03 — Teach the computer to spot trouble](chapter-03-models)
4. [Chapter 04 — Keep a tidy notebook of your experiments](chapter-04-mlflow)
5. [Chapter 05 — Let other programs talk to your model](chapter-05-api)

### Part 2 — Make it run anywhere
6. [Chapter 06 — Pack your program into a box (Docker)](chapter-06-docker)
7. [Chapter 07 — Set up AWS and build your first cloud server (Terraform)](chapter-07-terraform)
8. [Chapter 08 — Build bigger in the cloud](chapter-08-cloud)
9. [Chapter 09 — A robot helper that checks your work (CI/CD)](chapter-09-cicd)
10. [Chapter 10 — Run many copies safely (Kubernetes)](chapter-10-kubernetes) — builds the **cloud platform** every later chapter runs on

From here on, **every chapter builds a platform that companies hire for**, and each one plugs into
the platform you built in the chapter before:

| Chapter | The platform you build | Who builds it at work |
|---|---|---|
| [10 — Run many copies safely (Kubernetes)](chapter-10-kubernetes) | Container platform on Kubernetes | Platform Engineer, DevOps Engineer |
| [11 — Watch your program's health (Monitoring)](chapter-11-monitoring) | Observability platform | Site Reliability Engineer (SRE) |
| [12 — Teach the system to fix itself (AIOps)](chapter-12-aiops) | Self-healing (AIOps) platform | SRE, AIOps Engineer |
| [13 — Notice when the world changes (Drift & retraining)](chapter-13-retraining) | MLOps continuous-training platform | MLOps Engineer |
| [14 — Release changes without scary surprises](chapter-14-deployment) | Progressive delivery platform | Release Engineer, DevOps Engineer |
| [15 — Dashboards you can watch (Grafana)](chapter-15-dashboards) | SRE dashboards and alerting platform | SRE, Observability Engineer |
| [16 — Talk to a smart writing robot (LLM)](chapter-16-llm) | LLM application (AI gateway) platform | AI Engineer, AI Platform Engineer |
| [17 — Give the robot your own notes to read (RAG)](chapter-17-rag) | Enterprise knowledge (RAG) platform | AI Engineer, ML Engineer |
| [18 — Run the smart robot for real (Production LLM)](chapter-18-prodllm) | Production GenAI (LLMOps) platform — the capstone | LLMOps Engineer, AI Platform Engineer |

### How every chapter from 10 on works: three phases

Big companies never put a brand-new idea straight into production. They try it small, move it
somewhere real, then harden it. You'll do exactly the same, in every chapter:

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **Phase 1 — Build it on your laptop** | Your computer | Learn the new idea step by step, then pack it into a container. | Free |
| **Phase 2 — Promote it to the cloud** | AWS (EKS) | **2A:** run it with plain Kubernetes YAML. **2B:** package it with Helm and test it the same way you did on your laptop. | Costs money while it runs |
| **Phase 3 — Run it like a Fortune 500 company** | AWS (EKS) | Production settings: autoscaling, no-downtime safety nets, security, alerts, dashboards, secrets, plus how real teams run it (SLOs, runbooks, cost control, a readiness checklist). | Costs money while it runs |

Each chapter's `README.md` is Phase 1. Its `cloud/README.md` is Phase 2 and its
`cloud/PRODUCTION.md` is Phase 3. Phase 1 is always free, and you can stop there and still
learn the whole idea.

Before your first Phase 2, build the shared cloud platform once:
**[chapter-10-kubernetes/PLATFORM.md](chapter-10-kubernetes/PLATFORM.md)** (Terraform for the
cluster and image registries, Helm for the add-ons). One shared **Application Load Balancer** is
its front door: open its landing page in your browser (or `curl` it) to reach Grafana,
Prometheus and every chapter's app. It costs money while it runs, and every chapter shows how to
tear it down.

## What you need before Chapter 01

Almost nothing. Just:
- A computer (Windows, Mac, or Linux).
- About 30 minutes for the first setup.
- Curiosity. That's it.

Chapter 01 installs everything else, slowly, one piece at a time.

## One golden rule for beginners

> **Read the whole step, then do it. If something looks scary, it's just a new word — every
> new word is explained in the [GLOSSARY](GLOSSARY.md).**

Open the [GLOSSARY](GLOSSARY.md) in a second tab. Whenever you meet a bold word you don't
know, look it up there.

Start now: [Chapter 01 — Set up your computer and say hello](chapter-01-setup)
