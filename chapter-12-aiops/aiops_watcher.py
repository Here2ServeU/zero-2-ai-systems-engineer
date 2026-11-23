# aiops_watcher.py
# The Chapter 12 robot night guard, plugged into a REAL cluster.
#
#   1. Reads the last 15 minutes of CPU and memory for one app from Prometheus
#      (the same numbers you watched in Chapter 11).
#   2. Runs predict_failure() from aiops_engine.py: spikes + upward trends.
#   3. If WARNING and ALLOW_SCALE=true, acts:
#        - app has an autoscaler (HPA)? raise its minimum copies
#        - no autoscaler? add copies to the Deployment directly
#      Always capped at MAX_REPLICAS. Otherwise it only reports.
#
# Settings (environment variables):
#   PROMETHEUS_URL     e.g. http://kube-prometheus-stack-prometheus.monitoring:9090
#   TARGET_DEPLOYMENT  app to watch (default: metrics-api, from Chapter 11)
#   TARGET_NAMESPACE   default: zero2ai
#   ALLOW_SCALE        "true" to act, anything else = report only (default)
#   MAX_REPLICAS       never scale above this (default: 6)
#   SCALE_STEP         copies to add per WARNING (default: 1)
import contextlib, io, json, os, ssl, sys, time
import urllib.parse, urllib.request

# aiops_engine.py runs a demo when imported; keep its prints out of our logs.
with contextlib.redirect_stdout(io.StringIO()):
    from aiops_engine import predict_failure

PROM = os.getenv('PROMETHEUS_URL',
    'http://kube-prometheus-stack-prometheus.monitoring:9090')
TARGET = os.getenv('TARGET_DEPLOYMENT', 'metrics-api')
NS = os.getenv('TARGET_NAMESPACE', 'zero2ai')
ALLOW_SCALE = os.getenv('ALLOW_SCALE', 'false').lower() == 'true'
MAX_REPLICAS = int(os.getenv('MAX_REPLICAS', '6'))
SCALE_STEP = int(os.getenv('SCALE_STEP', '1'))

# CPU used, as % of the CPU each copy asked for. Memory used, as % of its limit.
PODS = f'namespace="{NS}",pod=~"{TARGET}-[a-z0-9]+-[a-z0-9]+"'
CPU_Q = (f'100 * sum(rate(container_cpu_usage_seconds_total{{{PODS},container!=""}}[2m]))'
         f' / sum(kube_pod_container_resource_requests{{{PODS},resource="cpu"}})')
MEM_Q = (f'100 * sum(container_memory_working_set_bytes{{{PODS},container!=""}})'
         f' / sum(kube_pod_container_resource_limits{{{PODS},resource="memory"}})')


def prom_range(query, minutes=15, step=60):
    end = time.time()
    params = urllib.parse.urlencode({'query': query, 'start': end - minutes * 60,
                                     'end': end, 'step': step})
    with urllib.request.urlopen(f'{PROM}/api/v1/query_range?{params}', timeout=20) as r:
        data = json.load(r)
    result = data.get('data', {}).get('result', [])
    if not result:
        return []
    # Skip gaps Prometheus reports as NaN/Inf (e.g. right after a restart).
    return [round(float(v), 1) for _, v in result[0]['values']
            if v not in ('NaN', '+Inf', '-Inf')]


# ---- tiny Kubernetes API client (uses the pod's own service account) -------
SA = '/var/run/secrets/kubernetes.io/serviceaccount'
API = 'https://kubernetes.default.svc'


def k8s(method, path, body=None):
    token = open(f'{SA}/token').read()
    ctx = ssl.create_default_context(cafile=f'{SA}/ca.crt')
    req = urllib.request.Request(API + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={'Authorization': f'Bearer {token}',
                 'Content-Type': 'application/merge-patch+json'})
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, {}


def act():
    hpa_path = f'/apis/autoscaling/v2/namespaces/{NS}/horizontalpodautoscalers/{TARGET}'
    status, hpa = k8s('GET', hpa_path)
    if status == 200:
        current = hpa['spec'].get('minReplicas', 1)
        wanted = min(current + SCALE_STEP, hpa['spec']['maxReplicas'], MAX_REPLICAS)
        if wanted == current:
            print(f'  - HPA minReplicas already at the cap ({current}); nothing to do')
            return
        k8s('PATCH', hpa_path, {'spec': {'minReplicas': wanted}})
        print(f'  - Raised HPA {TARGET} minReplicas {current} -> {wanted}')
        return
    scale_path = f'/apis/apps/v1/namespaces/{NS}/deployments/{TARGET}/scale'
    status, scale = k8s('GET', scale_path)
    if status != 200:
        print(f'  - Cannot read deployment {TARGET} (HTTP {status}); check RBAC')
        return
    current = scale['spec'].get('replicas', 1)
    wanted = min(current + SCALE_STEP, MAX_REPLICAS)
    if wanted == current:
        print(f'  - Already at MAX_REPLICAS ({current}); nothing to do')
        return
    k8s('PATCH', scale_path, {'spec': {'replicas': wanted}})
    print(f'  - Scaled deployment {TARGET} {current} -> {wanted} copies')


def main():
    print(f'AIOps watcher: target={NS}/{TARGET} allow_scale={ALLOW_SCALE}')
    cpu, mem = prom_range(CPU_Q), prom_range(MEM_Q)
    if len(cpu) < 3 or len(mem) < 3:
        print('Not enough data yet (need 3+ minutes of metrics). STABLE by default.')
        return 0
    print(f'CPU % of request (last {len(cpu)} min): {cpu}')
    print(f'Memory % of limit (last {len(mem)} min): {mem}')
    result = predict_failure(cpu, mem)
    print(f'Status: {result["status"]}')
    for w in result['warnings']:
        print(f'  WARNING: {w}')
    print(f'Action: {result["action"]}')
    if result['status'] == 'WARNING':
        if ALLOW_SCALE:
            print('Triggering automated response:')
            act()
        else:
            print('Report-only mode (ALLOW_SCALE is not "true"): no changes made.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
