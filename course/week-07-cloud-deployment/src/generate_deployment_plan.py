from __future__ import annotations

import json


def build_plan() -> dict:
    return {
        "cloud": "aws",
        "environment": "dev",
        "components": [
            "container registry",
            "artifact bucket",
            "api service",
            "kubernetes cluster",
            "monitoring stack",
        ],
        "release_flow": [
            "build container image",
            "push image",
            "apply terraform",
            "deploy helm chart",
            "verify health endpoint",
        ],
    }


if __name__ == "__main__":
    print(json.dumps(build_plan(), indent=2))
