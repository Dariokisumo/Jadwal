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
    tag = "v2.10.5"
    release_name = "v2.10.5 — Illustrated App Logo & Themed Monochrome Icon"
    release_body = """## What's new in v2.10.5

### 🎨 Illustrated App Brand Logo
- **New Illustrated Icon**: Integrated the new illustrated calendar & clock brand icon across all Android launcher densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) and web touch icons.
- **Normal Launcher Clarity**: Full-color illustrated calendar and clock artwork with realistic drop-shadow depth against a crisp white background badge.

### 🌓 Material You Adaptive Monochrome Themed Icon
- **Negative-Space Depth Architecture**: Rather than flattening the icon into an amorphous solid blob, the monochrome layer uses transparent viewports for the calendar body and clock face, providing maximum contrast for the number **7** and clock hands.
- **3D Spiral Binder Rings**: Preserved ring apertures ensuring the spiral loops arch naturally over the binder.
- **Multi-Tone Alpha Shading**: Soft secondary opacity for the binder header and fanned bottom pages retains 3D paper layers across both Light and Dark system wallpaper palettes.
- **Subpixel Anti-Aliasing**: Smooth boundary Gaussian edge modulation prevents stair-stepping across all display densities.

### 🌐 Companion Web Portal & Synchronized Downloads
- Synced direct APK download links and brand favicons on `https://getjadwal.surge.sh` and `https://dariokisumo.github.io`.

---

### 📦 Downloads & Architecture

| File | Architecture | Target Devices | Size | SHA256 |
|---|---|---|---|---|
| `jadwal-v2.10.5-64-release.apk` | **arm64-v8a** (64-bit) | Modern Android phones & tablets (recommended) | 24.33 MB | `c9ebe8770876e2f5545876e3521777fbc4922983e070dab220c7f772c7a555fc` |
| `jadwal-v2.10.5-64-arm32-release.apk` | **armeabi-v7a** (32-bit) | Older & budget 32-bit Android devices | 21.98 MB | `a8492ac8c221eb274af2cb6e1d762c06ff0211f48fb8a5019ad8d976083d7582` |
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
        ("Apk files/jadwal-v2.10.5-64-release.apk", "jadwal-v2.10.5-64-release.apk"),
        ("Apk files/apk32/jadwal-v2.10.5-64-release.apk", "jadwal-v2.10.5-64-arm32-release.apk")
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
