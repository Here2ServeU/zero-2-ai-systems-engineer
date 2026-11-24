# Chapter 14 — Phase 3: Run it like a Fortune 500 company

> Phase 2 could move **all** traffic at once and undo it in one command. Phase 3 releases the
> way big companies do: the load balancer sends just **10%** of real visitors to the new
> version, you grow that slice step by step, and a release that can't start is **rolled back
> automatically** before anyone notices. Both colors also get Chapter 10's production safety
> nets.

**Labels:** Needs an account that may cost money · Needs the internet

---

## Before you start

- Finish Phase 2 ([README.md](README.md)), with the platform still running.
- Run every command from this folder: `cd chapter-14-deployment/cloud`.

## Deploy and test Phase 3

```bash
bash deploy.sh 3
bash test.sh 3
```

**What you should see:** `deploy.sh 3` upgrades `fraud-blue`, `fraud-green` and `fraud-router`
and ends with `[OK] Phase 3 deployed: blue and green running, router on BLUE. Test: bash test.sh 3`.
(The router's own Service still points at blue. Public traffic now goes through the load
balancer's 90/10 split instead.)

`test.sh 3` waits for the shared **platform ALB** on port **8014** (the first time takes 2 to 4
minutes), visits `/info` 40 times, and prints the split the ALB is using:

```
==> Public ALB: http://k8s-zero2ai-....us-east-1.elb.amazonaws.com:8014  (canary split)
Out of 40 visits: blue=36 green=4
{"type":"forward","forwardConfig":{"targetGroups":[{"serviceName":"fraud-blue","servicePort":"80","weight":90},{"serviceName":"fraud-green","servicePort":"80","weight":10}]}}
Shift traffic: bash canary.sh 50   |   Demo auto-rollback: bash deploy.sh broken
[OK] Phase 3 checks passed
```

The split is random per visit, just like `router.py`, so you may see `blue=37 green=3` or
`blue=33 green=7`. You can also open `http://<that address>:8014/info` in your browser and
refresh it a few times, or run `bash ../../chapter-10-kubernetes/scripts/urls.sh` to list every
address.

### Grow the canary, step by step

```bash
bash canary.sh 50      # half and half
bash test.sh 3
bash canary.sh 100     # everyone on green: the release is finished
bash test.sh 3
bash canary.sh 0       # instant rollback: everyone back on blue
bash test.sh 3
```

**What you should see:** each `canary.sh` ends with a line like
`[OK] ALB now sends 50% to green, 50% to blue (takes ~10 s to apply)`, and the following test
shows the new split: about `blue=20 green=20`, then `blue=0 green=40`, then `blue=40 green=0`.
Notice that rollback was just `canary.sh 0`: green was never switched off, so going back needed
no new pods, only a new weight.

> In Phase 3 the public load balancer does the splitting, so `canary.sh` is the switch to use.
> `switch.sh 3 <color>` still works, but it only moves the router's *internal* Service.

### Watch Helm undo a broken release by itself

```bash
bash deploy.sh broken
```

This ships a green that **can't start** (its command points at a file that doesn't exist), with
`helm upgrade --atomic --timeout 3m`.

**What you should see:** after about 3 minutes, Helm reports
`Error: UPGRADE FAILED: release fraud-green failed, and has been rolled back due to atomic being set`,
then the script prints `[OK] Helm detected the failure and rolled green back automatically:` and
the release history, with a `failed` revision followed by a `Rollback to ...` revision that is
`deployed`.

While you wait, watch it from a second terminal:

```bash
kubectl -n zero2ai get pods -L zero2ai-color -w
```

**What you should see:** one new green pod going into `CrashLoopBackOff`, while the old green
pods and all blue pods stay `Running`. The chart's update rule (`maxUnavailable: 0`) never removes
a working copy before its replacement is healthy, so nobody gets an error. Press Ctrl+C to stop
watching. Run `bash test.sh 3` afterwards: it still passes.

## What changes in production, and why

Everything below is in [`phase3-production/app.yaml`](phase3-production/app.yaml) (for both
colors), [`phase3-production/router.yaml`](phase3-production/router.yaml), and the `3)` and
`broken)` steps of [`deploy.sh`](deploy.sh), on top of the Phase 2B files.

| Setting | What it does | Why production needs it |
|---|---|---|
| `ingress.weighted` in `router.yaml` (start: `canaryWeight: 10`) | The ALB itself splits visits by weight between the `fraud-blue` and `fraud-green` Services | A real **canary**: only 10% of users can be hurt by a bad release |
| `ingress.port: 8014`, `healthcheckPath: /health` | The router joins the shared platform ALB on its own port, and the ALB checks every copy's `/health` | One stable public address, no extra load balancer to pay for, and unhealthy copies get no traffic |
| `canary.sh <0-100>` | `helm upgrade fraud-router --reuse-values --set ingress.weighted.canaryWeight=<n>` | Every traffic change is a numbered Helm revision, so it's recorded and can be undone |
| `--atomic` on both colors (and in `deploy.sh broken`) | If an upgrade doesn't become healthy in time, Helm rolls back by itself | A broken release undoes itself, even at 3 a.m. |
| Chart default `maxSurge: 1`, `maxUnavailable: 0` | A new copy must be healthy before an old one is removed | Updates never reduce how many copies are serving |
| `command: gunicorn ...` | A real web server: 2 processes x 4 threads per copy | Flask's built-in server is for practice only |
| `resources` | Each copy asks for 250m CPU and 384Mi memory, and may never use more than 768Mi | The cloud can place copies safely; one copy can't eat a whole server |
| `autoscaling` (HPA) | 2 to 6 copies of **each** color, aiming for 70% CPU | If green gets 100% of traffic, it grows to handle it |
| `pdb.enabled` | At least 1 copy of each color stays up during server upgrades | Node maintenance can't take a color down |
| `topologySpread` | Spreads each color's copies across zones and servers | One data center going dark doesn't take a color down |
| `networkPolicy` (+ the VPC range from `deploy.sh`) | Only the ALB and pods in this namespace may connect to the colors | Limits the damage if something else is broken into |
| Chart security settings | Non-root user, read-only disk, no extra Linux powers, no Kubernetes API token | Hardening; passes the Kubernetes "restricted" security level |

**Honest limits** (not built here):

- **The canary grows by hand.** You run `canary.sh 50` when *you* think green looks fine. At work,
  a tool such as **Argo Rollouts** or **Flagger** grows the slice automatically and rolls back on
  its own if green's error rate or speed gets worse.
- **"Healthy" means `/health` answers.** `--atomic` catches a release that can't start, but not
  one that starts fine and gives wrong answers. That needs metrics and alerts (Chapter 11) and
  dashboards (Chapter 15).
- **Blue and green run the same code.** Only `APP_VERSION` and `APP_COLOR` differ, so you can see
  who answered. In real life green would be a new image tag, for example with a new model from
  Chapter 13.
- **No HTTPS yet.** The chart supports it (`ingress.host` + `ingress.certificateArn`) once you
  have your own domain and certificate.

## How big companies run this

Big companies add a few habits on top of the settings above. Each one is labeled **built in**
(this chapter really does it) or **how you'd extend it at work**.

### 1. Decide with numbers: SLIs, SLOs and error budgets (how you'd extend it at work)

- An **SLI** (service level indicator) is a number that shows if users are happy, like "the
  percentage of `/predict` calls that succeed" or "calls that answer in under 300 ms".
- An **SLO** (service level objective) is the promise, like "99.9% of calls succeed each month".
- The **error budget** is the 0.1% you're allowed to fail. Release teams use it as a traffic
  light: budget left means keep releasing; budget used up means freeze releases and fix
  reliability first.
- During a canary, you compare green's SLIs with blue's. Green only gets more traffic if its
  numbers are as good as blue's. This chapter does that comparison by eye with `test.sh 3`.

### 2. Safe change (built in)

This is the heart of the chapter: blue/green (Phase 2), a weighted canary (`canary.sh`),
automatic rollback (`--atomic`), rollback by hand (`canary.sh 0`, `helm rollback`), and updates
that never drop a working copy (`maxUnavailable: 0`). At work you'd add automatic canary
analysis (Argo Rollouts or Flagger) and **feature flags** from a flag service, so a feature can
be switched off in seconds without any release at all.

### 3. Alerting and a runbook (how you'd extend it at work)

A **runbook** is a recipe that anyone on call can follow at 3 a.m. Here is one for a bad canary:

| | Canary looks bad |
|---|---|
| **Alert** | Green's errors or slow answers rise after `canary.sh` raised its share (at work, a Prometheus alert from Chapter 11 would fire) |
| **What it means** | The new version is hurting the slice of users it serves |
| **First 3 commands** | `bash canary.sh 0` (stop the bleeding: everyone back on blue) · `kubectl -n zero2ai get pods -L zero2ai-color` · `kubectl -n zero2ai logs deployment/fraud-green --tail=50` |
| **How to fix** | Find the bug in green's logs, fix it, ship a new green (`bash deploy.sh 3`), then start again at `bash canary.sh 10`. A failed green upgrade already rolled itself back? See why with `helm history fraud-green -n zero2ai` and `kubectl -n zero2ai get events --sort-by=.lastTimestamp \| tail -20` |

Notice the order: **roll back first, investigate second**. Users come before curiosity.

### 4. Security (built in)

Non-root containers, read-only disks, no extra Linux powers, no Kubernetes API token in the
pods, and a NetworkPolicy that only lets the load balancer and this namespace in. At work you'd
also turn on HTTPS, limit who may reach the ALB port (`ingress.allowedCidrs`), and scan every
image before it's allowed to become green.

### 5. Reliability (built in)

Two or more copies of each color, spread across zones, an autoscaler, a disruption budget, and
ALB health checks. Because blue stays fully running during a canary, rollback needs no new pods
and takes seconds.

### 6. Cost control, or "FinOps" (partly built in)

Blue/green means paying for **two** full versions while a release is in progress. That's the
price of an instant rollback. Teams keep it small by shrinking or removing the old color once the
new one has had 100% of traffic for a while (for example a day). Here, the autoscaler already
shrinks a color with little traffic down to its minimum of 2 copies, and one shared ALB serves
every chapter. **Your biggest saving: tear the platform down when you're not using it.**

### 7. Audit and compliance (built in)

Every release and every traffic change is a numbered Helm revision with a time stamp:
`helm history fraud-router -n zero2ai` shows each canary step, and
`helm history fraud-green -n zero2ai` shows the failed release and its automatic rollback. Banks
and hospitals must be able to show exactly what changed, and when. At work you'd also record
*who* approved each step (for example a pull request in GitHub, Chapter 09) and link it to the
change ticket.

## Production readiness checklist

Tick each box by running the command next to it, from `chapter-14-deployment/cloud`.

- [ ] Both colors have at least 2 Ready copies: `kubectl -n zero2ai get deploy fraud-blue fraud-green`
- [ ] The canary split is set on the load balancer: `kubectl -n zero2ai get ingress fraud-router -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/actions\.weighted-routing}{"\n"}'` shows two weights that add up to 100
- [ ] Real visitors see the split: `bash test.sh 3`
- [ ] You can move the canary and roll it back: `bash canary.sh 10`, then `bash canary.sh 0`
- [ ] Each color has an autoscaler: `kubectl -n zero2ai get hpa`
- [ ] Each color has a disruption budget: `kubectl -n zero2ai get pdb`
- [ ] Network access is limited: `kubectl -n zero2ai get networkpolicy`
- [ ] A broken release undoes itself: `bash deploy.sh broken` ends with `[OK] Helm detected the failure ...`
- [ ] Every change is recorded: `helm history fraud-router -n zero2ai` shows more than one revision
- [ ] You know how to turn it all off: `bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev`

## Career corner

What you just built is what **Release Engineers**, **DevOps Engineers**, **Site Reliability
Engineers** and **Platform Engineers** do every day. You can now answer interview questions like:

1. What's the difference between a blue/green release and a canary release, and when would you
   pick each?
2. How does a Kubernetes Service decide which pods get traffic, and how can you use that to switch
   versions instantly?
3. What does `helm upgrade --atomic` do when a release fails, and what can it *not* catch?
4. Why set `maxUnavailable: 0` in a rolling update?
5. What is an error budget, and how would you use it to decide whether to keep releasing?

## If something breaks

- **`test.sh 3` says `No load balancer address yet` or `is not answering on /health yet`** → New
  ALB rules take a couple of minutes, and DNS a bit longer. Run `bash test.sh 3` again. Still
  stuck? `kubectl -n zero2ai describe ingress fraud-router` shows the reason under `Events`.
- **The split looks uneven, like `blue=39 green=1`** → It's random per visit, like `router.py`.
  Run the test again; over many visits it evens out.
- **`canary.sh` seemed to change nothing** → The ALB takes about 10 seconds to apply new weights.
  Wait, then run `bash test.sh 3` again.
- **`canary.sh` says `Error: UPGRADE FAILED: "fraud-router" has no deployed releases`** → Phase 3
  isn't installed. Run `bash deploy.sh 3` first.
- **`deploy.sh 3` fails with `UPGRADE FAILED` and the release rolled back** → `--atomic` did its
  job. See why with `kubectl -n zero2ai get events --sort-by=.lastTimestamp | tail -20`, fix it,
  and deploy again.
- **`[ERROR] Unexpected: the broken release succeeded`** → The broken green somehow became
  healthy. Check `helm get values fraud-green -n zero2ai`, then put green back with
  `bash deploy.sh 3`.
- **HPA shows `<unknown>/70%`** → The metrics service needs about a minute after pods start.
  `kubectl top pods -n zero2ai` should show numbers first.
- **Pods show `ImagePullBackOff`** → The image isn't in ECR for this environment. Run
  `bash deploy.sh build`, then `bash deploy.sh 3` again.

## Clean up

```bash
bash down.sh                                                   # remove this chapter's apps
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # when you're done for the day
```

**What you should see:** `[OK] Chapter 14 removed`.

## Where to next

[Chapter 15 — Dashboards you can watch](../../chapter-15-dashboards/README.md). During a canary
you compared blue and green by counting answers. Next you'll build live dashboards that show
each version's speed and errors side by side, which is how real teams decide whether a canary
may grow.
