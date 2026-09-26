# Changelog

## v1.0.2 — 2026-09-26

- The guard that stops the installer writing settings underneath a running
  VRCOSC never fired. It matched on the process name, but the generated launcher
  runs `dotnet.exe .../VRCOSC.dll`, so the process is called `dotnet.exe` — the
  check missed the only way this installer actually starts VRCOSC. It now matches
  on the command line, and `tests/unit/test-vrcosc-running.sh` covers both
  launch shapes, another prefix, VRChat, and unrelated wine processes.

  Found by starting the app after a real reinstall and asking whether the guard
  fired, rather than by the suite, which stubbed the function it was testing.

## v1.0.1 — 2026-09-26

- The package list printed before a channel switch clears `packages.json` named
  `cache` instead of the installed modules. The parser assumed the file was a
  flat `id: version` map; a real one is
  `{"installed": [{"package_id", "version"}], "cache": [...]}`, where `cache` is
  the remote catalogue. Caught by running a real reinstall, not by the tests,
  which used a fixture of the same invented shape — that fixture is now a copy of
  a real file. The grep fallback also runs whenever the parse yields nothing,
  rather than only when `python3` is absent, since it can equally be present and
  broken.

## v1.0.0 — 2026-09-26

First tagged release. The installer existed and worked before this; the version
number exists so a bug report can say which build it is about.

### Release channels

- `--branch beta` used to install the **live** package into the beta directory.
  GitHub's `/releases/latest` never returns a pre-release, and every VRCOSC beta
  is one, so the fallback pattern matched the live `.nupkg`.
- Switching channels now sets everything that has to change with it. Only the
  install directory is per-channel — settings, profiles and package records are
  shared, because `AppManager.APP_NAME` is `"VRCOSC"` for every Release build. So
  the installer writes `settings.UpdateChannel` to match `--branch` (without it a
  beta install claimed the live channel, and Velopack's `AllowVersionDowngrade`
  could replace it with the stable build), turns `AllowPreReleasePackages` on for
  beta and off again when switching back, and on a channel change lists the
  installed packages before clearing records that belong to the other SDK line.
  See [docs/channel-switching.md](docs/channel-switching.md).

### The `launch.exe` bridge

- **It could recurse without bound.** The backup was taken before the
  already-patched check, so a bridge with no backup beside it became its own
  fallback — on every launch with VRChat closed. Both the installer and the
  generated launcher now refuse that, and uninstall will not "restore" a backup
  that is itself a bridge.
- The bridge binary was rebuilt from source, fixing three defects measured
  against a real named pipe under wine: the acknowledgement read blocked forever
  when the game never answered, arguments containing spaces were split apart on
  their way to the stock launcher, and a missing `launch.org.exe` exited 0 as
  though the launch had worked.
- Its sha256 is pinned in `install.sh`, so a cached bridge from an older install
  is refreshed instead of kept forever, and a GitHub Pages deployment lagging
  behind `main` cannot serve a different payload.
- A backup taken before a VRChat update is refreshed rather than left stale.

### Destructive behaviour

- `--uninstall --dry-run` **actually uninstalled**. Every removal is gated now,
  with tests.
- `--backup` archived a symlink instead of the settings it pointed at.
- `--purge --branch beta` looked for a directory that does not exist and reported
  success having matched nothing.

### Safety and correctness

- Installing while VRChat runs silently undid the WPF registry fix: protontricks
  starts a second wineserver, and whichever exits last writes the registry
  wholesale. The fix now skips when it is already applied, and says so rather
  than writing something that will be discarded.
- The `.nupkg` and .NET downloads ran `curl` without `-f`, so a 404 body was
  written to disk and failed later as a corrupt archive or an HTML file handed to
  wine.
- Fixed `/tmp` paths replaced with `mktemp`; the backup staging directory was
  created with `mkdir -p`, which succeeds on someone else's directory, and it
  holds module settings with API tokens.
- protontricks passes its command through `sh -c` unescaped, so
  `wine regedit C:\...` reached wine as a drive-relative path that resolved only
  by luck.
- `--branch` accepted any value and installed live for anything but `beta`.
- The launcher's `exec nsenter` left no shell to fall back in when nsenter
  failed; it probes first.

### Transparency

- The three flatpak overrides granted to protontricks are listed with the reason
  for each, printed at install time, and revoked by `--uninstall`. One of them is
  a sandbox escape and is now labelled as one.
- Firewall rules are documented as being for remote OSC clients and mDNS only —
  same-machine traffic is loopback. `--no-firewall` adds nothing but still
  reports what is open.
- The bridge's source, build and digest are in the README.

### Testing

14 test suites, 270 tests, plus a shellcheck pass and CI that runs all of it and
fails if the pinned bridge digest or its marker string goes missing.
