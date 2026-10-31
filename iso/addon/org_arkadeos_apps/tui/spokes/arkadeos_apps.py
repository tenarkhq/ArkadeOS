"""The ArkadeOS apps spoke of the text installer (T026): the same choice as
the graphical one, one numbered tick per app."""

from simpleline.render.containers import ListColumnContainer
from simpleline.render.prompt import Prompt
from simpleline.render.screen import InputState
from simpleline.render.widgets import CheckboxWidget, TextWidget

from pyanaconda.ui.categories.software import SoftwareCategory
from pyanaconda.ui.tui.spokes import NormalTUISpoke

from org_arkadeos_apps.common import ARKADEOS_APPS, VENDORS, allowed, items, tr

__all__ = ["ArkadeosAppsSpoke"]


class ArkadeosAppsSpoke(NormalTUISpoke):
    category = SoftwareCategory

    @staticmethod
    def get_screen_id():
        return "arkadeos-apps"

    def __init__(self, *args):
        super().__init__(*args)
        self.title = tr("ArkadeOS apps", "ArkadeOS programok")
        self._proxy = ARKADEOS_APPS.get_proxy()
        self._chosen = set()
        self._container = None

    def setup(self, args=None):
        super().setup(args)
        self._chosen = set(self._proxy.Choice)
        return True

    def refresh(self, args=None):
        super().refresh(args)
        detected = self._proxy.Detected
        self.window.add_with_separator(TextWidget(tr(
            "Installed at the first login; can be changed later in the ArkadeOS Portal.",
            "Az első bejelentkezéskor települ; később az ArkadeOS Portálban módosítható.")))
        self._container = ListColumnContainer(columns=2)
        for item in items():
            if item["kind"] == "fixed" or not allowed(item["id"], detected):
                continue
            name = tr(item["en"], item["hu"])
            self._container.add(CheckboxWidget(title=name, completed=item["id"] in self._chosen),
                                callback=self._toggle, data=item["id"])
        self.window.add_with_separator(self._container)

    def _toggle(self, item_id):
        self._chosen.symmetric_difference_update({item_id})

    def input(self, args, key):
        if self._container.process_user_input(key):
            return InputState.PROCESSED_AND_REDRAW
        if key.lower() == Prompt.CONTINUE:
            self.apply()
            return InputState.PROCESSED_AND_CLOSE
        return super().input(args, key)

    def apply(self):
        self._proxy.SetChoice(sorted(self._chosen))

    @property
    def completed(self):
        return True

    @property
    def mandatory(self):
        return False

    @property
    def status(self):
        choice = self._proxy.Choice
        return tr("{} chosen", "{} kiválasztva").format(len([i for i in choice if i not in VENDORS]))
