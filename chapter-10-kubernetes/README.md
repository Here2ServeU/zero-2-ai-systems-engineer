# Chapter 10 — Kubernetes and Orchestration

**Book:** Chapter 10 (Kubernetes and Orchestration) · Lab 10.3
**Layer:** 5 · Automation & Orchestration · **You build:** Self-healing, scalable deployment

## What you build

A Kubernetes Deployment (2 replicas, liveness probe) and a NodePort Service for the
fraud API image from Chapter 6. Same manifests work on Docker Desktop K8s, Minikube, EKS,
AKS, or GKE.

## Run

```bash
# Enable Kubernetes (Docker Desktop) or: minikube start
kubectl get nodes

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl get pods            # expect 2 Running
curl http://localhost:30080/health

# Self-healing + scaling
kubectl delete pod <pod-name>      # watch it get replaced
kubectl scale deployment nawex-fraud-api --replicas=5
```

> The image `nawex-fraud-api:v1.0` must be available to the cluster (built in Chapter 6;
> on Docker Desktop set `imagePullPolicy: IfNotPresent` or push to a registry).

## What each file does (explained for absolute beginners)

Think of the computer as a friend who only does *exactly* what you tell it. A script
is just a list of instructions you hand to that friend, one line at a time. These two
files are the rules you hand to a playground manager named Kubernetes.

Kubernetes (people call it k8s for short) is like a playground manager. It runs many
copies of your app and quickly restarts any copy that falls down, so your app almost
never goes dark.

### `deployment.yaml` — the rule that says "always keep copies running"

**In one sentence:** This file tells the playground manager to always keep two copies of
your fraud app running, and to poke each one to make sure it is still alive.

**What it does, step by step:**

1. **Says what kind of rule this is.** `kind: Deployment` means "this is the rule about
   how many copies to keep running." A deployment is just that promise: always keep this
   many copies up.
2. **Gives it a name.** It calls the app `nawex-fraud-api` so the manager can find it.
3. **Asks for two copies.** `replicas: 2` means "always keep 2 copies running." Each
   running copy is called a pod. So you get 2 pods.
4. **Tags the copies.** It labels each copy `app: nawex-fraud-api` so the manager knows
   which pods belong together.
5. **Says what to run inside each copy.** Each pod runs a container (a sealed lunchbox with
   your app inside) built from the picture `nawex-fraud-api:v1.0`.
6. **Opens a door on the app.** The app listens on port `5000` inside the pod.
7. **Sets up a health check.** The liveness probe is the manager poking your app to ask
   "are you still alive?" It knocks on the `/health` path on port `5000`. It waits 10
   seconds before the first knock (`initialDelaySeconds: 10`) and then knocks every 30
   seconds (`periodSeconds: 30`). If a copy stops answering, the manager throws it out and
   starts a fresh one.

**What you get:** Two copies of your app that stay running on their own — if one falls
down, the playground manager replaces it without you lifting a finger.

### `service.yaml` — the front desk that sends visitors to a healthy copy

**In one sentence:** This file sets up a front desk that takes every visitor and sends them
to one of the healthy copies of your app.

**What it does, step by step:**

1. **Says what kind of thing this is.** `kind: Service` means "this is the front desk."
   A service is the front desk that sends visitors to a healthy copy.
2. **Gives it a name.** It calls the front desk `nawex-fraud-svc`.
3. **Picks the door type.** `type: NodePort` means visitors knock on a real door number on
   the machine. NodePort is just that door number.
4. **Points to the right copies.** It uses the label `app: nawex-fraud-api` so the front
   desk only sends people to your app's pods.
5. **Sets the doors and routing.** Inside the cluster the front desk listens on port `80`
   and passes visitors to port `5000` (`targetPort`) where the app is listening. From the
   outside world, visitors knock on door number `30080` (`nodePort`).

**What you get:** One steady front-desk address (door `30080`) that always forwards
visitors to a healthy copy of your app, even as copies come and go.

➡ Next: [chapter-11-monitoring](../chapter-11-monitoring) — instrument with Prometheus.
