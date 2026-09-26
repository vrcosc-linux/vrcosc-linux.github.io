# VRCOSC Linux Installer

An automated installer, updater and launcher manager for running
[VRCOSC](https://github.com/VolcanicArts/VRCOSC) on Linux.

Developed and tested against real Proton on Bazzite. The installer's own logic
is exercised on Ubuntu, Debian, Fedora and Arch in containers, which covers
shell and userland differences but not Proton, wine or WPF rendering. Other
distributions, SteamOS and the Steam Deck should work and are unverified; if
you try one, the Discord thread below is the place to say how it went.

## How it works

VRCOSC is a WPF application designed for Windows. It does not merely need to *run*
under Proton — it needs to reach into VRChat: the game's process, its named pipes,
its OSC/OSCQuery ports and its log files. Steam runs VRChat inside a container with
its own wineserver, and anything started outside that container gets a **separate
wine session** in which VRChat is invisible. So the installer both provisions
VRCOSC and arranges for it to run in the right place.

This installer configures VRCOSC to run seamlessly by:

1. **Auto-detecting your VRChat Proton prefix** across multiple internal, secondary, and external storage drives (`libraryfolders.vdf`), with an interactive prompt fallback.
2. **Applying the WPF registry patch** (`Avalon.Graphics\DisableHWAcceleration`) to turn off WPF hardware acceleration, which is what causes the black window and invisible context menus under wine/Proton.
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
6. **Patching VRChat's `launch.exe` with a Linux IPC Named-Pipe Bridge** (refuse with `--no-patch`):
   - VRChat ships a Windows launcher (`launch.exe`) that fails under Proton when companion tools (like VRCX or external launchers) request in-game world/instance navigation via `\\.\pipe\VRChatURLLaunchPipe`.
   - This replaces a file inside VRChat's own install directory, so `--no-patch` turns it off. Everything else works without it; only `vrchat://` navigation needs it.
   - The installer creates a read-only backup (`launch.org.exe`, `chmod 444`) and places a drop-in C# replacement bridge (`launch.exe`, `chmod 555`). The bridge binary ships in `bin/`; a piped install, which has no script directory, downloads it instead and caches it under `~/.local/share/vrcosc-linux`.
   - Steam restores the stock `launch.exe` on game updates and file validation, so the `vrcosc` launcher re-applies the patch before every session rather than leaving it to decay until the next install.
   - The bridge writes to VRChat's named pipe to open in-game world menus in real
     time, falling back to the original binary if VRChat isn't running. Wine named
     pipes belong to a single wine session, so this only works from inside VRChat's
     own session — which is what step 8 arranges.
   - The installer never backs up a `launch.exe` that is already a bridge. Doing so
     would make the bridge its own fallback, and the fallback path would re-enter it
     without bound every time VRChat was closed. If it finds a bridge with no
     backup beside it, it says so and leaves the file alone; Steam's *Verify
     integrity of game files* restores the stock launcher.

   **The bridge binary.** You are being asked to trust a 4.6 KB executable dropped
   over a game file, so: the source is [`bin/vrc-launch-bridge.cs`](bin/vrc-launch-bridge.cs),
   and it targets .NET Framework 4 — wine-mono, which Proton ships. Its PE header
   says PE32, machine i386, subsystem 3 (console), with the timestamp zeroed as a
   deterministic Roslyn build leaves it, which corresponds to

   ```
   csc /target:exe /platform:x86 /out:bin/vrc-launch-bridge.exe bin/vrc-launch-bridge.cs
   ```

   That command is read off the binary's headers rather than reproduced here, so
   treat it as a description of the shipped build, not a guarantee of a byte-identical
   rebuild.

   `install.sh` pins its sha256 and refuses any download that does not match, so a
   GitHub Pages deployment lagging behind `main` cannot hand you a different
   payload. Verify the copy in this repo with:

   ```bash
   sha256sum bin/vrc-launch-bridge.exe
   # c197a64f8411c11bcfe8a5df1868cf7734851cfd56a494155ba29db31cbb2297
   ```
7. **Setting up official application branding and desktop integration** (`vrcosc.png` hicolor icon, `vrcosc.desktop` launcher, and terminal command `vrcosc`).
8. **Running VRCOSC inside VRChat's own wine session.** The generated launcher finds
   the running game, enters its namespaces (`nsenter -U -m` — unprivileged, since
   they are yours) and starts VRCOSC there with Proton's own environment. Without
   this, `Process.GetProcessesByName("vrchat")` returns nothing, so VRCOSC treats
   the game as permanently closed and every VRChat-dependent feature stays inert.

Switching between `live` and `beta` needs more than swapping the binaries,
because the two share their settings, profiles and packages. The installer sets
the update channel to match `--branch`, turns pre-release packages on for beta
and off again when switching back to live, and on a channel change lists your
installed modules before clearing the now-stale package records. Reinstalling
those modules from the Packages tab is the one manual step left; the reasoning,
the evidence and what is still open are in
[docs/channel-switching.md](docs/channel-switching.md).

Steps 3, 6 and 8 exist because of measured behaviour, not guesswork — the
evidence, including what each communication channel does and does not survive, is
in [docs/prefix-session-findings.md](docs/prefix-session-findings.md).

## Prerequisites

Before running the installer, ensure you have:
* VRChat installed via Steam, and launched at least once under Proton.
* **Protontricks**, which Bazzite and SteamOS ship already.
* `curl` and `unzip`.
* `nsenter`, for VRChat integration. It comes from `util-linux`, which is a
  dependency of systemd, so it is present on every mainstream distribution
  including the gaming ones; it is listed here only because without it VRCOSC
  runs but cannot see VRChat.

The installer checks all of these and, if something is missing, prints the exact
command for your system. For reference:

| System | curl, unzip, nsenter |
| :--- | :--- |
| Debian, Ubuntu, Mint, Pop!_OS | `sudo apt-get install -y util-linux curl unzip` |
| Fedora, Nobara | `sudo dnf install -y util-linux curl unzip` |
| Arch, Manjaro, EndeavourOS | `sudo pacman -S --needed util-linux curl unzip` |
| openSUSE | `sudo zypper install -y util-linux curl unzip` |
| Bazzite, Silverblue, other image-based | `rpm-ostree install util-linux curl unzip` (takes effect after a reboot) |
| SteamOS / Steam Deck | `sudo steamos-readonly disable && sudo pacman -S --needed util-linux curl unzip` (may need repeating after a SteamOS update) |

Protontricks is handled separately, because most distribution repositories either
do not carry it or carry a version too old for current Proton:

```bash
flatpak install -y flathub com.github.Matoking.protontricks
```

```bash
pipx install protontricks
```

## Quick Install (One-Paste)

Copy and paste the following command into your terminal:

```bash
curl -sSL https://vrcosc-linux.github.io/install.sh | bash
```

Through a pipe, options go to `bash` itself unless you separate them with
`-s --`, so `| bash --uninstall` fails with "invalid option". Pass them like
this:

```bash
curl -sSL https://vrcosc-linux.github.io/install.sh | bash -s -- --branch beta
```

## CLI Options & Usage

From a clone:

```bash
bash install.sh [OPTIONS]
```

Through a pipe, flags go to `bash` itself unless you separate them with `-s --`,
so the documented install takes them like this:

```bash
curl -sSL https://vrcosc-linux.github.io/install.sh | bash -s -- [OPTIONS]
```

| Option | Description |
| :--- | :--- |
| `-i, --info` | Diagnostics: OS, tooling, Proton build, prefix, .NET runtime vs what VRCOSC requires, wine environment health, whether a VRChat session is joinable, and installed vs released VRCOSC versions |
| `-b, --backup` | Create a high-compression backup (`.7z` / `.tar.xz`) of VRCOSC settings, profiles, packages and the prefix registries to your Desktop. Symlinked config directories are followed, and the regenerated `runtime/` and `logs/` caches are left out |
| `-f, --force` | Force re-download and reinstall of .NET and VRCOSC binaries, including over a newer local build |
| `--branch <live\|beta>` | Choose release channel, `live` or `beta`, default `live`. Beta is published as a GitHub prerelease and installs into its own directory with a `vrcosc-beta` command, but **shares its settings with live**: VRCOSC uses the same config directory for every release build |
| `-u, --uninstall` | Remove VRCOSC binaries, launcher script and desktop shortcut, restore VRChat's original `launch.exe` if it was patched, and drop the cached bridge payload. Your settings in `AppData/Roaming/VRCOSC` are kept |
| `--purge` | Also delete VRCOSC's settings, profiles and logs for the selected `--branch`, for every user in the prefix. Use with `--uninstall` to remove the binaries too, or on its own to delete only settings; it never installs anything. If the config directory is a symlink, the target is deleted, so check `--purge --dry-run` first |
| `--dry-run` | Simulate actions without modifying files or installing runtimes. Honoured by every mode, including `--uninstall` and `--purge` |
| `--no-firewall` | Inspect the firewall and report what it finds for ports 9000, 9001 and 5353, but add no rules |
| `--no-patch` | Leave VRChat's `launch.exe` alone. The bridge is patched in by default; without it everything works except `vrchat://` navigation from VRCOSC and companion tools |
| `--prefix <PATH>` | Explicitly supply your custom VRChat compatdata/438100 path |
| `--runtime <MODE>` | How wine is invoked: `auto` (default, probes and picks a working mode), `no-bwrap`, `host` (no Steam Runtime), `container` (Steam Runtime with bwrap) |
| `-h, --help` | Show command usage and options |

`--purge` is the only flag that destroys data you cannot get back from a
reinstall. Pair it with `--dry-run` once before running it for real: the dry run
lists every directory it would delete, resolves symlinks so you can see where
they point, and changes nothing.

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

Run `--info` first; most of these are visible there. From a clone that is
`bash install.sh --info`, and through a pipe
`curl -sSL https://vrcosc-linux.github.io/install.sh | bash -s -- --info`.

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

**On beta, the Packages tab offers only stable module versions, and they fail to
import.**
Modules built against a beta SDK are published as pre-releases, and VRCOSC hides
pre-releases unless **Allow Pre-Release Packages** is enabled in Settings. A
stable-built module will not load on beta, so until that setting is on the list
looks normal and nothing works. `--branch beta` turns the setting on for you; if
you enabled beta some other way, turn it on yourself.

**After switching channels, modules are gone from the Packages tab.**
Expected. Their recorded versions belonged to the other channel's SDK line, so
the installer cleared them rather than leave entries whose DLLs cannot load. It
printed the list before doing so — reinstall those from the Packages tab.

**The installer says it will not write settings because VRCOSC is running.**
VRCOSC rewrites its settings file when it exits, so anything written underneath
it would be discarded. Close VRCOSC and run the installer again.

**`vrchat://` links and in-game navigation from VRCOSC do nothing.**
The `launch.exe` bridge is not installed. Rerun the installer without
`--no-patch`; `--info` shows whether the bridge is in place.

**VRChat and VRCOSC seem to interfere with each other.**
Start VRChat first and let it finish loading, then start VRCOSC. `--info` shows
what is currently using the prefix.

## Community & Support

Ran into an issue or need assistance?
* Join the [VRCOSC Discord Server](https://discord.gg/vrcosc-1000862183963496519)
* Check the [Linux Discussion Thread](https://discord.com/channels/1000862183963496519/1466540047149957374)

## Credits & AI Disclaimer

This project is written with agentic AI coding assistants. It was created with
**Antigravity** by **Google DeepMind**, and the later work — the wine session
join, the .NET version detection, the `launch.exe` bridge handling and the test
suites — was done with **Claude Code** by **Anthropic**. The commit history
shows which work came from which.

*Disclaimer: the installation scripts and configuration modifications were
generated and validated programmatically. Claims in this README about measured
behaviour are backed by [docs/prefix-session-findings.md](docs/prefix-session-findings.md);
anything else, treat as untested on your hardware. Use at your own risk.*

## Testing

`install.sh` breaks on environments rather than on logic, so the tests are tiered
by the environment they need. `tests/run-unit.sh` runs offline against fakes in
seconds; `tests/run-container-matrix.sh` runs the whole thing inside throwaway
Ubuntu/Debian/Fedora/Arch containers. See [tests/README.md](tests/README.md) for
what each tier does and does not prove, and for the VM tier that is the only way
to validate real Proton, bwrap and WPF rendering.

`experiments/oscquery-probe.py` holds an OSC/OSCQuery conversation with VRChat from
outside any wine prefix, which is how the OSC channel was verified.
