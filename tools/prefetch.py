#!/usr/bin/env python3
"""Keep the newest build inputs in a local cache on the build server.

Downloads the latest release asset of every GitHub-hosted app ArkadeOS ships,
the WhiteSur theme sources and the Battle.net installer into $ARKADEOS_CACHE
(default ~/arkadeos-cache). Each app keeps only its newest files; manifest.json
lists what is cached. Fedora-specific packages follow the Fedora version of
the Bazzite base image.
"""
import json, os, re, shutil, subprocess, sys, urllib.request
from pathlib import Path

CACHE = Path(os.environ.get("ARKADEOS_CACHE", Path.home() / "arkadeos-cache"))
TOKEN = os.environ.get("GITHUB_TOKEN", "")
BASE = "ghcr.io/ublue-os/bazzite:stable"

# name: (repo, [asset regexes]); {fc} = Fedora major of the base image
RELEASES = {
    "proton-ge": ("GloriousEggroll/proton-ge-custom", [r"GE-Proton.*-x86_64\.tar\.gz$", r"GE-Proton.*-x86_64\.sha512sum$"]),
    "umu-launcher": ("Open-Wine-Components/umu-launcher", [r"umu-launcher-.*\.fc{fc}\.x86_64\.rpm$", r"umu-launcher-.*-zipapp\.tar$"]),
    "wowup": ("WowUp/WowUp.CF", [r"WowUp-CF-.*\.AppImage$"]),
    "lact": ("ilya-zlobintsev/LACT", [r"lact-.*\.x86_64\.fedora-{fc}\.rpm$"]),
    "vesktop": ("Vencord/Vesktop", [r"vesktop-.*\.x86_64\.rpm$"]),
    "sunshine": ("LizardByte/Sunshine", [r"Sunshine-.*\.fc{fc}\.x86_64\.rpm$"]),
    "ollama": ("ollama/ollama", [r"ollama-linux-amd64\.tar\.zst$", r"ollama-linux-amd64-rocm\.tar\.zst$"]),
    "mcontrolcenter": ("dmitry-s93/MControlCenter", [r"MControlCenter-.*-bin\.tar\.gz$"]),
    "lenovolegionlinux": ("johnfanv2/LenovoLegionLinux", ["SOURCE"]),
}
GIT = {
    "whitesur-kde": "https://github.com/vinceliuice/WhiteSur-kde",
    "whitesur-gtk": "https://github.com/vinceliuice/WhiteSur-gtk-theme",
    "whitesur-icons": "https://github.com/vinceliuice/WhiteSur-icon-theme",
    "whitesur-cursors": "https://github.com/vinceliuice/WhiteSur-cursors",
}
DIRECT = {
    "battlenet": ("Battle.net-Setup.exe", "https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe"),
}


def get(url, accept="application/vnd.github+json"):
    req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "arkadeos-prefetch"})
    if TOKEN and "api.github.com" in url:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    return urllib.request.urlopen(req, timeout=120)


def download(url, dest, accept="application/octet-stream"):
    tmp = dest.with_suffix(dest.suffix + ".part")
    with get(url, accept) as r, open(tmp, "wb") as f:
        shutil.copyfileobj(r, f)
    tmp.replace(dest)


def fedora_major():
    out = subprocess.run(["podman", "image", "inspect", BASE, "--format",
                          '{{index .Labels "org.opencontainers.image.version"}}'],
                         capture_output=True, text=True).stdout.strip()
    return out.split(".")[0] if out else ""


def pick(assets, pattern, fc):
    exact = [a for a in assets if re.search(pattern.replace("{fc}", re.escape(fc)), a["name"])] if fc else []
    if exact or "{fc}" not in pattern:
        return exact[0] if exact else next((a for a in assets if re.search(pattern, a["name"])), None)
    # base Fedora not built yet upstream: take the highest Fedora version offered
    rx = re.compile(pattern.replace("{fc}", r"(\d+)"))
    found = [(int(m.group(1)), a) for a in assets if (m := rx.search(a["name"]))]
    return max(found, key=lambda t: t[0])[1] if found else None


def main():
    fc = fedora_major()
    manifest, failed = {"fedora": fc}, []
    for name, (repo, patterns) in RELEASES.items():
        d = CACHE / "apps" / name
        d.mkdir(parents=True, exist_ok=True)
        try:
            rel = json.load(get(f"https://api.github.com/repos/{repo}/releases/latest"))
            keep = []
            for p in patterns:
                accept = "application/octet-stream"
                if p == "SOURCE":
                    # the API tarball endpoint refuses octet-stream (HTTP 415)
                    fname, url = f"{name}-{rel['tag_name']}.tar.gz", rel["tarball_url"]
                    accept = "application/vnd.github+json"
                else:
                    a = pick(rel["assets"], p, fc)
                    if not a:
                        failed.append(f"{name}: no asset for {p}")
                        continue
                    fname, url = a["name"], a["browser_download_url"]
                if not (d / fname).exists():
                    download(url, d / fname, accept)
                keep.append(fname)
            for old in d.iterdir():
                if old.name not in keep:
                    old.unlink()
            manifest[name] = {"version": rel["tag_name"], "files": keep}
        except Exception as e:
            failed.append(f"{name}: {e}")
    for name, url in GIT.items():
        d = CACHE / "git" / name
        try:
            if d.exists():
                subprocess.run(["git", "-C", str(d), "pull", "--ff-only", "-q"], check=True)
            else:
                subprocess.run(["git", "clone", "-q", "--depth", "1", url, str(d)], check=True)
            rev = subprocess.run(["git", "-C", str(d), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
            manifest[name] = {"version": rev}
        except Exception as e:
            failed.append(f"{name}: {e}")
    for name, (fname, url) in DIRECT.items():
        d = CACHE / "apps" / name
        d.mkdir(parents=True, exist_ok=True)
        try:
            download(url, d / fname)
            manifest[name] = {"files": [fname]}
        except Exception as e:
            failed.append(f"{name}: {e}")
    manifest["failed"] = failed
    (CACHE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
