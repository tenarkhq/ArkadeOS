# ArkadeOS

**Fast, gaming-first Linux built on Fedora Atomic.**
A macOS-style KDE desktop, NVIDIA and AMD images, Steam and Proton, Battle.net, smart power profiles, and atomic updates you can roll back.

> **Status: early development, testing builds only (November 2026).** Not ready for daily use yet. "In testing" means the feature is in the image and checked automatically in a virtual machine on every build; "tested on hardware" means it was also tried on a real gaming laptop. See [Project status](#project-status).

![ArkadeOS desktop, dark look](art/screenshots/desktop-dark.png)

---

## Why ArkadeOS

- **Built for games only.** No background indexing, no services you don't need. The kernel, scheduler and power settings are tuned for low latency and high frame rates.
- **Looks and feels like macOS.** Top bar with a global menu, a centered dock, Spotlight-style search, gestures. From Windows it keeps only what helps: window snapping, Alt+Tab previews, clipboard history.
- **Can't be broken by an update.** The whole system is one image. A bad update? Reboot and pick the previous one.
- **Works for everyone.** Separate images for NVIDIA and AMD/Intel graphics. The installer picks the right one for your machine.

## Features

| | Feature | Status |
|---|---|---|
| 🎮 | Steam, Proton-GE, Proton Experimental, Gamescope, MangoHud, GameMode | in testing |
| 🕹️ | Game Mode session: boot straight into full-screen Steam, or switch from the desktop | in testing |
| ⚔️ | One-click Battle.net with World of Warcraft, WowUp for addons | **tested on hardware** |
| 🛒 | EA app, Ubisoft Connect, Heroic (Epic, GOG, Amazon), Lutris | in testing |
| 🪟 | Borderless windowed games run full screen, above the top bar and the dock | in testing |
| 🎞️ | Frame generation (lsfg-vk) per game, instant replay (GPU Screen Recorder), OBS, Sunshine | in testing |
| 💬 | Discord preinstalled, Vesktop optional for Wayland screen sharing with audio | in testing |
| 🧲 | qBittorrent: free, open-source torrent client without ads (ticked by default, can be left out) | in testing |
| 🎙️ | Microphone noise filter and low-latency audio | in testing |
| ⚡ | Gaming kernel, sched_ext scheduler, NTSYNC | in testing |
| 🔋 | Power profiles: Battery, Balanced, Gaming, Max, WoW, switching automatically, per game | **tested on hardware** |
| 💻 | ASUS gaming laptops (asusctl): the power profile also sets the firmware mode | **tested on hardware** |
| 💻 | MSI (msi-ec, MControlCenter), Lenovo Legion (LenovoLegionLinux); battery care at 80% | in testing |
| 🌈 | RGB that follows the power profile (OpenRGB, ASUS Aura) | **tested on hardware** |
| 🖱️ | Logitech and Razer mice, ASUS ROG keyboards, monitor control, LACT for the graphics card | in testing |
| 🍎 | macOS-style KDE Plasma 6 with the WhiteSur theme, light and dark, metal trash on the dock | in testing |
| 📌 | Anything pinned on the dock stays there: Steam games, Windows programs, Chrome web apps | in testing |
| 🧩 | ArkadeOS Portal: pick apps at first login, add or remove anything later | in testing |
| 🤖 | Optional AI pack: local models (Ollama, Open WebUI) sized to your GPU, AI command-line tools | in testing |
| 🔄 | Atomic image updates with rollback, builds of the last 90 days, factory reset that keeps your files | in testing |
| 📦 | Small updates: the image is split into about 100 layers, so an update downloads only what changed | in testing |
| 💿 | Installer next to Windows, with Windows in the boot menu; shows the download's progress and time left | in testing |
| 🔒 | Encrypted disk unlocked by the TPM, firewall on, telemetry off, nothing running in the background unless you turn it on | in testing |

## Screenshots

| | |
|---|---|
| ![Light look with the Finder-style file manager](art/screenshots/desktop-light.png) | ![Quick Settings: ArkadeOS Light, Dark or Automatic](art/screenshots/settings.png) |
| Light look, Finder-style file manager | Quick Settings: light, dark or automatic |
| ![ArkadeOS Portal: tick to install, untick to remove](art/screenshots/portal.png) | ![Login screen](art/screenshots/login.png) |
| ArkadeOS Portal: tick to install, untick to remove | Login screen |

Taken by the automatic VM test of the 2 November 2026 testing build (1280×800 virtual screen).

## Images

| Image | For |
|---|---|
| `arkadeos` | AMD and Intel graphics |
| `arkadeos-nvidia` | NVIDIA GTX 16xx / RTX 20xx and newer, including hybrid laptops |

Older NVIDIA cards (GTX 10xx and earlier) get the `arkadeos` image with the open nouveau driver: they work, but games run slower than on Windows. [Driver coverage](docs/drivers.md) lists which chips work out of the box.

## Install

**ISO:** a public download comes with the beta. Today's installer ISOs are test builds. They download the newest system image while installing, so the system you get is always up to date.

**Already on Fedora Atomic, Bazzite or another bootc system?** Switch to ArkadeOS. Until the first stable release only the testing channel exists:

```bash
sudo bootc switch ghcr.io/tenarkhq/arkadeos-nvidia:testing
```

Use `arkadeos` instead of `arkadeos-nvidia` for AMD or Intel graphics. Reboot to finish.

**Roll back to the previous version:**

```bash
arkadeos-update rollback
```

The ArkadeOS Portal does the same from a window, and also switches the channel (stable or testing) and goes back to any build of the last 90 days.

## Power profiles

| Profile | When | What it does |
|---|---|---|
| Battery | Automatically on battery | Power-saving CPU mode, no boost, deep sleep states, discrete GPU off |
| Balanced | Automatically on AC | Balanced CPU mode with boost |
| Gaming | Automatically while a game runs | Performance CPU mode, low-latency scheduler, GPU boost |
| Max | Manually, on AC only | Deep sleep states off, fans and platform profile at maximum |
| WoW | Automatically while World of Warcraft runs, or manually | Gaming for the CPU; on a laptop the graphics card is held back to 80% of its power (TGP; on ASUS also Dynamic Boost off) so the shared power and cooling go to the CPU. While the card itself is the bottleneck it gets more, up to all of it, so a weaker card is not slowed down. Desktops: nothing held back. The lowest share is `percent=` in `/etc/arkadeos/gpu-cap.conf` |

## Project status

*Updated 2 November 2026.*

**Every build is tested automatically.** Each change to `main` builds both images and boots them in a virtual machine that logs in, opens the apps, switches the looks and profiles, starts a Windows program under Proton, updates and rolls back. A separate test installs ArkadeOS from the ISO onto an encrypted disk and boots the installed system. Latest results:

| Test | Checks | Result |
|---|---|---|
| `arkadeos` image in a VM | 159 | ✅ all pass |
| `arkadeos-nvidia` image in a VM | 159 | ✅ all pass |
| Optional apps from the Portal | 40 | ✅ all pass |
| Update from the previous build | 9 | ✅ all pass |
| Install from the ISO (encryption, TPM unlock, Intel RST, download progress) | 60 | ✅ all pass |

**First tests on real hardware** (1 November 2026, ASUS gaming laptop with an NVIDIA RTX 5070 Laptop GPU):

| What | Result |
|---|---|
| Battle.net installs, World of Warcraft starts and runs | ✅ average 61–63 fps, 1% low 46 fps |
| World of Warcraft compared with Windows on the same laptop | **27–31% higher average fps** (61–63 vs 48.0) and **2.3× the 1% low** (46 vs 19.7) |
| WowUp finds the WoW folder, installs and updates addons | ✅ |
| Unplugging the charger switches to Battery, starting WoW switches to the WoW profile | ✅ |
| The power profile also sets ASUS's firmware mode (Quiet, Balanced, Performance) | ✅ |
| The keyboard lighting follows the power profile | ✅ |
| Terminal welcome | ✅ |
| Frame generation in WoW | works, but its added latency makes spells feel sluggish in WoW; off by default, can be turned on per game |
| Laptop screen brightness | ❌ not adjustable yet on this laptop, being fixed |

Measured the same way on both systems: the same World of Warcraft folder copied over from Windows, with the same addons and graphics settings (preset 8, 2560×1600, DX11; DXVK on ArkadeOS), standing at the fountain in Silvermoon. Windows: Armoury Crate Performance, mean of three runs. ArkadeOS: WoW power profile, MangoHud.

**Next:** more real-hardware checks (external monitors, peripherals, desktop PCs, an AMD Radeon machine), then the first stable build, the public beta and the ISO download.

## Known limitations

- **Games with kernel-level anti-cheat do not run on Linux**: Valorant, League of Legends, Fortnite, most recent Call of Duty titles. No Linux distribution can fix this.
- **Secure Boot with NVIDIA:** you confirm the ArkadeOS signing key once during install. The installer walks you through it.
- **DX12 on NVIDIA** is still slower under Proton than on Windows. Where a game offers DX11, ArkadeOS uses whichever mode is faster.
- **x86-64 PCs only.** Steam, Proton and the games are x86 software, so ArkadeOS does not run on Apple Silicon Macs or other ARM machines. x86 emulation in a virtual machine there is far too slow for games.

## Build it yourself

```bash
git clone https://github.com/tenarkhq/ArkadeOS.git
cd ArkadeOS
podman build -t arkadeos -f Containerfile .
```

## Built on

- [Fedora Atomic](https://fedoraproject.org/atomic-desktops/)
- [Bazzite](https://bazzite.gg) and [Universal Blue](https://universal-blue.org)
- [KDE Plasma](https://kde.org/plasma-desktop/)
- [WhiteSur](https://github.com/vinceliuice/WhiteSur-kde) by vinceliuice

## License

ArkadeOS's own code is licensed under the [Apache License 2.0](LICENSE). Every bundled component keeps its own license.
The ArkadeOS name and logo are not covered by the license. Forks must use a different name.

ArkadeOS is not affiliated with Apple, Valve, Blizzard, NVIDIA or AMD.
