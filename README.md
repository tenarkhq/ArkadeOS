# ArkadeOS

**Fast, gaming-first Linux built on Fedora Atomic.**
A macOS-style KDE desktop, NVIDIA and AMD images, Steam and Proton, Battle.net, smart power profiles, and atomic updates you can roll back.

> **Status: early development.** Nothing here is ready for daily use yet. "In testing" means the feature is in the image and checked in a virtual machine; real-hardware checks come with the public beta.

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
| ⚔️ | One-click Battle.net (World of Warcraft first), EA app and Ubisoft Connect, WowUp for addons | in testing |
| 💬 | Discord preinstalled, Vesktop optional for Wayland screen sharing with audio | in testing |
| 🧲 | qBittorrent: free, open-source torrent client without ads (ticked by default, can be left out) | in testing |
| 🎙️ | Microphone noise filter and low-latency audio | in testing |
| ⚡ | Gaming kernel, sched_ext scheduler, NTSYNC | in testing |
| 🔋 | Power profiles: Battery, Balanced, Gaming, Max, WoW, switching automatically, per game | in testing |
| 💻 | Gaming laptops: ASUS (asusctl), MSI (msi-ec, MControlCenter), Lenovo Legion (LenovoLegionLinux); battery care at 80% | in testing |
| 🌈 | RGB that follows the power profile (OpenRGB), Logitech and Razer mice, monitor control | in testing |
| 🍎 | macOS-style KDE Plasma 6 with the WhiteSur theme, light and dark | in testing |
| 🧩 | ArkadeOS Portal: pick apps at first login, add or remove anything later | in testing |
| 🤖 | Optional AI pack: local models (Ollama, Open WebUI) sized to your GPU, AI command-line tools | in testing |
| 🔄 | Atomic image updates with rollback, builds of the last 90 days, factory reset that keeps your files | in testing |
| 🪟 | Installer next to Windows, with Windows in the boot menu | in testing |
| 🔒 | Firewall on, telemetry off, nothing running in the background unless you turn it on | in testing |

## Images

| Image | For |
|---|---|
| `arkadeos` | AMD and Intel graphics |
| `arkadeos-nvidia` | NVIDIA GTX 16xx / RTX 20xx and newer, including hybrid laptops |

Older NVIDIA cards (GTX 10xx and earlier) get the `arkadeos` image with the open nouveau driver: they work, but games run slower than on Windows. [Driver coverage](docs/drivers.md) lists which chips work out of the box.

## Install

**ISO:** coming soon.

**Already on Fedora Atomic, Bazzite or another bootc system?** Switch to ArkadeOS:

```bash
sudo bootc switch ghcr.io/tenarkhq/arkadeos-nvidia:stable
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
| WoW | Automatically while World of Warcraft runs, or manually | Gaming for the CPU, the graphics card held back to 60% of its power (TGP; on ASUS also Dynamic Boost off) so power and cooling go to the CPU (`percent=` in `/etc/arkadeos/gpu-cap.conf`) |

## Known limitations

- **Games with kernel-level anti-cheat do not run on Linux**: Valorant, League of Legends, Fortnite, most recent Call of Duty titles. No Linux distribution can fix this.
- **Secure Boot with NVIDIA:** you confirm the ArkadeOS signing key once during install. The installer walks you through it.
- **DX12 on NVIDIA** is still slower under Proton than on Windows. Where a game offers DX11, ArkadeOS uses whichever mode is faster.

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
