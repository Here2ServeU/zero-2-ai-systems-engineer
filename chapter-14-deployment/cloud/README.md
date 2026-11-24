# Chapter 14 — Phase 2: Promote it to the cloud (AWS EKS)

> In Phase 1, `switch.py` flipped a word in memory, and you ran blue and green copies of the
> fraud API in Docker, picking the door (5001 or 5002) by hand. Now the cloud moves **real
> traffic** for you, in two small steps: **2A** uses plain YAML and one Kubernetes switch, then
> **2B** does the same with Helm, so every switch is recorded and can be undone with one
> command. Phase 3 ([PRODUCTION.md](PRODUCTION.md)) adds a real canary split and automatic
> rollback.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

1. **Finish Phase 1** ([../README.md](../README.md)). Everything here builds on it.
2. **Build the shared cloud platform once:**
   [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).
3. **Costs money.** The platform costs roughly **$0.10/hour** plus servers. Phase 2A also asks
   AWS for its own network load balancer (about $0.025/hour) while it runs. Get permission if
   the AWS account isn't yours, and **tear everything down when you finish** (see "Clean up" at
   the bottom).

**Run every command on this page from this folder:**

```bash
cd chapter-14-deployment/cloud
```

## What changes from your laptop to the cloud

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| `docker build` on your laptop | The image is pushed to **ECR**, your private image shelf in AWS | Cloud servers can't see your laptop |
| One copy of blue, one of green, on doors 5001 and 5002 | **2 copies** of blue and **2 copies** of green | One copy crashing never takes a color down |
| You picked the door for every visit | One **Service** (front desk) with one address. Its **selector** ("send visitors to pods labeled `color: blue`") decides who answers | Real users all use one address |
| `switch.py` changed a word in memory | `switch.sh` changes the Service's selector: **all** traffic moves at once | The switch works for every user, instantly |
| `rollback()` in Python | Switch back to blue (2A), or `helm rollback` (2B) | The fast way back is one command |
| `-e APP_COLOR=green` | The same settings, written in YAML (2A) or Helm values (2B) | Settings are saved in files, not typed by hand |

## New words

- **Selector** — The label a Service looks for to decide which pods get visitors. Change the
  selector, and the traffic moves.
- **Label** — A sticky note on a pod, like `color: blue`.
- **Release** — One installed copy of a Helm chart. Here there are three: `fraud-blue`,
  `fraud-green` and `fraud-router`.
- **Revision** — Every change to a Helm release gets the next number (1, 2, 3, ...). You can roll
  back to any earlier number.
- **port-forward** — A private tunnel from your laptop to something inside the cluster.

## Step 0 — Build the image and push it to ECR

```bash
bash deploy.sh build
```

This builds Chapter 10's fraud API ([`../../chapter-10-kubernetes/fraud-api`](../../chapter-10-kubernetes/fraud-api)),
the same image you ran as blue and green in Phase 1 Step 6, for `linux/amd64` (the kind of
computer EKS uses, even on a newer Mac), and pushes it to ECR. Blue and green both use this one
image; only their settings differ.

**What you should see:** `[OK] Pushed ...zero2ai-dev/fraud-api:3f9c2ab` (the last part is your
git commit).

---

## Phase 2A — Blue/green with plain YAML

Three plain files in [`phase2a-yaml/`](phase2a-yaml):

| File | What it is |
|---|---|
| [`deployment-blue.yaml`](phase2a-yaml/deployment-blue.yaml) | 2 copies labeled `app: fraud-bg, color: blue`, with `APP_VERSION=1.0.0`, `APP_COLOR=blue` |
| [`deployment-green.yaml`](phase2a-yaml/deployment-green.yaml) | 2 copies labeled `color: green`, with `APP_VERSION=2.0.0`, `APP_COLOR=green` |
| [`service.yaml`](phase2a-yaml/service.yaml) | The front desk `fraud-live-p1`, with a public AWS load balancer. Its selector says `color: blue` |

```bash
bash deploy.sh 2a
bash test.sh 2a
```

**What you should see:** `deploy.sh 2a` waits for both colors and ends with
`[OK] Phase 2A: blue and green running, traffic on BLUE. Test: bash test.sh 2a`. `test.sh 2a`
visits `/info` 10 times through a port-forward, then waits for the public load balancer (the
first time takes 2 to 4 minutes) and visits 10 more times:

```
Out of 10 visits: blue=10 green=0
==> Public NLB: http://k8s-zero2ai-fraudliv-....elb.us-east-1.amazonaws.com
Out of 10 visits: blue=10 green=0
Now flip it: bash switch.sh 2a green   then run this test again.
[OK] Phase 2A checks passed
```

Green is running and healthy, but gets **no** visitors. Now flip the switch, test, and flip it
back:

```bash
bash switch.sh 2a green
bash test.sh 2a
bash switch.sh 2a blue
```

**What you should see:** `switch.sh` prints `[OK] Traffic now goes to green`. The next test shows
`blue=0 green=10`. Switching back to blue is your **rollback**: one command, and everyone is on
the old version again.

> The port-forward count changes at once. The public load balancer needs about a minute to
> register the new copies, so its count may be short (for example `blue=0 green=7`) right after a
> switch. Run `bash test.sh 2a` again after a minute.

Explore it yourself:

```bash
kubectl -n zero2ai get pods -l app=fraud-bg -L color          # 4 pods, with a COLOR column
kubectl -n zero2ai get svc fraud-live-p1 -o wide              # the SELECTOR column shows the live color
kubectl -n zero2ai get endpointslices -l kubernetes.io/service-name=fraud-live-p1   # IPs of the pods getting traffic now
```

---

## Phase 2B — Blue/green with Helm

The same idea, as three releases of Chapter 10's shared chart
([`zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app)):

| Release | Values file | Has pods? |
|---|---|---|
| `fraud-blue` | [`phase2b-helm/blue.yaml`](phase2b-helm/blue.yaml) | yes: 2 copies of v1.0.0 |
| `fraud-green` | [`phase2b-helm/green.yaml`](phase2b-helm/green.yaml) | yes: 2 copies of v2.0.0 |
| `fraud-router` | [`phase2b-helm/router.yaml`](phase2b-helm/router.yaml) | **no**: only a Service, whose selector picks a color |

Splitting the **router** from the colors means you can switch traffic without touching either
version, and every switch becomes a numbered Helm revision.

```bash
bash deploy.sh 2b
bash test.sh 2b
```

**What you should see:** `deploy.sh 2b` removes the 2A files, installs the three releases, and
ends with `[OK] Phase 2B deployed: blue and green running, router on BLUE. Test: bash test.sh 2b`.
`test.sh 2b` ends with:

```
[OK] helm test fraud-blue
[OK] helm test fraud-green
[OK] helm test fraud-router
Out of 10 visits: blue=10 green=0
Now flip it: bash switch.sh 2b green   (undo: helm rollback fraud-router -n zero2ai)
[OK] Phase 2B checks passed
```

Now switch to green, test, and roll back **with Helm**:

```bash
bash switch.sh 2b green
bash test.sh 2b
helm rollback fraud-router -n zero2ai
bash test.sh 2b
```

**What you should see:** `switch.sh` shows the router's last revisions and
`[OK] Traffic now goes to green`, and the next test says `blue=0 green=10`. `helm rollback`
prints `Rollback was a success! Happy Helming!`, and the last test is back to `blue=10 green=0`.

See the whole story of your switches:

```bash
helm history fraud-router -n zero2ai
```

**What you should see:** one line per change: `install`, `upgrade` (your switch to green),
`Rollback to 1`. That list is an **audit trail**: who changed what, and when.

### Useful commands to explore

```bash
helm list -n zero2ai                                            # the three releases and their revisions
helm get values fraud-router -n zero2ai                         # which color the router points at
kubectl -n zero2ai get pods -L zero2ai-color                     # blue and green pods side by side
kubectl -n zero2ai port-forward svc/fraud-router 8080:80         # then: curl http://localhost:8080/info
```

### Try it yourself: a feature flag on Kubernetes

A feature flag on Kubernetes is just a setting. Change one on green without rebuilding the
image, look at it, then undo it:

```bash
helm upgrade fraud-green ../../chapter-10-kubernetes/helm/zero2ai-app -n zero2ai --reuse-values --set env.APP_VERSION=2.1.0 --wait
kubectl -n zero2ai port-forward svc/fraud-green 8081:80
```

In a second terminal: `curl http://localhost:8081/info`. **What you should see:**
`"version":"2.1.0"`. Press Ctrl+C in the first terminal, then undo it with
`helm rollback fraud-green -n zero2ai`. Every flag change is recorded in `helm history`, so it
can be rolled back like anything else.

---

## If something breaks

- **`[ERROR] Cluster zero2ai-eks-dev not found`** → The shared platform isn't built (or was torn
  down). Run `bash ../../chapter-10-kubernetes/scripts/platform-up.sh dev` first.
- **`[ERROR] No image recorded for 'fraud-api'`** → Run `bash deploy.sh build` first.
- **Pods show `ImagePullBackOff`** → The image isn't in ECR for this environment. Run
  `bash deploy.sh build` again, then the `deploy.sh` step you were on.
- **`test.sh 2a` stops at `No load balancer address yet` or `is not answering`** → New AWS load
  balancers take a few minutes, and their DNS name a bit longer. Wait 2 minutes and run
  `bash test.sh 2a` again. Still stuck? `kubectl -n zero2ai describe svc fraud-live-p1` shows
  the reason under `Events`.
- **The count shows `blue=0 green=0`** → Every visit failed. Check the pods are `Running` and
  `1/1`: `kubectl -n zero2ai get pods -L zero2ai-color,color`.
- **`switch.sh 2a` says `services "fraud-live-p1" not found`** → You're in Phase 2B, or the 2A
  files were removed. Use `bash switch.sh 2b green`, or run `bash deploy.sh 2a` first.
- **`switch.sh 2b` says `Error: UPGRADE FAILED: "fraud-router" has no deployed releases`** →
  Phase 2B isn't installed. Run `bash deploy.sh 2b` first.
- **`helm rollback` says `release has no 0 version`** or rolls back to the wrong one → Pick the
  revision yourself: `helm history fraud-router -n zero2ai`, then
  `helm rollback fraud-router <number> -n zero2ai`.
- **`port-forward` says `address already in use`** → Something on your laptop already uses that
  door. Pick another, for example `8090:80`, and curl that one.

## Clean up

```bash
bash down.sh                                                   # remove this chapter's apps
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # when you're done for the day
```

**What you should see:** `[OK] Chapter 14 removed`. Removing the 2A Service also removes its
load balancer, so it stops costing money.

## Next: Phase 3

You can switch everyone at once and undo it in one command. Now let the load balancer send just
10% to green, grow it step by step, and watch Helm undo a broken release by itself. Go to
**[PRODUCTION.md](PRODUCTION.md)**.
