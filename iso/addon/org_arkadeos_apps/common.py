"""ArkadeOS app choice in the installer (T026): the same list as the Portal's
first start, read from copies of the image's catalog.tsv and apps.list that
iso/build.sh puts next to this file. The maker rules are those of
arkadeos-vendor: a maker's parts only on that maker's laptop, free choice
only where the firmware does not tell."""

import os

from dasbus.identifier import DBusServiceIdentifier
from pyanaconda.core.dbus import DBus
from pyanaconda.modules.common.constants.namespaces import ADDONS_NAMESPACE

ARKADEOS_APPS = DBusServiceIdentifier(namespace=(*ADDONS_NAMESPACE, "ArkadeosApps"), message_bus=DBus)

DATA = os.path.join(os.path.dirname(__file__), "data")
VENDORS = ("asus", "msi", "legion")
GROUPS = [
    ("base", "Basic apps", "Alap appok"),
    ("chat", "Chat", "Csevegés"),
    ("stores", "Game stores", "Játékáruházak"),
    ("gaming", "Gaming", "Játék"),
    ("stream", "Streaming and recording", "Streamelés és felvétel"),
    ("desktop", "Desktop", "Asztal"),
    ("ai", "AI", "AI"),
    ("dev", "Developer tools", "Fejlesztői eszközök"),
    ("vendor", "Laptop maker (only the detected one can be chosen)",
     "Gépgyártó (csak a felismert választható)"),
]
LAPTOP = {"8", "9", "10", "14", "30", "31", "32"}
NOT_LAPTOP = {"3", "4", "5", "6", "7", "13", "15", "16", "17", "23", "24", "25", "35", "36"}
NO_DATA = ("to be filled", "system manufacturer", "default string", "o.e.m", "not applicable",
           "not specified")


def hungarian():
    return os.environ.get("LANG", "").startswith("hu")


def tr(en, hu):
    return hu if hungarian() else en


def items():
    """The catalog: id, group, kind and both names of every choice."""
    result = []
    with open(os.path.join(DATA, "catalog.tsv"), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            item_id, group, kind, ref, en, hu = line.split("\t")
            result.append({"id": item_id, "group": group, "kind": kind, "ref": ref, "en": en, "hu": hu})
    return result


def defaults():
    """The apps that come by default: apps.list's always and on ones, and the
    store launchers the image brings (image-apps: its desktop files)."""
    on = set()
    with open(os.path.join(DATA, "image-apps"), encoding="utf-8") as f:
        image_apps = set(f.read().split())
    for item in items():
        if item["kind"] == "launcher" and item["ref"] in image_apps:
            on.add(item["id"])
    with open(os.path.join(DATA, "apps.list"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                item_id, _ref, default = line.split("|")
                if default in ("always", "on"):
                    on.add(item_id)
    return on


def _read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def detect(dmi="/sys/class/dmi/id"):
    """asus | msi | legion | other | unknown, as arkadeos-vendor detect."""
    vendor = _read(os.path.join(dmi, "sys_vendor"))
    product = " ".join(_read(os.path.join(dmi, n)) for n in ("product_name", "product_family", "product_version"))
    chassis = _read(os.path.join(dmi, "chassis_type"))
    if not vendor or any(s in vendor.lower() for s in NO_DATA):
        return "unknown"
    maker = None
    if vendor.startswith("ASUS"):
        maker = "asus"
    elif vendor.startswith(("Micro-Star", "MSI")):
        maker = "msi"
    elif vendor.startswith("LENOVO"):
        maker = "legion" if ("Legion" in product or "LOQ" in product) else "lenovo"
    if maker is None:
        return "other"
    if chassis in NOT_LAPTOP:
        return "other"
    if chassis not in LAPTOP:
        return "unknown"
    return "other" if maker == "lenovo" else maker


def allowed(item_id, detected):
    """Whether this choice can be ticked on this machine."""
    if item_id not in VENDORS:
        return True
    return detected in ("unknown", item_id)


def default_choice(detected):
    chosen = set(defaults())
    if detected in VENDORS:
        chosen.add(detected)
    return sorted(chosen)
