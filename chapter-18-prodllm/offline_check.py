# offline_check.py
# Checks every guardrail in production_llm.py WITHOUT an API key and
# WITHOUT spending money. It swaps the real robot call for a pretend one
# that always answers the same thing, then tests the cache, the safety
# filter, the per-user budget, the retry and the metrics.
#
#   python offline_check.py
#
# Stop production_llm.py first (Ctrl+C): both use port 8000 for metrics.
import logging, os, types, urllib.request

# A pretend key, only so production_llm.py can start. It is never sent anywhere.
os.environ.setdefault('ANTHROPIC_API_KEY', 'sk-ant-offline-check')
import production_llm as p
logging.disable(logging.CRITICAL)   # keep the screen tidy: only this check's lines

calls = {'robot': 0, 'fail_next': 0}

def pretend_robot(**kwargs):
    calls['robot'] += 1
    if calls['fail_next'] > 0:
        calls['fail_next'] -= 1
        raise RuntimeError('pretend network hiccup')
    return types.SimpleNamespace(
        content=[types.SimpleNamespace(text='RAG means Retrieval-Augmented Generation.')],
        usage=types.SimpleNamespace(input_tokens=12, output_tokens=30))

p.client.messages.create = pretend_robot
web = p.app.test_client()

def ask(user, prompt):
    return web.post('/llm', json={'user_id': user, 'prompt': prompt})

def check(name, ok):
    print(('[OK]    ' if ok else '[ERROR] ') + name)
    if not ok:
        raise SystemExit(1)

# 1. Cache: the same question three times phones the robot only once.
answers = [ask('alice', 'What is RAG?').get_json() for _ in range(3)]
check('cache: 1st answer is fresh, 2nd and 3rd come from the memory box',
      [a['cached'] for a in answers] == [False, True, True] and calls['robot'] == 1)

# 2. Safety filter: private details are refused and never reach the robot.
before = calls['robot']
check('safety filter blocks "My SSN: ..." with HTTP 422',
      ask('alice', 'My SSN: 123-45-6789').status_code == 422)
check('safety filter blocks "password: ..." (any capital letters)',
      ask('alice', 'My Password: hunter2').status_code == 422)
check('blocked messages were never sent to the robot', calls['robot'] == before)

# 3. Empty question.
check('an empty prompt is refused with HTTP 422', ask('alice', '   ').status_code == 422)

# 4. Budget: alice has used 12 + 30 = 42 tokens. Shrink the daily cap to 50.
check('alice has been charged 42 tokens', p.USER_BUDGETS.get('alice') == 42)
p.DAILY_TOKEN_LIMIT = 50
check('a new question is still allowed (42 is under 50)',
      ask('alice', 'Second question').status_code == 200)
r = ask('alice', 'Third question')
check('now alice is over her cap: HTTP 429 "Daily token budget exceeded"',
      r.status_code == 429 and r.get_json()['error'] == 'Daily token budget exceeded')
check('bob has his own budget, so he is still allowed',
      ask('bob', 'Third question').status_code == 200)

# 5. Retry: two hiccups, then success (waits about 4 seconds).
print('        (testing retry: this waits a few seconds on purpose)')
calls['fail_next'] = 2
before = calls['robot']
check('retry: 2 failures then a success still answers',
      ask('carol', 'Retry me').status_code == 200 and calls['robot'] - before == 3)
calls['fail_next'] = 5
check('after 3 failed tries the service gives up with HTTP 503',
      ask('carol', 'Fail me').status_code == 503)

# 6. Metrics on port 8000.
text = urllib.request.urlopen('http://localhost:8000/metrics').read().decode()
check('metrics count the cache hits', 'llm_calls_total{status="cache_hit"} 2.0' in text)
print()
for line in text.splitlines():
    if line.startswith(('llm_calls_total', 'llm_tokens_total')):
        print('  ' + line)
print('\nAll offline checks passed. No API key was used and nothing was spent.')
