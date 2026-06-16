# verify_api.py
import anthropic, os

client = anthropic.Anthropic(
    api_key=os.environ['ANTHROPIC_API_KEY'])

msg = client.messages.create(
    model='claude-opus-4-7',
    max_tokens=200,
    messages=[
        {'role':'user',
         'content':'Say hello in one sentence.'}
    ])
print(msg.content[0].text)
print('Input tokens:', msg.usage.input_tokens)
print('Output tokens:', msg.usage.output_tokens)
