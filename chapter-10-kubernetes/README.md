# Chapter 10 — Run many copies safely (Kubernetes)

> Matches **Chapter 10** in the book. The runnable scripts for this chapter are in this folder.

**Labels:** 🧑‍🤝‍🧑 Easier with a helper the first time

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

> 🧑‍🤝‍🧑 **Easier with a helper the first time.** Getting Kubernetes running on your own
> laptop is the fiddly part. Once it's set up, the commands are short and friendly. A helper
> nearby for the setup step saves a lot of frustration.

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

---

## The free way to try this on your laptop (no cloud bill)

You don't need to rent anything. You can run a tiny Kubernetes right on your computer. Pick
**one** of these (a helper can confirm which is easiest for you):

- **Option A — Docker Desktop's built-in Kubernetes.** If you installed Docker Desktop in Chapter
  06, open its **Settings → Kubernetes** and tick **Enable Kubernetes**. Wait for it to turn
  green. Done.
- **Option B — minikube.** Install **minikube** (search "minikube install" for your system),
  then start it:

  ```bash
  minikube start
  ```

Either way, check the manager is awake:

```bash
kubectl get nodes
```

**What you should see:** at least one line with status `Ready`. `kubectl` (say "cube control")
is how you talk to Kubernetes.

> ⚠️ This setup step is the fiddly one. If `kubectl get nodes` doesn't show `Ready`, that's
> normal first-time friction — this is the moment a helper helps most. Don't push past it; get
> the node `Ready` before going on.

> 📦 **About the image.** These files run an app image called `zero2ai-fraud-api:v1.0`, built back
> in Chapter/Chapter 06. On a local cluster, make sure that image is available to it (on Docker
> Desktop, having built it locally is usually enough). If you haven't built it, you can still
> read along and learn what each file does.

## Reading the two files (in plain words)

### `deployment.yaml` — "always keep copies running"

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
        ports:
        - containerPort: 5000
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
6. `containerPort: 5000` — the app listens on door (port) `5000` inside each copy.
7. `livenessProbe` — the **health check**. The manager keeps poking `/health` on port `5000` to
   ask "are you still alive?" It waits 10 seconds before the first knock
   (`initialDelaySeconds: 10`), then knocks every 30 seconds (`periodSeconds: 30`). If a copy
   stops answering, the manager throws it out and starts a fresh one.

**What you get:** two self-healing copies of your app. If one falls, it's replaced
automatically.

### `service.yaml` — the front desk

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

## Let's run it

With your node showing `Ready`, run these one at a time:

```bash
kubectl apply -f deployment.yaml   # ask for 2 copies
kubectl apply -f service.yaml      # set up the front desk
kubectl get pods                   # expect 2 copies, status "Running"
```

`kubectl apply -f <file>` means "read this wish-file and make it real." Then visit the app
through the front desk:

```bash
curl http://localhost:30080/health
```

(`curl` knocks on a door from the terminal — you met it back in the API chapter.)

### See the self-healing trick

```bash
kubectl get pods                       # copy one pod's name from the list
kubectl delete pod <pod-name>          # remove one copy on purpose
kubectl get pods                       # watch a fresh copy appear in its place
```

You asked for 2 copies. Delete one, and the manager immediately starts another to keep its
promise. That's self-healing, live, on your laptop.

### Scale up (and back down)

```bash
kubectl scale deployment zero2ai-fraud-api --replicas=5   # now keep 5 copies
kubectl get pods                                         # watch 5 appear
kubectl scale deployment zero2ai-fraud-api --replicas=2   # back to 2
```

🎉 You just ran many copies of a real app, watched one heal itself, and changed how many run —
all with a few short commands.

---

## Try it yourself (mini challenges)

- 🔧 **Change the copy count.** In `deployment.yaml`, find the line that sets how many copies run.
  Change `2` to `3`, then run `kubectl apply -f deployment.yaml` again and watch a third copy
  appear.
- 🔧 **Find the health check.** Which lines make the manager poke your app to see if it's alive?
  Which path and port does it knock on?
- 🔧 **Find the outside door.** In `service.yaml`, which line sets the door number people outside
  knock on? What would the new `curl` address be if you changed it to `30090`?
- 🔧 **Watch healing happen.** Delete a pod (`kubectl delete pod <name>`) and immediately run
  `kubectl get pods` a couple of times. Catch the new copy being born.

## If something breaks

- **`kubectl: command not found`** → Kubernetes tools aren't ready. Enable Docker Desktop's
  Kubernetes, or install and `minikube start`. (Helper moment.)
- **`kubectl get nodes` shows nothing `Ready`** → The local cluster isn't up yet. Wait a minute,
  or restart it (`minikube start`, or toggle Docker Desktop's Kubernetes off and on).
- **Pods stuck in `ErrImagePull` / `ImagePullBackOff`** → The cluster can't find the image
  `zero2ai-fraud-api:v1.0`. Build it locally (Chapter 06) so the local cluster can see it.
- **`curl: ... Connection refused` on port 30080** → Give the pods a few seconds to reach
  `Running`, and confirm the Service was applied: `kubectl get service`.
- **YAML error on `apply`** → Indentation again — two spaces per level, never tabs. Compare to
  the examples above.

## What you just learned

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

## Where to next

➡ [Chapter 11 — Watch your program's health (Monitoring)](../chapter-11-monitoring). Now that many
copies are running, you'll learn to watch their health on charts you can glance at any time.
