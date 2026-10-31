import logging
import os

from dasbus.server.interface import dbus_interface
from dasbus.server.property import emits_properties_changed
from dasbus.typing import *  # pylint: disable=wildcard-import,unused-wildcard-import
from pyanaconda.core.configuration.anaconda import conf
from pyanaconda.core.dbus import DBus
from pyanaconda.core.signal import Signal
from pyanaconda.modules.common.base import KickstartService, KickstartModuleInterface
from pyanaconda.modules.common.containers import TaskContainer
from pyanaconda.modules.common.task import Task

from org_arkadeos_apps.common import ARKADEOS_APPS, VENDORS, allowed, default_choice, detect, items
from org_arkadeos_apps.service.kickstart import ArkadeosAppsKickstartSpecification

log = logging.getLogger(__name__)


class ArkadeosAppsService(KickstartService):
    def __init__(self):
        super().__init__()
        self.detected = detect()
        self.choice = default_choice(self.detected)
        self.choice_changed = Signal()
        log.info("ArkadeOS apps: machine %s, default choice %s", self.detected, self.choice)

    def publish(self):
        TaskContainer.set_namespace(ARKADEOS_APPS.namespace)
        DBus.publish_object(ARKADEOS_APPS.object_path, ArkadeosAppsInterface(self))
        DBus.register_service(ARKADEOS_APPS.service_name)

    @property
    def kickstart_specification(self):
        return ArkadeosAppsKickstartSpecification

    def process_kickstart(self, data):
        ids = data.addons.org_arkadeos_apps.ids
        if ids is not None:
            self.set_choice(ids)

    def setup_kickstart(self, data):
        data.addons.org_arkadeos_apps.ids = list(self.choice)

    def set_choice(self, ids):
        known = {i["id"]: i for i in items()}
        self.choice = sorted({i for i in ids if i in known and known[i]["kind"] != "fixed"
                              and allowed(i, self.detected)})
        self.choice_changed.emit()

    def install_with_tasks(self):
        return [WriteChoiceTask(conf.target.system_root, self.choice)]


@dbus_interface(ARKADEOS_APPS.interface_name)
class ArkadeosAppsInterface(KickstartModuleInterface):
    def connect_signals(self):
        super().connect_signals()
        self.watch_property("Choice", self.implementation.choice_changed)

    @property
    def Detected(self) -> Str:
        return self.implementation.detected

    @property
    def Choice(self) -> List[Str]:
        return self.implementation.choice

    @emits_properties_changed
    def SetChoice(self, ids: List[Str]):
        self.implementation.set_choice(ids)


class WriteChoiceTask(Task):
    """Writes the choice into the installed system: /etc/arkadeos/apps (for
    apps-install and the Portal's first start, which installs it without
    asking again: apps-from-installer) and /etc/arkadeos/vendor."""

    def __init__(self, sysroot, choice):
        super().__init__()
        self._sysroot = sysroot
        self._choice = choice

    @property
    def name(self):
        return "Write the ArkadeOS app choice"

    def run(self):
        etc = os.path.join(self._sysroot, "etc/arkadeos")
        os.makedirs(etc, exist_ok=True)
        apps = [i for i in self._choice if i not in VENDORS]
        makers = [i for i in self._choice if i in VENDORS]
        for name, lines in (("apps", apps), ("vendor", makers), ("apps-from-installer", [])):
            with open(os.path.join(etc, name), "w", encoding="utf-8") as f:
                f.write("".join(line + "\n" for line in lines))
        log.info("ArkadeOS apps written: %s, makers %s", apps, makers)
