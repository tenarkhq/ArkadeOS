# ArkadeOS

**Fast, gaming-first Linux built on Fedora Atomic.**
A clean KDE Plasma desktop, one image for NVIDIA, AMD and Intel graphics, Steam and Proton, Battle.net, smart power profiles, and atomic updates you can roll back.

> **Status: early development (November 2026).** Not ready for daily use yet. "Implemented" means the feature is in the image; "under development" means it is still being built. See [Project status](#project-status).

![ArkadeOS desktop, dark look](art/screenshots/desktop-dark.png)

---

## Why ArkadeOS

- **Built for games only.** No background indexing, no services you don't need. The kernel, scheduler and power settings are tuned for low latency and high frame rates.
- **KDE Plasma in ArkadeOS Glass.** Our own sky-blue glass look, light and dark: one glass taskbar at the bottom with the pinned apps in the middle, ArkadeOS's own app and tray icons. Menus in the windows, quick search on Meta+Space, window snapping, Alt+Tab previews, clipboard history.
- **Can't be broken by an update.** The whole system is one image. A bad update? Reboot and pick the previous one.
- **One image for every gaming graphics card.** NVIDIA, AMD and Intel: the NVIDIA driver is built in and only runs where an NVIDIA card is. See [Supported graphics cards](#supported-graphics-cards).

## Features

| | Feature | Status |
|---|---|---|
| 🎮 | Steam, Proton-GE, Proton Experimental, Gamescope, MangoHud (set up in MangoJuice), GameMode, Protontricks | implemented |
| ⚔️ | One-click Battle.net with World of Warcraft | implemented |
| 🧰 | WowUp addon manager with CurseForge, finds the WoW folder by itself | implemented |
| 🛒 | EA app, Ubisoft Connect, Heroic (Epic, GOG, Amazon), Lutris | implemented |
| 🪟 | Borderless windowed games run full screen, above the taskbar | implemented |
| 🎞️ | Frame generation (lsfg-vk) per game, instant replay (GPU Screen Recorder) | implemented |
| 💬 | Discord preinstalled, Vesktop optional for Wayland screen sharing with audio | implemented |
| 🧲 | qBittorrent: free, open-source torrent client without ads (ticked by default, can be left out) | implemented |
| 🎙️ | Microphone noise filter and low-latency audio | implemented |
| ⚡ | Gaming kernel, sched_ext scheduler, NTSYNC | implemented |
| 🔋 | Power profiles: Battery, Balanced, Gaming, Max, WoW, switching automatically, per game | implemented |
| 💻 | ASUS gaming laptops (asusctl): the power profile also sets the firmware mode | implemented |
| 💻 | MSI (msi-ec, MControlCenter), Lenovo Legion (LenovoLegionLinux); battery care at 80% | implemented |
| 🌈 | RGB that follows the power profile (OpenRGB, ASUS Aura) | implemented |
| 🖱️ | Logitech and Razer mice, ASUS ROG keyboards, monitor control, LACT for the graphics card | implemented |
| 🖥️ | KDE Plasma 6 in ArkadeOS Glass: own glass look, wallpapers, app and tray icons, System Settings and Portal in the same look; light and dark switching by the time of day, one taskbar | implemented |
| 📌 | Anything pinned on the taskbar stays there: Steam games, Windows programs, Chrome web apps | implemented |
| 🧩 | ArkadeOS Portal: pick apps at first login, add or remove anything later | implemented |
| 🤖 | Optional AI tools: Claude and Codex, desktop apps and command line | implemented |
| 🔄 | Atomic image updates with rollback, builds of the last 90 days, factory reset that keeps your files | implemented |
| 📦 | Small updates: ArkadeOS's own files, Proton-GE and the boot image are layers of their own, so an update downloads only the part that changed | implemented |
| 💿 | Installer next to Windows, with Windows in the boot menu; shows the download's progress and time left | implemented |
| 🔒 | Encrypted disk unlocked by the TPM, firewall on, telemetry off, nothing running in the background unless you turn it on | implemented |

## Screenshots

| | |
|---|---|
| ![Light look](art/screenshots/desktop-light.png) | ![Quick Settings: ArkadeOS Light, Dark or Automatic](art/screenshots/settings.png) |
| Light look | Quick Settings: light, dark or automatic |
| ![ArkadeOS Portal at the first login: tick what you want](art/screenshots/portal.png) | ![Login screen](art/screenshots/login.png) |
| ArkadeOS Portal at the first login: tick what you want, change it any time | Login screen |

Taken automatically from the 14 November 2026 build in a virtual machine (1280×800 screen).

## Supported graphics cards

| Maker | Supported |
|---|---|
| NVIDIA | GeForce GTX 16 series, RTX 20 series and newer, also in laptops next to the processor's graphics |
| AMD | Radeon RX 400 / 500 (Polaris) and newer; Ryzen processors with Radeon graphics |
| Intel | Arc graphics cards; Iris Xe (11th gen Core) and newer built-in graphics |

Older cards (NVIDIA GTX 10 series and earlier, AMD Radeon before the RX 400) are not supported: ArkadeOS is made for gaming, and these cards cannot run today's games. The installer checks the card: it stops when an unsupported card is the only one, and notes it when the machine also has supported graphics.

One image, `arkadeos`, serves every supported card. Machines installed from the former `arkadeos-nvidia` image keep following that name, which gets the same builds. [Driver coverage](docs/drivers.md) lists which other chips work out of the box.

## Install

**ISO:** a public download comes with the beta. Today's installer ISOs are test builds. They download the newest system image while installing, so the system you get is always up to date.

**Already on Fedora Atomic, Bazzite or another bootc system?** Switch to ArkadeOS:

```bash
sudo bootc switch ghcr.io/tenarkhq/arkadeos:stable
```

Reboot to finish. The same image works with NVIDIA, AMD and Intel graphics.

**Roll back to the previous version:**

```bash
arkadeos-update rollback
```

The ArkadeOS Portal does the same from a window, and also switches the channel (stable, or testing for each build three days earlier) and goes back to any build of the last 90 days.

## Power profiles

| Profile | When | What it does |
|---|---|---|
| Battery | Automatically on battery | Power-saving CPU mode, no boost, deep sleep states, discrete GPU off |
| Balanced | Automatically on AC | Balanced CPU mode with boost; nothing else saves power (sound, Wi-Fi, USB and disk links stay awake), only an unused graphics card may sleep |
| Gaming | Automatically while a game runs | Performance CPU mode, low-latency scheduler, GPU boost, no power saving anywhere, huge memory pages for the game |
| Max | Manually, on AC only | Deep sleep states off, fans and platform profile at maximum |
| WoW | Automatically while World of Warcraft runs, or manually | Gaming for the CPU; on a laptop the graphics card is held back to 80% of its power (TGP; on ASUS also Dynamic Boost off) so the shared power and cooling go to the CPU. While the card itself is the bottleneck it gets more, up to all of it, so a weaker card is not slowed down. Desktops: nothing held back. The lowest share is `percent=` in `/etc/arkadeos/gpu-cap.conf`. On a processor with two groups of cores (the two CCDs of a Ryzen 9) the game runs on one of them; `arkadeos-power ccd off` lets it use all cores |

## Project status

*Updated 14 November 2026.*

**Built on Fedora 45 since 12 November 2026:** Bazzite's Fedora 45 base with kernel 7.3, KDE Plasma 6.8, Mesa 26.2 and NVIDIA driver 620. The stable channel gets it three days later. An update that changes only ArkadeOS's own files downloads about 7 MB of the 6 GB image.

**Every build is tested automatically.** Each change to `main` builds the image and boots it in a virtual machine that logs in, opens the apps, switches the looks and profiles, starts a Windows program under Proton, updates and rolls back. A separate test installs ArkadeOS from the ISO onto an encrypted disk and boots the installed system. Latest results (14 November 2026):

| Test | Checks | Result |
|---|---|---|
| `arkadeos` image in a VM | 226 | ✅ all pass |
| Optional apps from the Portal | 18 | ✅ all pass |
| Update from the previous build | 12 | ✅ all pass |
| Install from the ISO (encryption, TPM unlock, Intel RST, download progress) | 42 | ✅ all pass (9 November) |

**First tests on real hardware** (1 November 2026, ASUS gaming laptop with an NVIDIA RTX 5070 Laptop GPU):

| What | Result |
|---|---|
| Battle.net installs, World of Warcraft starts and runs | ✅ |
| WowUp finds the WoW folder, installs and updates addons (the edition with Wago; the CurseForge edition took its place on 12 November) | ✅ |
| Unplugging the charger switches to Battery, starting WoW switches to the WoW profile | ✅ |
| The power profile also sets ASUS's firmware mode (Quiet, Balanced, Performance) | ✅ |
| The keyboard lighting follows the power profile | ✅ |
| Terminal welcome | ✅ |
| Frame generation in WoW | works, but its added latency makes spells feel sluggish in WoW; off by default, can be turned on per game |
| Laptop screen brightness | ❌ not adjustable yet on this laptop, being fixed |

**ArkadeOS compared with Windows on the same laptop** (1–2 November 2026, Windows measured on 30 October):

| | Windows | ArkadeOS | Difference |
|---|---|---|---|
| World of Warcraft, average fps | 48.0 | 55.7 | **+16%** |
| World of Warcraft, 1% low fps | 19.7 | 37.3 | **+90%** (1.9×) |
| WoW Mythic+ boss fight, average fps | 102 | 111 | **+9%** |
| WoW Mythic+ boss fight, 1% low fps | 39 | 57 | **+46%** |
| Memory in use when idle | 10.2 GB | 4.5 GB | **−56%** (5.7 GB less) |

Measured the same way on both systems: the same World of Warcraft folder copied over from Windows, with the same addons and graphics settings (preset 8, 2560×1600, DX11; DXVK on ArkadeOS), standing at the fountain in Silvermoon, three 60-second recordings each (CapFrameX on Windows, MangoHud on ArkadeOS). Memory: five minutes after start, nothing open. Runs, average / 1% low: Windows 52/25, 48/15, 44/19; ArkadeOS 58/38, 57/40, 52/34. Boss fight: the end boss of a Blindingvale +10 Mythic+ dungeon, one fight on each system; a group fight varies more from run to run than standing in a city.

**Next:** more real-hardware checks (external monitors, peripherals, desktop PCs, an AMD Radeon machine), then the first stable build, the public beta and the ISO download.

## Known limitations

- **Games with kernel-level anti-cheat do not run on Linux**: Valorant, League of Legends, Fortnite, most recent Call of Duty titles. No Linux distribution can fix this.
- **Secure Boot with NVIDIA:** you confirm the ArkadeOS signing key once during install. The installer walks you through it.
- **DX12 on NVIDIA** is still slower under Proton than on Windows. Where a game offers DX11, ArkadeOS uses whichever mode is faster.
- **No PC sound on HomePod or Apple TV over AirPlay.** Since Apple's 27 releases these devices refuse AirPlay 1 senders, and Linux (PipeWire) has no AirPlay 2 audio sender yet; speakers that accept only AirPlay 2 do not show up at all. Mirroring an iPhone or Mac screen to ArkadeOS works.
- **x86-64 PCs only.** Steam, Proton and the games are x86 software, so ArkadeOS does not run on Apple Silicon Macs or other ARM machines. x86 emulation in a virtual machine there is far too slow for games.

## Build it yourself

```bash
git clone https://github.com/tenarkhq/ArkadeOS.git
cd ArkadeOS
podman build -t arkadeos --build-arg PROTON_GE_VERSION=GE-Proton11-12 -f Containerfile .
```

`PROTON_GE_VERSION` is the GE-Proton release that goes into the image: the newest name on [its releases page](https://github.com/GloriousEggroll/proton-ge-custom/releases). The build starts from Bazzite's newest base; `--build-arg BASE_IMAGE=…` with the image named in `bases.txt` gives the base this commit was tested on.

## Built on

- [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) 45
- [Bazzite](https://bazzite.gg) and [Universal Blue](https://universal-blue.org)
- [KDE Plasma](https://kde.org/plasma-desktop/)

## License

ArkadeOS's own code is licensed under the [Apache License 2.0](LICENSE). Every bundled component keeps its own license.
The ArkadeOS name and logo are not covered by the license. Forks must use a different name.

ArkadeOS is not affiliated with Apple, Valve, Blizzard, NVIDIA or AMD.
