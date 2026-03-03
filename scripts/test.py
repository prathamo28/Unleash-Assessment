#!/usr/bin/env python3
"""
Unleash live AWS Assessment - Automated Test Script
"""
import asyncio, json, os, sys, time
import urllib.request, urllib.error
import boto3
from botocore.exceptions import ClientError

USER_EMAIL    = "prathamesh.mokal@hotmail.com"
USER_PASSWORD = os.environ.get("COGNITO_PASSWORD", "ChangeMe123!")

COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID", "")
COGNITO_CLIENT_ID    = os.environ.get("COGNITO_CLIENT_ID", "")
API_URL_US           = os.environ.get("API_URL_US_EAST_1", "")
API_URL_EU           = os.environ.get("API_URL_EU_WEST_1", "")
REGIONS = {"us-east-1": API_URL_US, "eu-west-1": API_URL_EU}

def get_jwt_token():
    print("\n[AUTH] Authenticating with Cognito...")
    client = boto3.client("cognito-idp", region_name="us-east-1")
    try:
        resp = client.initiate_auth(
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={"USERNAME": USER_EMAIL, "PASSWORD": USER_PASSWORD},
            ClientId=COGNITO_CLIENT_ID,
        )
        token = resp["AuthenticationResult"]["IdToken"]
        print("[AUTH] JWT obtained.")
        return token
    except ClientError as e:
        print(f"[AUTH] Error: {e}")
        sys.exit(1)

def call_endpoint(region, api_url, path, token):
    url = f"{api_url.rstrip('/')}/{path.lstrip('/')}"
    req = urllib.request.Request(url, headers={"Authorization": token})
    start = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            ms = round((time.monotonic() - start) * 1000, 1)
            body = json.loads(resp.read().decode())
            return {"region": region, "path": path, "status": resp.status, "body": body, "ms": ms, "error": None}
    except Exception as e:
        ms = round((time.monotonic() - start) * 1000, 1)
        return {"region": region, "path": path, "status": None, "body": None, "ms": ms, "error": str(e)}

async def run_concurrent(token, path):
    loop = asyncio.get_event_loop()
    tasks = [loop.run_in_executor(None, call_endpoint, r, u, path, token) for r, u in REGIONS.items() if u]
    return await asyncio.gather(*tasks)

def report(results, path):
    print(f"\n{'='*55}\n  Endpoint: /{path}\n{'='*55}")
    passed = True
    for r in results:
        ok = r["status"] == 200
        print(f"\n  Region  : {r['region']}")
        print(f"  Status  : {r['status']} [{'PASS' if ok else 'FAIL'}]")
        print(f"  Latency : {r['ms']} ms")
        if r["error"]:
            print(f"  Error   : {r['error']}")
            passed = False
        elif r["body"]:
            print(f"  Body    : {json.dumps(r['body'])}")
            if path == "greet":
                got = r["body"].get("region", "")
                match = got == r["region"]
                print(f"  Assert  : {'PASS' if match else 'FAIL'} - region={got}")
                if not match: passed = False
    return passed

def main():
    print("="*55)
    print("  Unleash live - Test Runner")
    print("="*55)
    if not all([COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, API_URL_US, API_URL_EU]):
        print("\n[ERROR] Set these env vars first:")
        print("  export COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)")
        print("  export COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)")
        print("  export API_URL_US_EAST_1=$(terraform output -raw api_url_us_east_1)")
        print("  export API_URL_EU_WEST_1=$(terraform output -raw api_url_eu_west_1)")
        sys.exit(1)
    token = get_jwt_token()
    print("\n[TEST] Calling /greet concurrently in both regions...")
    gr = asyncio.run(run_concurrent(token, "greet"))
    gp = report(gr, "greet")
    print("\n[TEST] Calling /dispatch concurrently in both regions...")
    dr = asyncio.run(run_concurrent(token, "dispatch"))
    dp = report(dr, "dispatch")
    print(f"\n{'='*55}")
    print(f"  /greet   : {'PASS' if gp else 'FAIL'}")
    print(f"  /dispatch: {'PASS' if dp else 'FAIL'}")
    lats = sorted([(r['region'], r['ms']) for r in gr if r['ms']], key=lambda x: x[1])
    if len(lats) == 2:
        print(f"\n  Latency diff: {round(abs(lats[0][1]-lats[1][1]),1)} ms")
        for reg, ms in lats:
            print(f"    {reg}: {ms} ms")
    print()
    sys.exit(0 if gp and dp else 1)

if __name__ == "__main__":
    main()
