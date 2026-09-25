# VRCOSC Linux Installer

An automated installer, updater, and launcher manager for running [VRCOSC](https://github.com/VolcanicArts/VRCOSC) on Linux (tested on Bazzite, SteamOS/Steam Deck, Fedora, and general Linux desktop environments).

## How it works

VRCOSC is a WPF application designed for Windows. It does not merely need to *run*
under Proton — it needs to reach into VRChat: the game's process, its named pipes,
its OSC/OSCQuery ports and its log files. Steam runs VRChat inside a container with
its own wineserver, and anything started outside that container gets a **separate
wine session** in which VRChat is invisible. So the installer both provisions
VRCOSC and arranges for it to run in the right place.

This installer configures VRCOSC to run seamlessly by:

1. **Auto-detecting your VRChat Proton prefix** across multiple internal, secondary, and external storage drives (`libraryfolders.vdf`), with an interactive prompt fallback.
2. **Applying the WPF registry patch** to disable Direct3D acceleration, completely eliminating the black window / invisible context menu rendering bug under Wine/Proton.
3. **Provisioning the .NET Desktop Runtime** inside VRChat's Proton prefix — the
   exact version VRCOSC asks for, read from its `VRCOSC.runtimeconfig.json`, then
   verified to be present afterwards. .NET does not roll forward across major
   versions, so a mismatch here shows up as "no runtime installed" even with
   `dotnet.exe` sitting in the prefix.
4. **Installing VRCOSC binaries** into the prefix's AppData directory. The install
   directory is replaced wholesale, so the installer first compares the installed
   version against the release it would fetch and declines to downgrade or to
   reinstall the same version — useful if you build VRCOSC yourself ahead of the
   published release. `-f/--force` overrides.
5. **Configuring firewall rules** for OSC/OSCQuery ports (9000, 9001, 5353 UDP).
6. **Patching VRChat's `launch.exe` with a Linux IPC Named-Pipe Bridge**:
   - VRChat ships a Windows launcher (`launch.exe`) that fails under Proton when companion tools (like VRCX or external launchers) request in-game world/instance navigation via `\\.\pipe\VRChatURLLaunchPipe`.
   - The installer creates a read-only backup (`launch.org.exe`, `chmod 444`) and places a drop-in C# replacement bridge (`launch.exe`, `chmod 555`). The bridge binary ships in `bin/`; a piped install, which has no script directory, downloads it instead and caches it under `~/.local/share/vrcosc-linux`.
   - Steam restores the stock `launch.exe` on game updates and file validation, so the `vrcosc` launcher re-applies the patch before every session rather than leaving it to decay until the next install.
   - The bridge writes to VRChat's named pipe to open in-game world menus in real
     time, falling back to the original binary if VRChat isn't running. Wine named
     pipes belong to a single wine session, so this only works from inside VRChat's
     own session — which is what step 8 arranges.
7. **Setting up official application branding and desktop integration** (`vrcosc.png` hicolor icon, `vrcosc.desktop` launcher, and terminal command `vrcosc`).
8. **Running VRCOSC inside VRChat's own wine session.** The generated launcher finds
   the running game, enters its namespaces (`nsenter -U -m` — unprivileged, since
   they are yours) and starts VRCOSC there with Proton's own environment. Without
   this, `Process.GetProcessesByName("vrchat")` returns nothing, so VRCOSC treats
   the game as permanently closed and every VRChat-dependent feature stays inert.

Steps 3, 6 and 8 exist because of measured behaviour, not guesswork — the
evidence, including what each communication channel does and does not survive, is
in [docs/prefix-session-findings.md](docs/prefix-session-findings.md).

## Prerequisites

Before running the installer, ensure you have:
* VRChat installed via Steam, and launched at least once under Proton.
* **Protontricks** installed (available on Bazzite/SteamOS by default, or via Flatpak/pipx).
* `curl` and `unzip` installed on the host system.
* `nsenter` (from `util-linux`) for VRChat integration. Every mainstream distro
  ships it; without it VRCOSC still runs, but cannot see VRChat.

## Quick Install (One-Paste)

Copy and paste the following command into your terminal:

```bash
curl -sSL https://vrcosc-linux.github.io/install.sh | bash
```

## CLI Options & Usage

```bash
bash install.sh [OPTIONS]
```

| Option | Description |
| :--- | :--- |
| `-i, --info` | Diagnostics: OS, tooling, Proton build, prefix, .NET runtime vs what VRCOSC requires, wine environment health, whether a VRChat session is joinable, and installed vs released VRCOSC versions |
| `-b, --backup` | Create a high-compression backup (`.7z` / `.tar.xz`) of VRCOSC configs & prefix registries to Desktop |
| `-f, --force` | Force re-download and reinstall of .NET and VRCOSC binaries, including over a newer local build |
| `--branch <live\|beta>` | Choose release channel (`live` or `beta`, defaults to `live`) |
| `-u, --uninstall` | Cleanly remove VRCOSC binaries, launcher script, and desktop shortcut (preserves user settings) |
| `--dry-run` | Simulate actions without modifying files or installing runtimes |
| `--skip-firewall` | Skip firewall inspection and rule generation |
| `--prefix <PATH>` | Explicitly supply your custom VRChat compatdata/438100 path |
| `--runtime <MODE>` | How wine is invoked: `auto` (default, probes and picks a working mode), `no-bwrap`, `host` (no Steam Runtime), `container` (Steam Runtime with bwrap) |
| `-h, --help` | Show command usage and options |

**Start with `--info`** if anything misbehaves. It reports the state of everything
the installer depends on, and is safe to run at any time.

### Environment variables

| Variable | Effect |
| :--- | :--- |
| `VRCOSC_JOIN=0` | Launcher only: skip joining VRChat's wine session and always run standalone |
| `GITHUB_TOKEN` / `GH_TOKEN` | Used for release lookups. The unauthenticated GitHub API allows 60 requests/hour per address, which shared or NAT'd connections exhaust; `export GITHUB_TOKEN=$(gh auth token)` avoids it |

## Running VRCOSC

**Start VRChat first, then VRCOSC.** With the game running, VRCOSC joins its wine
session and gets full integration: process detection, the game's log, OSC, and
`vrchat://` navigation. Started before the game, VRCOSC runs in a session of its
own — it works standalone, but cannot detect VRChat, so close and relaunch it once
the game is up. The launcher prints which of the two it did.

Once installed, you can launch VRCOSC:
* From your application menu/search bar (search for **VRCOSC**).
* Or by running the command in your terminal:
  ```bash
  vrcosc
  ```

## Troubleshooting

Run `bash install.sh --info` first; most of these are visible there.

**VRCOSC doesn't see VRChat — no avatar, instance or player data.**
VRCOSC is in its own wine session. Close VRCOSC, make sure VRChat is running, and
start VRCOSC again; it should print `joining VRChat's wine session`. If it doesn't,
check that `nsenter` is installed.

**`System.ComponentModel.Win32Exception (5): Access denied` in Velopack, and VRCOSC
never opens a window.**
VRCOSC connected to VRChat's wineserver from outside the game's user namespace,
which the wineserver cannot read. The launcher avoids this by entering the
namespace properly. If you are launching VRCOSC by hand, use the installed
`vrcosc` launcher instead.

**`Fontconfig error: "/etc/fonts/fonts.conf", line 86: out of memory`.**
Not a memory problem — fontconfig reports config parse failures with that message.
It means wine is loading Steam Runtime libraries while reading host config files,
usually because Steam Runtime variables leaked in from the calling shell. The
installer and launcher scrub those; if it persists, try `--runtime host` or
`--runtime container`.

**`curl: (22) ... error: 403` while fetching releases.**
GitHub rate-limited your address. Wait an hour, or
`export GITHUB_TOKEN=$(gh auth token)`.

**"Installed VRCOSC … is newer than the latest release; not downgrading."**
Working as intended — you have a build ahead of the published release. Use
`--force` if you really want the released version.

**VRChat and VRCOSC seem to interfere with each other.**
Start VRChat first and let it finish loading, then start VRCOSC. `--info` shows
what is currently using the prefix.

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

`experiments/oscquery-probe.py` holds an OSC/OSCQuery conversation with VRChat from
outside any wine prefix, which is how the OSC channel was verified.
