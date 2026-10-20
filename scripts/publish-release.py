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
    tag = "v2.10.6"
    release_name = "v2.10.6 — Relational Notification Tuneup & In-App Diagnostics"
    release_body = """## What's new in v2.10.6

### ⏰ Resilient Exact Alarm Scheduling & Inexact Fallback
- **Android 14+ Inexact Fallback**: Dynamically selects `exactAllowWhileIdle` when granted, with automated fallback to `inexactAllowWhileIdle` so period reminders are never silently lost.
- **Settings Intent Resolution**: Fixed focus hijack in `MainActivity.kt` where opening Alarms & Reminders was immediately overridden by generic App Info.

### 🔔 Relational Notification Polish & Formatting
- **Information Gravity**: Clean notification title leading with subject and period (`Period 3 · Mathematics`), keeping status bar and lockscreen immediately legible at a glance.
- **Null-Safe Room Formatting**: Clean room text without awkward spacing (`Starts at 9:00 AM in Room 4` vs `Starts at 9:00 AM`).
- **Emoji-Free Styling**: Replaced emoji prefix with clean semantic text according to Relational Design standards.

### 🛠️ In-App Notification Diagnostics & Test Action
- **Diagnostics Section in Misc**: New "NOTIFICATIONS & REMINDERS" relational card showing live permission and alarm health.
- **Send Test Notification**: 1-tap instant test notification to verify sound, vibration, heads-up banner, and OEM background delivery.
- **Non-Blocking Permission Flow**: Replaced startup blocking modal traps with an elegant AppBar indicator and polite, dismissible dialogs.

---

### 📦 Downloads & Architecture

| File | Architecture | Target Devices | Size | SHA256 |
|---|---|---|---|---|
| `jadwal-v2.10.6-65-release.apk` | **arm64-v8a** (64-bit) | Modern Android phones & tablets (recommended) | 24.33 MB | `c2975f2092aa33f24f67c74f8ee5a6bd265e6d52fd520cdb4575b756c1fc7273` |
| `jadwal-v2.10.6-65-arm32-release.apk` | **armeabi-v7a** (32-bit) | Older & budget 32-bit Android devices | 21.98 MB | `c4f8e48315c055f5e14706c384303578ffa8b4089ab56d2e3f725e8b39f9f568` |
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
        ("Apk files/jadwal-v2.10.6-65-release.apk", "jadwal-v2.10.6-65-release.apk"),
        ("Apk files/apk32/jadwal-v2.10.6-65-release.apk", "jadwal-v2.10.6-65-arm32-release.apk")
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
