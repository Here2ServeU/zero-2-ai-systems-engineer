"""Evaluation harness for the LLM and RAG endpoints.

Wires Week 17 (Production LLM Systems) into the capstone. Each case
has a question and a set of substrings the response must contain.
The script prints a pass/fail summary and exits non-zero on any
failure, so CI can gate releases on it.
"""

import json
import sys

import requests

import paths

ENDPOINT = "http://localhost:8080/chat-rag"


def main() -> int:
    cases = json.loads(paths.EVAL_SET.read_text())
    passed = 0
    for case in cases:
        body = {"message": case["question"]}
        try:
            response = requests.post(ENDPOINT, json=body, timeout=30)
            reply = response.json()["reply"].lower()
        except Exception as exc:
            print(f"FAIL  {case['question']}  ({exc})")
            continue
        missing = [t for t in case["must_contain"] if t.lower() not in reply]
        if missing:
            print(f"FAIL  {case['question']}  missing={missing}")
        else:
            passed += 1
            print(f"PASS  {case['question']}")
    print(f"\n{passed}/{len(cases)} cases passed")
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    sys.exit(main())
