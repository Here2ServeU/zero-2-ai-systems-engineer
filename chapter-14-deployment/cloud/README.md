# Chapter 14 — Cloud track: blue/green and canary releases on EKS

> On your laptop, `switch.py` flipped a variable and `router.py` sent 20% of calls to the new
> model. On EKS the same ideas move **real traffic**: a Service selector for blue/green, a Helm
> release you can roll back, and an AWS load balancer that splits traffic by weight.
> Platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

Both colors run the **same fraud API image** (Chapter 06). Only two settings differ —
`APP_VERSION` and `APP_COLOR` — so `GET /info` tells you who answered.

```bash
cd chapter-14-deployment/cloud
bash deploy.sh build
```

## Phase 1 — Blue/green with plain YAML

Two Deployments (`fraud-blue-p1`, `fraud-green-p1`) and one public Service whose selector says
`color: blue`.

```bash
bash deploy.sh 1
bash test.sh 1            # 10 visits: blue=10 green=0
bash switch.sh 1 green    # flip the selector: ALL traffic moves at once
bash test.sh 1            # blue=0 green=10
bash switch.sh 1 blue     # rollback = flip back
```

## Phase 2 — Blue/green with Helm

Three releases of the same chart:

| Release | Values | Has pods? |
|---|---|---|
| `fraud-blue` | [`phase2/blue.yaml`](phase2/blue.yaml) | yes (v1.0.0) |
| `fraud-green` | [`phase2/green.yaml`](phase2/green.yaml) | yes (v2.0.0) |
| `fraud-router` | [`phase2/router.yaml`](phase2/router.yaml) | **no** — only a Service whose selector picks a color |

```bash
bash deploy.sh 2
bash test.sh 2
bash switch.sh 2 green                       # helm upgrade fraud-router --set ...color=green
helm rollback fraud-router -n zero2ai         # the fast way back, recorded in helm history
```

## Phase 3 — Canary through the load balancer + automatic rollback

[`phase3/router.yaml`](phase3/router.yaml) gives the router a public **ALB** that splits
traffic by **weight** between the `fraud-blue` and `fraud-green` Services (start: 90/10).
[`phase3/app.yaml`](phase3/app.yaml) gives both colors the production settings from Chapter 10.

```bash
bash deploy.sh 3
bash test.sh 3            # 40 visits: about 36 blue, 4 green
bash canary.sh 50         # half and half
bash canary.sh 100        # everyone on green
bash canary.sh 0          # instant rollback
```

**Automatic rollback:** ship a green that can't start, with `helm upgrade --atomic`:

```bash
bash deploy.sh broken     # Helm waits, sees it never becomes healthy, and rolls back by itself
```

Blue keeps serving the whole time, because `maxUnavailable: 0` never removes a working copy
before its replacement is healthy.

> **Feature flags on Kubernetes** are just settings: `helm upgrade <release> --reuse-values
> --set env.MY_FLAG=true` changes them without rebuilding the image. Everything you change this
> way is recorded in `helm history`, so you can roll it back too.

## If something breaks

- **Canary split looks uneven with few visits** → It's random per request, like `router.py`.
  Count more visits.
- **`canary.sh` changed nothing** → The ALB takes ~10 seconds to apply new weights.

## Clean up / next

`bash down.sh` · Next: [Chapter 15's cloud track](../../chapter-15-dashboards/cloud/README.md).
