# ArkadeOS

**Fast, gaming-first Linux built on Fedora Atomic.**
A macOS-style KDE desktop, NVIDIA and AMD images, Steam and Proton, Battle.net, smart power profiles, and atomic updates you can roll back.

> **Status: early development.** Nothing here is ready for daily use yet. Features below are the plan; each one is ticked off as it lands.

---

## Why ArkadeOS

- **Built for games only.** No background indexing, no services you don't need. The kernel, scheduler and power settings are tuned for low latency and high frame rates.
- **Looks and feels like macOS.** Top bar with a global menu, a centered dock, Spotlight-style search, gestures. From Windows it keeps only what helps: window snapping, Alt+Tab previews, clipboard history.
- **Can't be broken by an update.** The whole system is one image. A bad update? Reboot and pick the previous one.
- **Works for everyone.** Separate images for NVIDIA and AMD/Intel graphics. The installer picks the right one for your machine.

## Features

| | Feature | Status |
|---|---|---|
| 🎮 | Steam, Proton-GE, Proton Experimental, Gamescope, MangoHud, GameMode | planned |
| 🕹️ | Game Mode session: boot straight into full-screen Steam, or switch from the desktop | planned |
| ⚔️ | One-click Battle.net (World of Warcraft first) with a pinned, tested Proton | planned |
| 💬 | Discord preinstalled, Vesktop optional for Wayland screen sharing with audio | planned |
| ⚡ | Gaming kernel, sched_ext scheduler, NTSYNC | planned |
| 🔋 | Power profiles: Battery, Balanced, Gaming, Max, switching automatically | planned |
| 💻 | ASUS laptop support: fan modes, charge limit, MUX switch (asusctl, supergfxctl) | planned |
| 🍎 | macOS-style KDE Plasma 6 with the WhiteSur theme, light and dark | planned |
| 🤖 | Optional AI pack at first boot: local models (Ollama), AI command-line tools | planned |
| 🔄 | Atomic image updates with rollback | planned |

## Images

| Image | For |
|---|---|
| `arkadeos` | AMD and Intel graphics |
| `arkadeos-nvidia` | NVIDIA GTX 16xx / RTX 20xx and newer, including hybrid laptops |

Older NVIDIA cards (GTX 10xx and earlier) are not supported.

## Install

**ISO:** coming soon.

**Already on Fedora Atomic, Bazzite or another bootc system?** Switch to ArkadeOS:

```bash
sudo bootc switch ghcr.io/<owner>/arkadeos-nvidia:stable
```

Use `arkadeos` instead of `arkadeos-nvidia` for AMD or Intel graphics. Reboot to finish.

**Roll back to the previous version:**

```bash
sudo bootc rollback
```

## Power profiles

| Profile | When | What it does |
|---|---|---|
| Battery | Automatically on battery | Power-saving CPU mode, no boost, deep sleep states, discrete GPU off |
| Balanced | Automatically on AC | Balanced CPU mode with boost |
| Gaming | Automatically while a game runs | Performance CPU mode, low-latency scheduler, GPU boost |
| Max | Manually, on AC only | Deep sleep states off, fans and platform profile at maximum |

## Known limitations

- **Games with kernel-level anti-cheat do not run on Linux**: Valorant, League of Legends, Fortnite, most recent Call of Duty titles. No Linux distribution can fix this.
- **Secure Boot with NVIDIA:** you confirm the ArkadeOS signing key once during install. The installer walks you through it.
- **DX12 on NVIDIA** is still slower under Proton than on Windows. Where a game offers DX11, ArkadeOS uses whichever mode is faster.

## Build it yourself

```bash
git clone https://github.com/<owner>/arkadeos.git
cd arkadeos
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
