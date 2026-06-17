# Chapter 06 — Pack your program into a box (Docker)

> Matches **Chapter 06** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 💻 Runs free on your laptop · 🧑‍🤝‍🧑 Easier with a helper the first time

---

## The big idea (in plain words)

In Chapter 05 you built a front desk (an API) and ran it on *your* laptop. But here's a worry
every builder has: "It works on my computer... will it work on someone else's?" Maybe their
computer has a different Python, or a missing helper, and it breaks.

The fix is to pack your program into a **lunchbox** — your code *and* every helper it needs,
all sealed together — so it runs the exact same way on any computer. The tool that makes these
lunchboxes is called **Docker**. A sealed lunchbox is called a **container**, and the recipe
for making one is a **Dockerfile**.

> **Good news:** the program *inside* the box is the **same** fraud front desk you already
> built in Chapter 05. We're not writing new app code — we're just learning to pack it up.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Docker** — the tool that packs your program into a lunchbox so it runs the same everywhere.
- **Image** — the recipe/snapshot Docker builds (the *packed* lunchbox, before it's opened).
- **Container** — a *running* copy of an image (the lunchbox, opened and in use).
- **Dockerfile** — the recipe that tells Docker how to build the image.

## What you will build

A self-contained lunchbox (a Docker **image**) holding your fraud API, then you'll run it as a
**container** and knock on its door — just like Chapter 05, but now fully packed up. Expected
result: `curl http://localhost:5000/health` answers `healthy` from inside the box.

---

## Let's do it, one small step at a time

### Step 1 — Install Docker Desktop (this is the fiddly part)

Before anything else, you need Docker itself.

1. Go to **docker.com/products/docker-desktop** and download **Docker Desktop** for your
   system (Windows or Mac).
2. Install it like a normal app, then **open it**. Wait until its little whale icon shows it's
   "running" (it can take a minute the first time).
3. **Check it worked** — open your terminal and type:

   ```bash
   docker --version
   ```

   **What you should see:** something like `Docker version 24.0.6`.

> 🧑‍🤝‍🧑 This install is the trickiest part of the whole book — it touches deep computer
> settings and sometimes asks for a restart. If a more experienced person is around, this is a
> great moment to have them sit with you. Once Docker is installed, the rest is easy.

### Step 2 — Go to the chapter's code folder

```bash
cd chapter-06-docker
```

Inside you'll find the same `app/` from Chapter 05, plus two new files:

- **`Dockerfile`** — the recipe for the lunchbox.
- **`docker-compose.yml`** — a one-button way to start the whole thing.

**What the `Dockerfile` recipe says, in plain words (you don't edit it — just understand it):**

- Start from a small box that already has Python inside.
- Copy in the shopping list (`requirements.txt`) and install all the helpers.
- Copy in our actual program files (`app/`).
- Switch to a plain, non-boss user for safety.
- Open window (**port**) `5000` and, when the box turns on, start the program with
  `python api.py`.

### Step 3 — Build the lunchbox (the image)

```bash
docker build -t zero2ai-fraud-api:v1.0 .
```

- `docker build` — "follow the recipe and bake an **image**."
- `-t zero2ai-fraud-api:v1.0` — give the image a name (`zero2ai-fraud-api`) and a version tag
  (`v1.0`), like a label on the lunchbox.
- the `.` at the end — "the recipe is in *this* folder."

**What you should see:** lots of steps scrolling by (downloading Python, installing helpers),
ending with something like `naming to ... zero2ai-fraud-api:v1.0` and no errors. The first build
is slow; later builds are much faster because Docker remembers the parts that didn't change.

### Step 4 — Run the lunchbox (start a container)

```bash
docker run -d -p 5000:5000 --name fraud-api zero2ai-fraud-api:v1.0
```

- `docker run` — "open the lunchbox and start it" (this running copy is a **container**).
- `-d` — run it quietly in the background (so your terminal stays free).
- `-p 5000:5000` — connect window 5000 on *your* computer to window 5000 *inside* the box, so
  you can reach it.
- `--name fraud-api` — give this running container a friendly name.

**What you should see:** a long string of letters and numbers (the container's ID). That means
it started.

### Step 5 — Check it's running

```bash
docker ps
```

- `docker ps` lists the lunchboxes that are currently open and running.

**What you should see:** one line showing `fraud-api`, the image name, and `0.0.0.0:5000->5000`.

### Step 6 — Knock on its door

```bash
curl http://localhost:5000/health
```

**What you should see:** the same friendly answer as Chapter 05:

```
{"status":"healthy","ts":"2026-06-16T12:00:00"}
```

🎉 Your fraud front desk is now answering from *inside the lunchbox*. The very same program
would now run identically on any computer that has Docker.

You can also peek at the logbook inside the box:

```bash
docker logs fraud-api
```

### Step 7 — Stop and clean up

When you're done:

```bash
docker stop fraud-api && docker rm fraud-api
```

- `docker stop` closes the running container.
- `docker rm` removes it (the *image* recipe stays, so you can run it again anytime).

### Step 8 — The one-button way (Docker Compose)

Typing all those flags gets old. There's a file, `docker-compose.yml`, that remembers them for
you. From the `chapter-06-docker` folder:

```bash
docker compose up -d      # build + start everything in the background
docker compose down       # stop and clean up
```

**What you should see:** `compose up` builds and starts the container in one go; `curl
http://localhost:5000/health` works exactly the same. `compose down` tidies it all away.

---

## Try it yourself (mini challenges)

- 🔧 **Change the version tag.** Build again with `docker build -t zero2ai-fraud-api:v1.1 .`,
  then run `docker ps` (after starting it) and notice the new `v1.1` label.
- 🔧 **Talk to the boxed model.** With the container running, send a `/predict` request exactly
  like Chapter 05's Step 6. The boxed front desk answers FRAUD or LEGIT just the same.
- 🔧 **List your lunchboxes.** Run `docker images` to see every image you've built, with names
  and tags.
- 🔧 **Watch it self-heal.** Start it with `docker compose up -d`, then `docker stop fraud-api`.
  Wait a moment and run `docker ps` — Compose is set to restart it automatically.

## If something breaks

- **`docker: command not found` or "Cannot connect to the Docker daemon"** → Docker isn't
  installed, or **Docker Desktop isn't open and running**. Open Docker Desktop and wait for the
  whale icon to say it's running, then try again (Step 1).
- **"port is already allocated" / "address already in use"** → Window 5000 is busy. Stop any
  old container (`docker stop fraud-api`) or the Chapter 05 server (Ctrl+C in its terminal),
  then run Step 4 again.
- **`permission denied` while building or running** (common on Linux) → Make sure Docker
  Desktop is running. On Linux you may need to run the command with `sudo`, or ask a helper to
  add your user to the `docker` group.
- **"name fraud-api is already in use"** → A container with that name already exists. Remove it
  with `docker rm -f fraud-api`, then run Step 4 again.
- **The build is very slow the first time** → That's normal. It's downloading Python and the
  helpers once. Later builds reuse them and are quick.

## What you just learned

- **Docker** packs your program *and its helpers* into a sealed **container** so it runs the
  same on any computer.
- A **Dockerfile** is the recipe; building it creates an **image**; running the image creates a
  **container**.
- Key commands: `docker build`, `docker run`, `docker ps`, `docker logs`, `docker stop`,
  `docker rm`.
- **Docker Compose** (`docker compose up -d` / `down`) starts and stops everything with one
  short command.
- The program inside the box is the **same** fraud API you built in Chapter 05 — only now it's
  portable.

## Where to next

➡ [Chapter 07 — Rent a computer with a wish-list (Terraform)](../chapter-07-terraform). You'll
learn how to ask the cloud for a real computer to run your lunchbox on.
