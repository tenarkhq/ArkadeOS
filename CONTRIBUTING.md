# Contributing to ArkadeOS

## Background load budget

ArkadeOS is for games first. Nothing we add may slow the system or a game
down. Every change follows these rules (T050):

1. **Only what was chosen gets installed.** Optional apps and vendor parts
   (ASUS, MSI, Lenovo) are installed only when picked in the installer's
   choice screen or later in the ArkadeOS Portal, and vendor parts only for
   that vendor's machines.
2. **Nothing starts by itself unless it has to.** Services start when an app
   asks for them (D-Bus or socket activation). AirPlay is off by default
   and runs only when switched on.
3. **RGB effects run from the devices' own memory.** Effects computed on the
   machine (software effects) are stopped by the Gaming profile.
4. **The Gaming profile pauses background work while a game runs:** update
   downloads, file indexing, a loaded AI model, software RGB.
5. **Measured at every milestone** against the baseline measurement (T005):
   idle memory and CPU, the list of background services, WoW FPS. A change that
   makes these worse does not go in.

What enforces them today:

| Rule | Where |
|---|---|
| 1 | `system_files/usr/share/arkadeos/apps.list` (`off` = only when chosen); vendor parts run only for the chosen or detected maker: `usr/libexec/arkadeos/vendor-set` masks the others' services, unloads their drivers and hides their apps at every boot |
| 2 | `tests/vm/run.sh` checks AirPlay is off by default; `tests/vm` records the running services and idle load (`idle.txt`). The key remapper's service runs only for a user with a preset (`input-remapper.service.d`), the PlayStation controller helper when such a controller is connected (`90-arkadeos-ds-inhibit.rules`); what watches all the time looks cheaply: the game watcher reads only new processes, the power switch reads the profile when it changes |
| 3, 4 | `usr/libexec/arkadeos/game-profile` (the game watcher) keeps a mark while a game runs; `usr/libexec/arkadeos/no-game-running` reads it, and updates, snapshot cleanup, disk trim and the firmware list wait (their `*.service.d/50-arkadeos-not-while-gaming.conf`); file indexing is off |
| 5 | `idle.txt` of each VM test run; WoW FPS on real hardware at milestones |

## Changes

- Every change belongs to a task on the board (T001…); its commit message
  starts with the task ID.
- The image is built locally before a push
  (`podman build -f Containerfile .`), and every push runs the VM test
  (`tests/vm/run.sh`), which boots the installed image and checks the
  features one by one.
