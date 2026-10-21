# verify_api_gemini.py
# Same test as verify_api.py, but using Google Gemini instead of Anthropic.
from google import genai
import os

client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])

resp = client.models.generate_content(
    model='gemini-2.5-flash',
    contents='Say hello in one sentence.')
print(resp.text)
print('Input tokens:', resp.usage_metadata.prompt_token_count)
print('Output tokens:', resp.usage_metadata.candidates_token_count)
