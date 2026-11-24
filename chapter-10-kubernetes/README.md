# Chapter 10 — Run many copies safely (Kubernetes)

> Matches **Chapter 10** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** Easier with a helper the first time

---

## The big idea (in plain words)

Back in Chapter 06 you packed your app into a **container** (a sealed lunchbox that runs the same
anywhere). One lunchbox is fine for a test. But what if it crashes at 3 a.m.? What if a thousand
people show up and one copy can't keep up?

Enter the **traffic controller** — its real name is **Kubernetes** (people shorten it to *k8s*).
Think of it as a playground manager. You tell it: *"Always keep this many copies of my app
running."* It does exactly that — and if a copy falls over, the manager quietly throws it out and
starts a fresh one. No one has to wake up at 3 a.m.

You tell Kubernetes what you want with two small files:

- **`deployment.yaml`** — *how many copies* to run, and how to check each one is still alive.
- **`service.yaml`** — *how visitors reach* a healthy copy (the front desk).

> **Easier with a helper the first time.** Getting Kubernetes running on your own
> laptop is the fiddly part. Once it's set up, the commands are short and friendly. A helper
> nearby for the setup step saves a lot of frustration.

## The platform you are building

A **container platform**: one place where many apps run as many copies, heal themselves, and
grow when they're busy. Almost every large company runs one on Kubernetes, and the people who
build them (**Platform Engineers**, **DevOps Engineers**, **Site Reliability Engineers**) are some
of the most wanted in tech. Every later chapter, from monitoring to AI chatbots, runs on the
platform you start here.

## Your three phases

| Phase | Where it runs | What you do | Cost |
|---|---|---|---|
| **Phase 1 — Build it on your laptop** (this page) | Your computer | Run 2 self-healing copies with Kubernetes on your laptop | Free |
| **Phase 2 — Promote it to the cloud** ([cloud/README.md](cloud/README.md)) | AWS EKS | **2A:** the same YAML in the cloud. **2B:** packaged with Helm | Costs money while it runs |
| **Phase 3 — Run it like a Fortune 500 company** ([cloud/PRODUCTION.md](cloud/PRODUCTION.md)) | AWS EKS | Autoscaling, no-downtime safety nets, security, a shared load balancer, runbooks | Costs money while it runs |

You can stop after Phase 1 and still have learned the whole idea.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Container** — A sealed, packed-up running copy of your app (the "lunchbox").
- **Image** — The recipe/snapshot a container is started from.
- **Kubernetes (k8s)** — A traffic controller that runs many copies of your app and restarts any
  that fall over.
- **Deployment** — The rule that says "always keep this many copies running."
- **Pod** — One running copy (Kubernetes' name for one running container-group).
- **Replica** — One of the many copies. "2 replicas" means "keep 2 copies."
- **Service** — The front desk that sends each visitor to a healthy copy.
- **minikube** — A free tool that runs a tiny Kubernetes on your own laptop, with no cloud bill.

## What you will build

A running pair of files on **your own laptop, for free**:

- A **Deployment** that keeps **2 copies** of the fraud app alive and pokes each one to check
  it's healthy.
- A **Service** (front desk) that gives one steady address forwarding visitors to a healthy copy.

Then you'll do the magic trick: delete a copy on purpose and watch Kubernetes bring it back.

> About 30 minutes. Free: everything runs on your laptop. You need **Docker Desktop**
> (from Chapter 06) and a terminal. On Windows, use **Git Bash** for every command below.

### What's in this folder

Everything this chapter needs is inside `chapter-10-kubernetes/`. You don't need any other
chapter's folder.

```text
chapter-10-kubernetes/
├── README.md          ← you are here (the laptop part)
├── fraud-api/         the app: Python code + Dockerfile (the "lunchbox recipe")
├── deployment.yaml    wish-file 1: keep 2 copies running
├── service.yaml       wish-file 2: the front desk
├── scripts/
│   ├── local-check.sh   is my laptop ready?        (changes nothing)
│   ├── local-up.sh      build + deploy + wait      (safe to run again)
│   ├── local-test.sh    call the app through the front desk
│   └── local-down.sh    remove the app
└── cloud/, helm/, terraform/, PLATFORM.md   the optional AWS track (later, costs money)
```

**Run every command from inside this folder.** Open a terminal and go there first:

```bash
cd path/to/zero-2-ai-systems-engineer/chapter-10-kubernetes
ls          # you should see README.md, deployment.yaml, fraud-api, scripts ...
```

---

## Phase 1 — Build it on your laptop

### Step 1 — Turn on Kubernetes on your laptop

Pick **one** (a helper can confirm which is easiest for you):

- **Option A (recommended) — Docker Desktop's built-in Kubernetes.** Open Docker Desktop →
  **Settings → Kubernetes** → tick **Enable Kubernetes**. If it asks for a **cluster type**,
  choose **kubeadm** (one node, and it can see the images you build, so there's nothing extra
  to do). Click **Apply**, then wait until the Kubernetes icon at the bottom turns green.
  (This takes a few minutes the first time.)
- **Option B — minikube.** Install **minikube** (search "minikube install" for your system),
  then start it:

  ```bash
  minikube start
  ```

`kubectl` (say "cube control") is how you talk to Kubernetes. Check the manager is awake:

```bash
kubectl get nodes
```

**What you should see:** at least one line with status `Ready`.

> This setup step is the fiddly one. If `kubectl get nodes` doesn't show `Ready`, that's
> normal first-time friction — this is the moment a helper helps most. Don't push past it; get
> the node `Ready` before going on.

### Step 2 — Ask "is my laptop ready?"

```bash
bash scripts/local-check.sh
```

**What you should see:** four green [OK] lines and `All good`. Any [ERROR] line tells you exactly what
to fix (for example *"Docker is installed but not running → Open Docker Desktop"*). Fix it and
run the check again. It changes nothing, so run it as often as you like.

> **About the image.** The two wish-files run an app image called `zero2ai-fraud-api:v1.0`.
> You build it in Step 3 from [`fraud-api/`](fraud-api), the same fraud API you packed in
> Chapter 06, copied here so this chapter works on its own.

### Reading the two files (in plain words)

#### `deployment.yaml` — "always keep copies running"

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zero2ai-fraud-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: zero2ai-fraud-api
  template:
    metadata:
      labels:
        app: zero2ai-fraud-api
    spec:
      containers:
      - name: fraud-api
        image: zero2ai-fraud-api:v1.0
        # Use the image you built on your laptop. Never try to download it from
        # the internet (it isn't there), which is what causes ErrImagePull.
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5000
        # Readiness: "is this copy ready for visitors yet?" The front desk only
        # sends traffic to copies that pass this check.
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
        # Liveness: "is this copy still alive?" If not, it is replaced.
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 30
```

Step by step:

1. `kind: Deployment` — "this is the rule about *how many copies* to keep running."
2. `name: zero2ai-fraud-api` — the app's name, so the manager can find it.
3. `replicas: 2` — **always keep 2 copies running.** Each running copy is a **pod**, so you get
   2 pods.
4. The `labels` (`app: zero2ai-fraud-api`) — name tags so the manager knows which copies belong
   together.
5. `image: zero2ai-fraud-api:v1.0` — each copy runs your app from this lunchbox recipe.
6. `imagePullPolicy: IfNotPresent` — "use the image already on this machine." Without it, a
   cluster may try to download `zero2ai-fraud-api:v1.0` from the internet, where it doesn't exist.
7. `containerPort: 5000` — the app listens on door (port) `5000` inside each copy.
8. `readinessProbe` — the **"ready for visitors?"** check. The front desk only sends visitors to
   copies that pass it, so nobody reaches a copy that is still starting up.
9. `livenessProbe` — the **health check**. The manager keeps poking `/health` on port `5000` to
   ask "are you still alive?" It waits 10 seconds before the first knock
   (`initialDelaySeconds: 10`), then knocks every 30 seconds (`periodSeconds: 30`). If a copy
   stops answering, the manager throws it out and starts a fresh one.

**What you get:** two self-healing copies of your app. If one falls, it's replaced
automatically.

#### `service.yaml` — the front desk

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zero2ai-fraud-svc
spec:
  type: NodePort
  selector:
    app: zero2ai-fraud-api
  ports:
  - port: 80
    targetPort: 5000
    nodePort: 30080
```

Step by step:

1. `kind: Service` — "this is the **front desk**."
2. `name: zero2ai-fraud-svc` — the front desk's name.
3. `type: NodePort` — visitors knock on a real door number on the machine. NodePort *is* that
   door number.
4. `selector: app: zero2ai-fraud-api` — only send visitors to *your* app's copies.
5. The ports — inside, the front desk listens on `80` and passes visitors to `5000`
   (`targetPort`) where the app waits. From the outside, visitors knock on door `30080`
   (`nodePort`).

**What you get:** one steady address that always forwards visitors to a healthy copy, even as
copies come and go.

### Step 3 — Run it

#### The quick way (one script does every step)

```bash
bash scripts/local-up.sh      # build the image, hand it to the cluster, deploy, wait for Ready
bash scripts/local-test.sh    # call /health, /info and /predict through the front desk
```

**What you should see:** `local-up.sh` prints `Step 1/5` … `Step 5/5`, then two pods with
`READY 1/1` and `Running`. `local-test.sh` prints three answers from the app and ends with
`[OK] All checks passed.` (The first build downloads Python and libraries: allow a few minutes.)

`local-up.sh` notices which cluster you use. On minikube, kind, and Docker Desktop's multi-node
mode it **loads your image into the cluster** (they have their own private image shelf and
can't see images on your laptop until you hand them over). Run it again any time you change
the app: it rebuilds and swaps in fresh copies.

#### The step-by-step way (the same steps, by hand)

Doing it by hand once is the best way to learn what the script does:

```bash
# 1. Bake the image from the recipe in fraud-api/
docker build -t zero2ai-fraud-api:v1.0 fraud-api

# 2. minikube ONLY: hand the image to minikube (Docker Desktop kubeadm: skip this)
minikube image load zero2ai-fraud-api:v1.0

# 3. Make the wishes real
kubectl apply -f deployment.yaml   # ask for 2 copies
kubectl apply -f service.yaml      # set up the front desk

# 4. Watch them start (press Ctrl+C to stop watching once both say Running 1/1)
kubectl get pods --watch
```

`kubectl apply -f <file>` means "read this wish-file and make it real." Each copy trains its
small model when it starts, so `READY` goes from `0/1` to `1/1` after about 10–20 seconds.

> Using **kind** or Docker Desktop's **multi-node** mode (nodes named `desktop-…`)? Hand the
> image over in step 2 with `kind load docker-image zero2ai-fraud-api:v1.0 --name <cluster>`
> (`--name desktop` for Docker Desktop), or simply use `bash scripts/local-up.sh`.

### Step 4 — Visit the app

Open a **tunnel** from your laptop to the front desk. Leave this running in one terminal:

```bash
kubectl port-forward service/zero2ai-fraud-svc 8080:80
```

**What you should see:** `Forwarding from 127.0.0.1:8080 -> 5000`. It looks stuck: that's
correct, the tunnel stays open until you press Ctrl+C.

In a **second** terminal (also inside `chapter-10-kubernetes`):

```bash
curl http://localhost:8080/health
curl http://localhost:8080/info
curl -X POST http://localhost:8080/predict -H "Content-Type: application/json" \
  -d '{"amount":950.0,"hour":3,"is_weekend":0,"amount_vs_avg":2.8,"is_large_txn":1,"is_late_night":1,"merch_txn_ct":4}'
```

**What you should see:** `{"status":"healthy","ts":"..."}`, then the app's name, then a
prediction such as `"label":"LEGIT"`. You can also open `http://localhost:8080/health` in your
browser while the tunnel is open.

`port-forward` means "connect door `8080` on my laptop to door `80` on the front desk." It works
on Docker Desktop, minikube, kind, **and on a real cloud cluster** (you'll use it again on AWS).
(`curl` knocks on a door from the terminal — you met it back in the API chapter.)

> **Why not `curl http://localhost:30080/health`?** A NodePort opens door `30080` on the
> *cluster's machine*. With **Docker Desktop (kubeadm)**, that machine is your laptop, so
> `localhost:30080` works. With **minikube**, **kind** or Docker Desktop's **multi-node** mode,
> the cluster runs *inside containers*, so door `30080` is on a container, not on your laptop,
> and you get `curl: (7) Failed to connect to localhost port 30080`. Nothing is broken. Use
> port-forward (above), or on minikube ask it for the real address:
>
> ```bash
> minikube service zero2ai-fraud-svc --url   # prints an address; curl <that>/health
> ```
>
> On Windows/macOS with minikube's Docker driver, keep that terminal open: it's a tunnel too.

### Step 5 — See the self-healing trick

```bash
kubectl get pods                       # copy one pod's name from the list
kubectl delete pod <pod-name>          # remove one copy on purpose (paste the name, no < >)
kubectl get pods                       # watch a fresh copy appear in its place
```

For example: `kubectl delete pod zero2ai-fraud-api-65475c495c-4smch`.

You asked for 2 copies. Delete one, and the manager immediately starts another to keep its
promise. That's self-healing, live, on your laptop.

### Step 6 — Scale up (and back down)

```bash
kubectl scale deployment zero2ai-fraud-api --replicas=5   # now keep 5 copies
kubectl get pods                                         # watch 5 appear
kubectl scale deployment zero2ai-fraud-api --replicas=2   # back to 2
```

You just ran many copies of a real app, watched one heal itself, and changed how many run —
all with a few short commands.

### Step 7 — Clean up

```bash
bash scripts/local-down.sh      # same as: kubectl delete -f service.yaml -f deployment.yaml
```

**What you should see:** both items `deleted`, then `Cleaned up.` Your cluster keeps running
with nothing in it. To stop it completely: untick **Enable Kubernetes** in Docker Desktop, or
run `minikube stop`.

---

### Try it yourself (mini challenges)

- **Change the copy count.** In `deployment.yaml`, find the line that sets how many copies run.
  Change `2` to `3`, then run `kubectl apply -f deployment.yaml` again and watch a third copy
  appear.
- **Find the health check.** Which lines make the manager poke your app to see if it's alive?
  Which path and port does it knock on?
- **Find the outside door.** In `service.yaml`, which line sets the door number people outside
  knock on? What would the new `curl` address be if you changed it to `30090`?
- **Watch healing happen.** Delete a pod (`kubectl delete pod <name>`) and immediately run
  `kubectl get pods` a couple of times. Catch the new copy being born.

### If something breaks

**First, run `bash scripts/local-check.sh`.** It finds the most common problems and says how to
fix each one. Then look for your message below.

- **`Cannot connect to the Docker daemon`** or **`docker: command not found`** → Docker Desktop
  isn't running (or isn't installed). Open it and wait for *Engine running*.
- **`kubectl: command not found`** → Kubernetes tools aren't ready. Enable Docker Desktop's
  Kubernetes (Step 1), or install and `minikube start`. (Helper moment.)
- **`The connection to the server … was refused`** or **`kubectl get nodes` shows nothing
  `Ready`** → The local cluster isn't up yet. Wait a minute, or restart it (`minikube start`, or
  toggle Docker Desktop's Kubernetes off and on).
- **`error: the path "deployment.yaml" does not exist`** or **`bash: scripts/local-up.sh: No
  such file or directory`** → You're in the wrong folder. `cd` into `chapter-10-kubernetes`
  ("What's in this folder" above) and try again.
- **Pods stuck in `ErrImagePull` / `ImagePullBackOff` / `ErrImageNeverPull`** → The cluster
  can't find the image `zero2ai-fraud-api:v1.0`. That image lives only in your laptop's Docker,
  so check three things:
  1. `kubectl config current-context`: if it shows `arn:aws:eks:…`, you're talking to the
     **cloud** cluster (running `platform-up.sh` switches you there), and it can't see your laptop.
     Remove the local copy with `kubectl delete -f deployment.yaml -f service.yaml`, then switch
     back with `kubectl config use-context docker-desktop` (or `minikube` / `kind-<name>`).
  2. `docker images zero2ai-fraud-api`: if `v1.0` isn't listed, build it:
     `docker build -t zero2ai-fraud-api:v1.0 fraud-api`.
  3. On minikube, kind, or Docker Desktop's multi-node mode (`kubectl get nodes` shows
     `desktop-control-plane` / `desktop-worker`), hand the image over:
     `minikube image load zero2ai-fraud-api:v1.0`, or
     `kind load docker-image zero2ai-fraud-api:v1.0 --name <cluster>` (`desktop` for Docker
     Desktop). Easier: switch Docker Desktop's cluster type to **kubeadm** (Step 1).

  Then run `kubectl rollout restart deployment zero2ai-fraud-api`. Or simply run
  `bash scripts/local-up.sh`, which does all of this for you.
- **Pods show `CrashLoopBackOff`** → The app starts and then crashes. Read its last words with
  `kubectl logs deployment/zero2ai-fraud-api`, then rebuild with `bash scripts/local-up.sh`.
- **Pods show `0/1 READY` for a while, or port-forward says `unable to forward port`** → The
  copies aren't healthy yet. The app trains its model at startup, so give it 10–20 seconds and
  check again with `kubectl get pods`.
- **port-forward says `address already in use`** → Something else on your laptop uses door 8080.
  Use another door: `kubectl port-forward service/zero2ai-fraud-svc 8090:80`, then
  `curl http://localhost:8090/health`. (`local-test.sh` picks a free door by itself.)
- **`curl: (7) Failed to connect to localhost port 30080`** → Expected on minikube, kind, and
  Docker Desktop's multi-node mode (see the box in Step 4). Use port-forward instead.
- **`curl: (7) Failed to connect to localhost port 8080`** → The tunnel isn't open. Start
  `kubectl port-forward …` in another terminal first and leave it running.
- **`local-up.sh: line NN: syntax error near unexpected token`** → Your copy of the script got
  damaged, usually from being pasted through a word processor (curly “quotes”) or saved with
  Windows line endings. Get a clean copy: `git checkout -- scripts/` then `git pull`.
- **`kubectl logs` shows `WARNING: This is a development server`** → Normal. Flask's built-in
  server is fine for learning; the cloud track's Phase 3 swaps in a production server (gunicorn).
- **`curl` hangs on Windows Git Bash** → Try `curl.exe http://localhost:8080/health`, or open
  that address in your browser.
- **YAML error on `apply`** → Indentation again — two spaces per level, never tabs. Compare to
  the examples above.

### What you learned in Phase 1

- **Kubernetes** is a traffic controller / playground manager: it runs many copies and restarts
  any that fall over.
- A **Deployment** sets *how many copies* (replicas) to keep alive and how to **health-check**
  each one.
- A **Service** is the **front desk** that forwards every visitor to a healthy copy.
- A **pod** is one running copy; **self-healing** means deleted or crashed copies come back on
  their own.
- You can run a real, multi-copy, self-healing app **free on your own laptop** with Docker
  Desktop's Kubernetes or **minikube** — no cloud bill.
- `kubectl apply`, `get pods`, `delete pod`, and `scale` are the everyday commands.
- `kubectl port-forward` is the tunnel that reaches a Service from your laptop on **any** cluster.

## Phase 2 and Phase 3 — Take it to the cloud

You just ran the app on your laptop. Next, run the *same* thing on **AWS EKS** (Amazon's
managed Kubernetes), built with **Terraform** and deployed with **Helm**:

1. Build the shared cloud platform once: **[PLATFORM.md](PLATFORM.md)**.
2. **Phase 2 — Promote it to the cloud:** **[cloud/README.md](cloud/README.md)**.
3. **Phase 3 — Run it like a Fortune 500 company:** **[cloud/PRODUCTION.md](cloud/PRODUCTION.md)**.

> **Costs money.** An EKS cluster costs roughly **$0.10/hour** plus servers and a load
> balancer. Get permission if the account isn't yours, and **destroy everything when you
> finish** (every guide ends with a one-line teardown).

## Where to next

[Chapter 11 — Watch your program's health (Monitoring)](../chapter-11-monitoring). Now that many
copies are running, you'll learn to watch their health on charts you can glance at any time.
