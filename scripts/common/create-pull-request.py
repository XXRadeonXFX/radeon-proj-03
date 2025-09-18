import argparse
import os
import requests
from requests.auth import HTTPBasicAuth
import json
import sys

def log(msg):
    print(f"[create-pull-request] {msg}")

def create_pull_request(repository_id, source_branch, pat):
    organization = "https://dev.azure.com/tetrapak-tpps"
    project = "Platform and Process"
    title = "Auto-generated PR for " + source_branch 
    description = "This PR was created automatically by the pipeline."
    target_branch = "main"

    url = f"{organization}/{project}/_apis/git/repositories/{repository_id}/pullrequests?api-version=7.1-preview.1"
    payload = {
        "sourceRefName": f"refs/heads/{source_branch}",
        "targetRefName": f"refs/heads/{target_branch}",
        "title": title,
        "description": description,
        "reviewers": []
    }

    log(f"Creating pull request from '{source_branch}' to '{target_branch}' in repo '{repository_id}'")
    try:
        response = requests.post(
            url,
            auth=HTTPBasicAuth('', pat),
            headers={"Content-Type": "application/json"},
            data=json.dumps(payload),
            timeout=30
        )
    except Exception as e:
        log(f"❌ Exception during PR creation: {e}")
        sys.exit(1)

    if response.status_code == 201:
        pr = response.json()
        log(f"✅ Pull request created: {pr.get('url', 'No URL in response')}")
    else:
        log(f"❌ Failed to create pull request: {response.status_code}")
        log(f"Response: {response.text}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Create a pull request in Azure DevOps.")
    parser.add_argument("--repository_id", required=True, help="Repository ID or GUID")
    parser.add_argument("--source_branch", required=True, help="Source branch name")
    parser.add_argument("--pat", required=False, help="Personal Access Token (optional if using env variable)")

    args = parser.parse_args()

    pat = args.pat or os.getenv("ENCODED_PAT")
    if not pat:
        log("❌ PAT must be provided either as an argument or via the ENCODED_PAT environment variable.")
        sys.exit(1)

    create_pull_request(args.repository_id, args.source_branch, pat)

if __name__ == "__main__":
    main()