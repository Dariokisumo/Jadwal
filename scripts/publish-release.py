#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

def get_token():
    res = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True, check=True)
    url = res.stdout.strip()
    # format: https://<token>@github.com/...
    if "@" in url and "://" in url:
        part = url.split("://", 1)[1]
        token = part.split("@", 1)[0]
        return token
    raise ValueError("Could not extract token from git remote origin")

def main():
    token = get_token()
    owner = "Dariokisumo"
    repo = "Jadwal"
    tag = "v2.10.3"
    release_name = "v2.10.3 — Plain-Language Onboarding Guide & Streamlined Photo Setup"
    release_body = """## What's new in v2.10.3

### 🌟 Plain-Language Onboarding Welcome Guide
- **3-Step Visual Cards**: Introduced an intuitive visual overview of how Jadwal works in simple, jargon-free language:
  1. *Snap your paper schedule* (no typing needed)
  2. *Your AI helper reads it* (Gemini, ChatGPT, or Claude handles extraction)
  3. *Get offline bell alerts* (notifies before every period starts)
- **Key Trust Badges**: Clear visual assurance on first launch: **100% Offline**, **Instant bell alerts**, and **No sign-up or accounts required**.
- **Streamlined Actions**: Direct primary button to take or align a schedule photo, an instant one-tap **Try Demo Schedule** button, and a quiet path to manual file import / step-by-step setup.
- **Bi-directional Navigation**: Easy "Guide" return button in the setup step header allowing teachers to flip back to the visual onboarding guide at any time.

### ⚡ Build & Platform Stability
- **AndroidX Dependency Resolution**: Pinned `androidx.core` and `androidx.activity` versions across subprojects to ensure reliable, zero-warning builds against Android Gradle Plugin 8.7.0 and Gradle 8.14.2.
- **Accessibility & Overflow Hardening**: Verified zero overflow on 320dp narrow screens and high font scaling factors (up to 1.4×).

---

### 📦 Downloads & Architecture

| File | Architecture | Target Devices | Size | SHA256 |
|---|---|---|---|---|
| `jadwal-v2.10.3-62-release.apk` | **arm64-v8a** (64-bit) | Modern Android phones & tablets (recommended) | ~24.2 MB | `a857cc69a17d4b3ac49dcd3e20dd9cdfe185c91ace5836a55793b1807366fd9f` |
| `jadwal-v2.10.3-62-arm32-release.apk` | **armeabi-v7a** (32-bit) | Older & budget 32-bit Android devices | ~21.8 MB | `ac234f18489389bc226e8ea1a1d334eab3a5ffd328c924e037c567670710c680` |
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
        ("Apk files/jadwal-v2.10.3-62-release.apk", "jadwal-v2.10.3-62-release.apk"),
        ("Apk files/apk32/jadwal-v2.10.3-62-release.apk", "jadwal-v2.10.3-62-arm32-release.apk")
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
