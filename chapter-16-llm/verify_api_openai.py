# verify_api_openai.py
# Same test as verify_api.py, but using OpenAI instead of Anthropic.
from openai import OpenAI
import os

client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])

resp = client.chat.completions.create(
    model='gpt-4o',
    max_tokens=200,
    messages=[
        {'role': 'user',
         'content': 'Say hello in one sentence.'}
    ])
print(resp.choices[0].message.content)
print('Input tokens:', resp.usage.prompt_tokens)
print('Output tokens:', resp.usage.completion_tokens)
