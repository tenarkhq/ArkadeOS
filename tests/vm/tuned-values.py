"""The balanced profile's audio and SATA values as TuneD expands them when it
applies the profile (the Portal's mode, /usr/libexec/arkadeos/mode)."""
import tuned.consts as consts
import tuned.profiles as profiles
from tuned.profiles.variables import Variables
from tuned.utils.global_config import GlobalConfig

config = GlobalConfig()
dirs = config.get_list(consts.CFG_PROFILE_DIRS, consts.CFG_DEF_PROFILE_DIRS)
units = profiles.Loader(profiles.Locator(dirs), profiles.Factory(), profiles.Merger(), config,
                        Variables()).load(["arkadeos-balanced"]).units
variables = Variables()
print(variables.expand(units["audio"].options["timeout"]),
      variables.expand(units["scsi_host"].options["alpm"]))
