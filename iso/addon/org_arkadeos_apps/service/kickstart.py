"""%addon org_arkadeos_apps: the chosen ids of the catalog, separated by spaces
or lines. Without the section the defaults and the detected maker are chosen."""

from pyanaconda.core.kickstart import KickstartSpecification
from pyanaconda.core.kickstart.addon import AddonData


class ArkadeosAppsData(AddonData):
    def __init__(self):
        super().__init__()
        self.ids = None

    def handle_header(self, args, line_number=None):
        self.ids = []

    def handle_line(self, line, line_number=None):
        self.ids.extend(line.split())

    def __str__(self):
        if self.ids is None:
            return ""
        return "\n%addon org_arkadeos_apps\n{}\n%end\n".format(" ".join(self.ids))


class ArkadeosAppsKickstartSpecification(KickstartSpecification):
    addons = {"org_arkadeos_apps": ArkadeosAppsData}
