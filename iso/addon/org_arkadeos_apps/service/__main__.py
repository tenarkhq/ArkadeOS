from pyanaconda.modules.common import init
init()

from org_arkadeos_apps.service.arkadeos_apps import ArkadeosAppsService
service = ArkadeosAppsService()
service.run()
