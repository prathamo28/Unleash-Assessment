import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import boto3
import requests


COGNITO_CLIENT_ID = os.environ["COGNITO_CLIENT_ID"]
COGNITO_PASSWORD = os.environ["COGNITO_PASSWORD"]
COGNITO_USERNAME = os.environ.get("COGNITO_USERNAME", "prathamesh.mokal@hotmail.com")

API_URL_US_EAST_1 = os.environ["API_URL_US_EAST_1"]
API_URL_EU_WEST_1 = os.environ["API_URL_EU_WEST_1"]


def get_jwt_token() -> str:
    client = boto3.client("cognito-idp", region_name="us-east-1")

    resp = client.initiate_auth(
        ClientId=COGNITO_CLIENT_ID,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": COGNITO_USERNAME,
            "PASSWORD": COGNITO_PASSWORD,
        },
    )

    return resp["AuthenticationResult"]["IdToken"]


def call_endpoint(name: str, url: str, token: str, expected_region: str) -> dict:
    headers = {"Authorization": f"Bearer {token}"}
    start = time.time()
    resp = requests.get(url, headers=headers, timeout=10)
    latency_ms = (time.time() - start) * 1000.0

    resp.raise_for_status()
    body = resp.json()

    region = body.get("region")
    assert (
        region == expected_region
    ), f"{name}: expected region {expected_region}, got {region}"

    return {
        "name": name,
        "url": url,
        "status_code": resp.status_code,
        "region": region,
        "latency_ms": latency_ms,
    }


def main() -> None:
    print("Authenticating against Cognito...")
    token = get_jwt_token()
    print("Got JWT, running concurrent calls...")

    tasks = {
        "greet-us-east-1": (
            f"{API_URL_US_EAST_1}/greet",
            "us-east-1",
        ),
        "greet-eu-west-1": (
            f"{API_URL_EU_WEST_1}/greet",
            "eu-west-1",
        ),
        "dispatch-us-east-1": (
            f"{API_URL_US_EAST_1}/dispatch",
            "us-east-1",
        ),
        "dispatch-eu-west-1": (
            f"{API_URL_EU_WEST_1}/dispatch",
            "eu-west-1",
        ),
    }

    results = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        future_map = {
            executor.submit(
                call_endpoint,
                name,
                url,
                token,
                expected_region,
            ): name
            for name, (url, expected_region) in tasks.items()
        }

        for future in as_completed(future_map):
            name = future_map[future]
            try:
                res = future.result()
                results.append(res)
            except Exception as exc:  # noqa: BLE001
                print(f"[ERROR] {name} failed: {exc}")
                raise

    print("\nResults:")
    for r in sorted(results, key=lambda x: x["name"]):
        print(
            f"{r['name']}: status={r['status_code']}, "
            f"region={r['region']}, latency={r['latency_ms']:.2f}ms"
        )


if __name__ == "__main__":
    main()

