# automated_response.py
from aiops_engine import predict_failure

def automated_response(cpu, mem):
    result = predict_failure(cpu, mem)
    if result['status'] == 'WARNING':
        print('=== AIOps ALERT ===')
        for w in result['warnings']:
            print(f'  {w}')
        print('Triggering automated response:')
        print('  - Alert sent to Slack')
        print('  - Kubernetes pods scaled up')
        print('  - Incident ticket opened')
    else:
        print('All systems stable.')

cpu_now = [45,47,48,52,60,72,85,91,95,98]
mem_now = [60,62,63,66,72,80,88,92,95,97]
automated_response(cpu_now, mem_now)
