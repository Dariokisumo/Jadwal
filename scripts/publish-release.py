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
        token = part.split("@", 1)[0]
        return token
    raise ValueError("Could not extract token from GITHUB_TOKEN env or git remote origin")

def main():
    token = get_token()
    owner = "Dariokisumo"
    repo = "Jadwal"
    tag = "v2.10.4"
    release_name = "v2.10.4 — Period Reminder Auto-Dismissal & Modular Relational UI"
    release_body = """## What's new in v2.10.4

### ⏰ Notification Timing & Auto-Dismissal
- **Period Reminder Auto-Clear**: Class reminder notifications scheduled 5 minutes before class now automatically clear 5 minutes after class begins (`timeoutAfter: 10min`), preventing stale notifications from cluttering the status bar or lock screen.
- **Single Live Reminder**: Preserves `onlyAlertOnce: true` and high-priority reminder channels for subtle, non-intrusive alerts.

### 🎨 Modular Relational UI Refactoring
- **WeekStrip Component**: Extracted calendar week selector into a dedicated, responsive widget (`WeekStrip`) supporting narrow screen constraints.
- **Unified AppDialog & AppSheet**: Standardized confirmation modals and bottom sheets (`AppDialog`, `AppSheet`) across all screens for consistent surface hierarchy and elevation.
- **Modularized Screen Subcomponents**: Cleanly decoupled `HomeScreen`, `SetupScreen`, and `PeriodTimingsScreen` into composable subcomponents for faster build iterations and maintainability.

### ⚡ Build System & Android Stability
- **Gradle VFS Watching & Incremental Build**: Enabled `org.gradle.vfs.watch=true` and `kotlin.incremental=true` in `gradle.properties` for lightning-fast incremental builds.
- **Verified Dual ABI Releases**: Independent compilation and cryptographic signing for both 64-bit and 32-bit release APKs.

---

### 📦 Downloads & Architecture

| File | Architecture | Target Devices | Size | SHA256 |
|---|---|---|---|---|
| `jadwal-v2.10.4-63-release.apk` | **arm64-v8a** (64-bit) | Modern Android phones & tablets (recommended) | 24.21 MB | `55d8b6721c4ff77067b49f26073a2593ddda72126f3c1c5dbd8f8aac8c1ad882` |
| `jadwal-v2.10.4-63-arm32-release.apk` | **armeabi-v7a** (32-bit) | Older & budget 32-bit Android devices | 21.84 MB | `a1fb1c6d8a65797b6e6e06939cd1b87ee821e96ef5a53431aec4411cc5c6b49f` |
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
        ("Apk files/jadwal-v2.10.4-63-release.apk", "jadwal-v2.10.4-63-release.apk"),
        ("Apk files/apk32/jadwal-v2.10.4-63-release.apk", "jadwal-v2.10.4-63-arm32-release.apk")
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
