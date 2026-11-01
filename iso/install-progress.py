#!/usr/bin/python3
"""Makes the installer show how far the system's download is (T065).

Fedora's installer says only "Deployment starting: <image>" for the many
minutes `ostree container image deploy` downloads and writes the image. This
adds a line, updated every 2 seconds, in the installer's language:

    A rendszer letöltése: 2,4 / 6,6 GB (36%) · kb. 7 perc van hátra
    Downloading the system: 2.4 / 6.6 GB (36%) · about 7 min left

and, once the download is done, that writing to the disk takes a few minutes.
The size is the image's layers in the registry; what has arrived is what the
network cards received since the deploy started.

    install-progress.py <installation.py>

edits Anaconda's rpm_ostree/installation.py in place, and fails when the
installer's code is not the one this was written for (Fedora 44,
anaconda 44.30).
"""
import sys

DEPLOY = '''            safe_exec_program(
                "ostree",
                args,
                env_add={"LC_ALL": "C.UTF-8"},
            )
'''

PROGRESS = '''# ArkadeOS (T065): the download of the system image, shown while it runs.
import json as _ark_json
import re as _ark_re
import threading as _ark_threading
import time as _ark_time
import urllib.error as _ark_error
import urllib.parse as _ark_parse
import urllib.request as _ark_request


def _arkadeos_image_size(ref):
    """Bytes of the image's layers in its registry, 0 when unknown."""
    try:
        name, digest = ref.split("@", 1) if "@" in ref else (ref, None)
        if digest is None:
            name, _, digest = name.rpartition(":")
            if not name or "/" in digest:
                name, digest = ref, "latest"
        host, _, repo = name.partition("/")
        headers = {"Accept": ", ".join([
            "application/vnd.oci.image.index.v1+json",
            "application/vnd.oci.image.manifest.v1+json",
            "application/vnd.docker.distribution.manifest.list.v2+json",
            "application/vnd.docker.distribution.manifest.v2+json"])}

        def get(url):
            try:
                with _ark_request.urlopen(_ark_request.Request(url, headers=headers), timeout=20) as reply:
                    return _ark_json.load(reply)
            except _ark_error.HTTPError as e:
                # Public images: an anonymous token from the registry.
                challenge = e.headers.get("WWW-Authenticate", "")
                if e.code != 401 or "Authorization" in headers or not challenge.startswith("Bearer "):
                    raise
                params = dict(_ark_re.findall(r'(\\w+)="([^"]*)"', challenge))
                realm = params.pop("realm")
                with _ark_request.urlopen(realm + "?" + _ark_parse.urlencode(params), timeout=20) as reply:
                    token = _ark_json.load(reply)
                headers["Authorization"] = "Bearer " + (token.get("token") or token["access_token"])
                return get(url)

        manifest = get("https://{}/v2/{}/manifests/{}".format(host, repo, digest))
        for entry in manifest.get("manifests", []):
            if entry.get("platform", {}).get("architecture") == "amd64":
                manifest = get("https://{}/v2/{}/manifests/{}".format(host, repo, entry["digest"]))
                break
        return sum(layer.get("size", 0) for layer in manifest.get("layers", []))
    except Exception as e:  # pylint: disable=broad-except
        log.info("ArkadeOS download: size of %s unknown: %s", ref, e)
        return 0


def _arkadeos_received():
    """Bytes the network cards received so far."""
    received = 0
    with open("/proc/net/dev") as f:
        for line in f.readlines()[2:]:
            iface, _, counters = line.partition(":")
            if iface.strip() != "lo":
                received += int(counters.split()[0])
    return received


class _ArkadeosProgress:
    """Reports the image's download every 2 seconds while the deploy runs."""

    def __init__(self, task, ref):
        self._task, self._ref = task, ref
        self._stop = _ark_threading.Event()
        self._thread = _ark_threading.Thread(target=self._run, daemon=True)
        try:
            lang = LOCALIZATION.get_proxy().Language
        except Exception:  # pylint: disable=broad-except
            lang = os.environ.get("LANG", "")
        self._hu = lang.startswith("hu")

    def __enter__(self):
        self._thread.start()
        return self

    def __exit__(self, *exc):
        self._stop.set()
        self._thread.join(5)
        return False

    def _gb(self, n):
        text = "{:.1f}".format(n / 1e9)
        return text.replace(".", ",") if self._hu else text

    def message(self, got, total, seconds_left):
        if total and got >= total:
            return ("Írás a lemezre… (ez néhány percig tart, folyamatjelző nélkül)" if self._hu else
                    "Writing to the disk… (this takes a few minutes, with no progress shown)")
        if not total:
            return ("A rendszer letöltése: {} GB" if self._hu else
                    "Downloading the system: {} GB").format(self._gb(got))
        text = ("A rendszer letöltése: {} / {} GB ({}%)" if self._hu else
                "Downloading the system: {} / {} GB ({}%)").format(
            self._gb(got), self._gb(total), min(99, int(got * 100 // total)))
        if seconds_left is None:
            return text
        minutes = round(seconds_left / 60)
        if minutes < 1:
            return text + (" · kevesebb mint 1 perc van hátra" if self._hu else " · less than a minute left")
        return text + (" · kb. {} perc van hátra" if self._hu else " · about {} min left").format(minutes)

    def _run(self):
        try:
            start = _arkadeos_received()
            total = _arkadeos_image_size(self._ref)
            log.info("ArkadeOS download: %s, %d bytes", self._ref, total)
            window = [(_ark_time.monotonic(), 0)]
            while not self._stop.wait(2):
                got = _arkadeos_received() - start
                now = _ark_time.monotonic()
                window = [s for s in window if now - s[0] <= 30] + [(now, got)]
                rate = (got - window[0][1]) / max(now - window[0][0], 1)
                left = (total - got) / rate if total and rate > 0 else None
                text = self.message(got, total, left)
                self._task.report_progress(text)
                log.info("ArkadeOS download: %s", text)
        except Exception as e:  # pylint: disable=broad-except
            log.info("ArkadeOS download: no progress shown: %s", e)


'''


def main(path):
    with open(path, encoding="utf-8") as f:
        code = f.read()
    if code.count(DEPLOY) != 1 or code.count("\nclass DeployOSTreeTask(Task):\n") != 1:
        sys.exit(f"{path}: not the installer code install-progress.py was written for")
    wrapped = "            with _ArkadeosProgress(self, ref):\n" + "".join(
        "    " + line for line in DEPLOY.splitlines(keepends=True))
    code = code.replace(DEPLOY, wrapped).replace(
        "\nclass DeployOSTreeTask(Task):\n", "\n" + PROGRESS + "class DeployOSTreeTask(Task):\n")
    with open(path, "w", encoding="utf-8") as f:
        f.write(code)


if __name__ == "__main__":
    main(sys.argv[1])
