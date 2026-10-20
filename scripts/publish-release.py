#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

def get_token():
    env_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if env_token:
        return env_token
    res = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True, check=True)
    url = res.stdout.strip()
    # format: https://<token>@github.com/...
    if "@" in url and "://" in url:
        part = url.split("://", 1)[1]
        user_or_token = part.split("@", 1)[0]
        if ":" in user_or_token:
            return user_or_token.split(":", 1)[1]
        return user_or_token
    raise ValueError("Could not extract token from GITHUB_TOKEN env or git remote origin")

def main():
    token = get_token()
    owner = "Dariokisumo"
    repo = "Jadwal"
    tag = "v2.10.7"
    release_name = "v2.10.7 — UI Clutter Reduction & Setup Flow Refinement"
    release_body = """## What's new in v2.10.7

### 🧭 Streamlined Setup Screen & Progressive Disclosure
- **Step 1 Accordion Collapse**: When Step 2 activates, Step 1 now automatically collapses into a sleek 52px summary chip with a "Change" action, keeping the primary "Import This Schedule" button in immediate focus above the fold.
- **Removed Static Prompt Banner**: Eliminated the redundant permanent in-card prompt copy banner. Transient feedback is now handled cleanly by floating snackbars and button state swaps.
- **Consolidated Entry Points**: Streamlined Step 1 to keep focus on AI assistant selection and photo alignment while retaining quick access to file uploads and demo schedules.

### 🔔 Singleton Transient Notifications & Dismissible Errors
- **Purged Notification Queue**: Upgraded notification dispatch in `AppFeedback` to immediately clear pending snackbars so rapid taps no longer stack lingering banners.
- **Dismissible Error Box**: Added an interactive dismiss action to error alerts in Step 2, and ensured error states clear automatically upon valid timetable entry.

---

### 📦 Downloads & Architecture

| File | Architecture | Target Devices | Size | SHA256 |
|---|---|---|---|---|
| `jadwal-v2.10.7-66-release.apk` | **arm64-v8a** (64-bit) | Modern Android phones & tablets (recommended) | 24.33 MB | `7889854958369941752050812e6bfe180bbf79e6d36771f54f5a5487a77ab581` |
| `jadwal-v2.10.7-66-arm32-release.apk` | **armeabi-v7a** (32-bit) | Older & budget 32-bit Android devices | 21.99 MB | `f6560bbaf336b0003d2e3ac82f657f65f1f5ce998a2c005d16fe0111775781b3` |
"""

    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "Jadwal-Release-Script"
    }

    # 1. Create or get existing release
    print(f"Creating release {tag}...")
    create_url = f"https://api.github.com/repos/{owner}/{repo}/releases"
    payload = json.dumps({
        "tag_name": tag,
        "name": release_name,
        "body": release_body,
        "draft": False,
        "prerelease": False
    }).encode("utf-8")

    req = urllib.request.Request(create_url, data=payload, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            release_id = data["id"]
            upload_url = data["upload_url"].split("{")[0]
            print(f"Created release ID: {release_id}")
    except urllib.error.HTTPError as e:
        if e.code == 422:
            print("Release already exists, fetching existing release...")
            get_req = urllib.request.Request(f"https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}", headers=headers)
            with urllib.request.urlopen(get_req) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                release_id = data["id"]
                upload_url = data["upload_url"].split("{")[0]
                print(f"Found existing release ID: {release_id}")
        else:
            raise

    # Assets to upload
    assets = [
        ("Apk files/jadwal-v2.10.7-66-release.apk", "jadwal-v2.10.7-66-release.apk"),
        ("Apk files/apk32/jadwal-v2.10.7-66-release.apk", "jadwal-v2.10.7-66-arm32-release.apk")
    ]

    for local_path, asset_name in assets:
        if not os.path.exists(local_path):
            print(f"Error: {local_path} not found!")
            sys.exit(1)
        file_size = os.path.getsize(local_path)
        print(f"Uploading {asset_name} ({file_size / (1024*1024):.2f} MB)...")
        upload_endpoint = f"https://uploads.github.com/repos/{owner}/{repo}/releases/{release_id}/assets?name={asset_name}"
        
        with open(local_path, "rb") as f:
            file_data = f.read()

        upload_headers = {
            "Authorization": f"token {token}",
            "Content-Type": "application/vnd.android.package-archive",
            "Content-Length": str(file_size),
            "User-Agent": "Jadwal-Release-Script"
        }

        up_req = urllib.request.Request(upload_endpoint, data=file_data, headers=upload_headers, method="POST")
        with urllib.request.urlopen(up_req) as up_resp:
            up_data = json.loads(up_resp.read().decode("utf-8"))
            print(f"Uploaded {asset_name} successfully -> {up_data.get('browser_download_url')}")

    print("\nAll assets uploaded and release published successfully!")

if __name__ == "__main__":
    main()
