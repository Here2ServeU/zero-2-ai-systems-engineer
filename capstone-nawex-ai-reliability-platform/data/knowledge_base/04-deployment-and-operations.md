# Deployment and Operations

The platform supports three deployment strategies, selectable per release:

- **Canary**: route 5% of traffic to the new version, watch error rate and latency for a configurable bake period, then promote or roll back.
- **Blue-green**: stand up the new version in parallel, smoke-test it on a sealed-off endpoint, then flip the load balancer when it passes.
- **Feature flags**: ship the code dark, gate the new behavior behind a flag, and ramp exposure gradually for individual tenants.

When a model exhibits drift, the retraining pipeline kicks off a fresh training run, registers the resulting artifact in MLflow with a `staging` tag, and opens a pull request that, once merged, deploys the model through a canary rollout.

AIOps watches platform telemetry — request rate, error rate, latency percentiles, model prediction confidence — and uses anomaly detection to surface incidents before they trigger user-visible failures. Alerts route through Slack for soft signals and PagerDuty for hard incidents.
