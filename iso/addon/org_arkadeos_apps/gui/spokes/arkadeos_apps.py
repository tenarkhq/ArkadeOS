"""The ArkadeOS apps spoke on the installation summary (T026): the Portal's
choice list, one tick per app; Steam always ticked; another maker's parts
greyed out on an identified machine."""

from gi.repository import GLib, Gtk

from pyanaconda.ui.categories.software import SoftwareCategory
from pyanaconda.ui.gui.spokes import NormalSpoke

from org_arkadeos_apps.common import ARKADEOS_APPS, GROUPS, VENDORS, allowed, items, tr

__all__ = ["ArkadeosAppsSpoke"]


def _title():
    return tr("ArkadeOS _apps", "ArkadeOS _programok")


class _Titled(type(NormalSpoke)):
    # The hub reads the title after the language was chosen.
    title = property(lambda cls: _title())


class ArkadeosAppsSpoke(NormalSpoke, metaclass=_Titled):
    builderObjects = ["arkadeosAppsWindow"]
    mainWidgetName = "arkadeosAppsWindow"
    uiFile = "arkadeos_apps.glade"
    category = SoftwareCategory
    icon = "applications-games-symbolic"
    title = property(lambda self: _title())

    @staticmethod
    def get_screen_id():
        return "arkadeos-apps"

    def __init__(self, *args):
        super().__init__(*args)
        self._proxy = ARKADEOS_APPS.get_proxy()
        self._checks = {}

    def initialize(self):
        super().initialize()
        self._grid = self.builder.get_object("appsGrid")
        self._intro = self.builder.get_object("introLabel")

    def refresh(self):
        self.window.set_property("window-name", _title().replace("_", "").upper())
        self._intro.set_text(tr(
            "Tick what you want on this machine. It is installed at the first login; "
            "everything can be changed later in the ArkadeOS Portal.",
            "Pipáld ki, mi legyen ezen a gépen. Az első bejelentkezéskor települ, később "
            "az ArkadeOS Portálban bármikor módosíthatod."))
        for child in self._grid.get_children():
            self._grid.remove(child)
        self._checks = {}
        detected = self._proxy.Detected
        chosen = set(self._proxy.Choice)
        catalog = items()
        hu = tr(False, True)
        n = 0
        for group, en, hun in GROUPS:
            members = [i for i in catalog if i["group"] == group]
            if not members:
                continue
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            label = Gtk.Label(xalign=0)
            label.set_markup("<b>{}</b>".format(GLib.markup_escape_text(hun if hu else en)))
            box.pack_start(label, False, False, 0)
            for item in members:
                name = item["hu"] if hu else item["en"]
                check = Gtk.CheckButton(label=name)
                if item["kind"] == "fixed":
                    check.set_active(True)
                    check.set_sensitive(False)
                    check.set_tooltip_text(tr("Always on this machine", "Mindig rajta van a gépen"))
                elif not allowed(item["id"], detected):
                    check.set_active(False)
                    check.set_sensitive(False)
                    check.set_tooltip_text(tr("This machine is not this maker's laptop",
                                              "Ez a gép nem ennek a gyártónak a laptopja"))
                else:
                    check.set_active(item["id"] in chosen)
                    self._checks[item["id"]] = check
                    if item["id"] == detected:
                        check.set_label(name + tr("  (detected)", "  (felismerve)"))
                box.pack_start(check, False, False, 0)
            self._grid.attach(box, n % 2, n // 2, 1, 1)
            n += 1
        self._grid.show_all()

    def apply(self):
        self._proxy.SetChoice([i for i, c in self._checks.items() if c.get_active()])

    @property
    def completed(self):
        return True

    @property
    def mandatory(self):
        return False

    @property
    def status(self):
        choice = self._proxy.Choice
        apps = len([i for i in choice if i not in VENDORS])
        text = tr("{} chosen", "{} kiválasztva").format(apps)
        makers = [i for i in choice if i in VENDORS]
        if makers:
            names = {"asus": "ASUS", "msi": "MSI", "legion": "Lenovo Legion"}
            text += " · " + ", ".join(names[m] for m in makers)
        return text

