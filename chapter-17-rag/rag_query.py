# rag_query.py
import anthropic, os
from retrieval import retrieve

client = anthropic.Anthropic(
    api_key=os.environ['ANTHROPIC_API_KEY'])

SYSTEM = (
    'You are a fintech compliance assistant. '
    'Answer using ONLY the supplied context. '
    'If the context does not contain the answer, '
    'say so explicitly. Cite which passage you used.')

def answer(question):
    chunks = retrieve(question, k=3)
    context = '\n\n'.join(
        f'[{i+1}] {c}'
        for i, c in enumerate(chunks))
    prompt = (
        f'Context:\n{context}\n\n'
        f'Question: {question}')
    msg = client.messages.create(
        model='claude-opus-4-7',
        max_tokens=600,
        system=SYSTEM,
        messages=[
            {'role':'user','content':prompt}
        ])
    return {
        'answer': msg.content[0].text,
        'sources': chunks,
        'tokens_in': msg.usage.input_tokens,
        'tokens_out': msg.usage.output_tokens}

if __name__ == '__main__':
    q = 'What documents are required for KYC?'
    result = answer(q)
    print(result['answer'])
    print(f'\nTokens: {result["tokens_in"]}'
          f'/{result["tokens_out"]}')
