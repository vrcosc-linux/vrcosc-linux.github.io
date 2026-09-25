# VRCOSC Linux Installer

An automated installer, updater, and launcher manager for running [VRCOSC](https://github.com/VolcanicArts/VRCOSC) on Linux (tested on Bazzite, SteamOS/Steam Deck, Fedora, and general Linux desktop environments).

## How it works

VRCOSC is a WPF application designed for Windows, requiring hardware graphics acceleration and direct integration with VRChat (using mDNS/OSCQuery protocols and local log parsing). 

This installer configures VRCOSC to run seamlessly by:
1. **Auto-detecting your VRChat Proton prefix** across multiple internal, secondary, and external storage drives (`libraryfolders.vdf`), with an interactive prompt fallback.
2. **Applying the WPF registry patch** to disable Direct3D acceleration, completely eliminating the black window / invisible context menu rendering bug under Wine/Proton.
3. **Silently provisioning .NET 10.0 Desktop Runtime** directly inside VRChat's Proton prefix (skips download if already installed).
4. **Installing VRCOSC binaries** into the prefix's AppData directory. The install
   directory is replaced wholesale, so the installer first compares the installed
   version against the release it would fetch and declines to downgrade or to
   reinstall the same version — useful if you build VRCOSC yourself ahead of the
   published release. `-f/--force` overrides.
5. **Configuring firewall rules** for OSC/OSCQuery ports (9000, 9001, 5353 UDP).
6. **Patching VRChat's `launch.exe` with a Linux IPC Named-Pipe Bridge**:
   - VRChat ships a Windows launcher (`launch.exe`) that fails under Proton when companion tools (like VRCX or external launchers) request in-game world/instance navigation via `\\.\pipe\VRChatURLLaunchPipe`.
   - The installer creates a read-only backup (`launch.org.exe`, `chmod 444`) and places a drop-in C# replacement bridge (`launch.exe`, `chmod 555`).
   - The bridge directly communicates with VRChat's named pipe to open in-game world menus in real-time, falling back cleanly to the original binary if VRChat isn't running.
7. **Setting up official application branding and desktop integration** (`vrcosc.png` hicolor icon, `vrcosc.desktop` launcher, and terminal command `vrcosc`).
8. **Running VRCOSC inside VRChat's own wine session.** Steam runs the game in a
   container with its own wineserver; anything started outside it lands in a
   separate wine session and can never see `VRChat.exe`, its named pipes or its
   windows — VRCOSC then treats the game as permanently closed. The launcher finds
   the running game, enters its namespaces (`nsenter -U -m`, no root needed) and
   starts VRCOSC there with Proton's own environment. Measured, not assumed: see
   [docs/prefix-session-findings.md](docs/prefix-session-findings.md).

## Prerequisites

Before running the installer, ensure you have:
* VRChat installed via Steam, and launched at least once under Proton.
* **Protontricks** installed (available on Bazzite/SteamOS by default, or via Flatpak).
* `curl` and `unzip` installed on the host system.

## Quick Install (One-Paste)

Copy and paste the following command into your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/Bluscream/vrcosc-linux/main/install.sh | bash
```

## CLI Options & Usage

```bash
bash install.sh [OPTIONS]
```

| Option | Description |
| :--- | :--- |
| `-i, --info` | Display diagnostic system, prefix, runtime, VRCOSC, and VRChat IPC bridge details |
| `-b, --backup` | Create a high-compression backup (`.7z` / `.tar.xz`) of VRCOSC configs & prefix registries to Desktop |
| `-f, --force` | Force re-download and reinstall of .NET and VRCOSC binaries, including over a newer local build |
| `--branch <live\|beta>` | Choose release channel (`live` or `beta`, defaults to `live`) |
| `-u, --uninstall` | Cleanly remove VRCOSC binaries, launcher script, and desktop shortcut (preserves user settings) |
| `--dry-run` | Simulate actions without modifying files or installing runtimes |
| `--skip-firewall` | Skip firewall inspection and rule generation |
| `--prefix <PATH>` | Explicitly supply your custom VRChat compatdata/438100 path |
| `-h, --help` | Show command usage and options |

## Running VRCOSC

**Start VRChat first, then VRCOSC.** With the game running, VRCOSC joins its wine
session and sees it (process, log, OSC, `vrchat://` navigation). Started before
the game, VRCOSC runs in a session of its own — it still works, but cannot detect
VRChat; close and relaunch it once the game is up. `VRCOSC_JOIN=0 vrcosc` forces
the standalone session. Joining needs `nsenter` (util-linux), which every
mainstream distro ships.

Once installed, you can launch VRCOSC:
* From your application menu/search bar (search for **VRCOSC**).
* Or by running the command in your terminal:
  ```bash
  vrcosc
  ```

## Community & Support

Ran into an issue or need assistance?
* Join the [VRCOSC Discord Server](https://discord.gg/vrcosc-1000862183963496519)
* Check the [Linux Discussion Thread](https://discord.com/channels/1000862183963496519/1466540047149957374)

## Credits & AI Disclaimer

This project was created and is maintained with the help of **Antigravity**, an agentic AI coding assistant designed by **Google DeepMind**.

*Disclaimer: The installation scripts and configuration modifications were generated and validated programmatically. Use at your own risk.*

## Testing

`install.sh` breaks on environments rather than on logic, so the tests are tiered
by the environment they need. `tests/run-unit.sh` runs offline against fakes in
seconds; `tests/run-container-matrix.sh` runs the whole thing inside throwaway
Ubuntu/Debian/Fedora/Arch containers. See [tests/README.md](tests/README.md) for
what each tier does and does not prove, and for the VM tier that is the only way
to validate real Proton, bwrap and WPF rendering.
