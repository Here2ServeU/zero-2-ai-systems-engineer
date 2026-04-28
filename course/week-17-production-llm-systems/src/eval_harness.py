"""Score the RAG endpoint against a held-out question set.

Placeholder for Chapter 18. The chapter walks through judge prompts,
golden-answer comparisons, and how to wire scores into MLflow so each
prompt revision is tracked the same way classical models are.
"""

import json
import pathlib

import requests

QUESTIONS = pathlib.Path("course/week-17-production-llm-systems/data/eval_set.json")
ENDPOINT = "http://localhost:8080/chat"


def main() -> None:
    cases = json.loads(QUESTIONS.read_text())
    passed = 0
    for case in cases:
        response = requests.post(ENDPOINT, json={"message": case["question"]}, timeout=30)
        reply = response.json()["reply"].lower()
        if all(token.lower() in reply for token in case["must_contain"]):
            passed += 1
    print(f"{passed}/{len(cases)} cases passed")


if __name__ == "__main__":
    main()
