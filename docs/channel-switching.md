# Switching between live and beta

What `--branch live` ↔ `--branch beta` has to do to be a clean operation, and
what the installer does about it. Written 2026-09-26 after switching a real
install back and forth several times; each item below is something that actually
went wrong, not a precaution. Items 1-3 and 5 are automated as of
`apply_channel_settings`; item 4 is not, and cannot be without a design change.

## Why switching is not just swapping the binaries

Only the install directory is per-channel. Everything else is shared:

| | live | beta |
| :--- | :--- | :--- |
| App files | `AppData/Local/VRCOSC` | `AppData/Local/VRCOSC-beta` |
| Launcher | `vrcosc` | `vrcosc-beta` |
| Settings, profiles, packages | `AppData/Roaming/VRCOSC` | the same directory |

The config directory is shared because `AppManager.APP_NAME` is `"VRCOSC"` for
every Release build and only becomes `"VRCOSC-Dev"` under `#if DEBUG`
(`VRCOSC.App/AppManager.cs`). So a channel switch hands the new app the old
app's settings, profile set, package records and package DLLs — and several of
those are only valid for the channel that wrote them.

## What has to change on a switch

### 1. The update channel, or Velopack rewrites the install

`settings.UpdateChannel` is `0` for live and `1` for beta
(`VRCOSC.App/Updater/UpdateChannel.cs`). `VelopackUpdater` builds its
`UpdateManager` with `ExplicitChannel` from that value **and
`AllowVersionDowngrade = true`**, so an install whose channel setting does not
match what is installed can quietly replace itself with the other channel's
build.

This is not hypothetical: it is the failure documented in the machine's old
hand-written `vrcosc-beta` launcher, where a beta install self-updated to the
stable release and its modules stopped loading.

**Automated.** The installer writes `settings.UpdateChannel` to match `--branch`
on every install. Before that it wrote neither, so a beta install sat there
claiming to be on the live channel.

### 2. Pre-release visibility, both directions

`PackageSource.filterReleases()` hides pre-releases unless
`settings.AllowPreReleasePackages` is true. Module builds for a beta SDK are
published as pre-releases, so beta needs it on.

**Automated, both directions.** Beta sets it true. Live sets it false *only when
the channel actually changed* -- on a plain live install the setting may have
been turned on deliberately, and overriding that on every run is not the
installer's call. Before this, switching back to live left live offering
beta-SDK packages, which cannot load there.

### 3. The installed-package records, which are now wrong

`configuration/packages.json` records a version per package id. After a switch
those versions belong to the other channel's SDK line, and the app will happily
report them as installed while the DLLs on disk refuse to load.

Deleting `configuration/packages.json` while the app is closed forces a clean
rebuild; measured on this machine it went from 14 stale entries to a correct
re-resolved set, and the cache then offered the right builds for the channel.

**Automated.** `packages.json` is deleted when the configured channel differs
from the branch being installed, and only then; re-running the same channel
leaves it alone.

### 4. The module DLLs themselves

A module DLL only loads on the SDK line it was compiled against; the mismatch
surfaces as `failed to import` with a `TypeLoadException` underneath, naming a
type rather than the package. Confirmed both ways:

- official `2026.501.1` and `bluscream 2026.0812.8` import on live `2026.807.0`
  and fail on beta `2026.906.0`
- official `2026.906.1` and `bluscream 2026.0926.0` import on beta `2026.906.0`
  and would fail on live

There is no way to keep one `packages/remote` valid for both channels. Either
re-download per channel, or keep a per-channel copy of `packages/remote` plus
`packages.json` and swap them on switch. The second is the only version of this
that makes switching instant.

**Not automated**, and the one item here that needs a decision rather than code.
Clearing `packages.json` (item 3) makes the app re-resolve correctly, but the
user still has to press install in the Packages tab. Item 5 exists to make that
step obvious rather than to avoid it.

### 5. What the profiles expect

ChatBox clips reference module variables. If the modules those clips came from
are not installed, the app opens with *"ChatBox could not load all data"* and
the log says `ChatBox could not validate all data`. Nothing is broken and
nothing is lost; the clips resolve again once the modules are back.

**Automated.** The package list is read out of `packages.json` and printed
before the file is deleted, so the only record of what was installed survives
the thing that invalidates it.

## Not yet confirmed

- Whether `metadata.InstalledUpdateChannel` needs setting too, or whether the
  updater maintains it on its own (`VelopackUpdater.cs:91` assigns it after an
  update).
- Whether `openxr_loader.dll` has to be placed next to the binary per install
  directory, as the hand-written module deploy script does for its own installs.
  The OpenXR modules load without it, but report no runtime; that may simply be
  a headset not being active.
- Whether the `.NET` requirement can differ between channels. It is read per
  install directory from `VRCOSC.runtimeconfig.json`, so it is handled either
  way, but both channels wanted 10.0 when this was written.

## Switching, now

1. Close VRCOSC. The app rewrites `settings.json` on exit, so anything written
   underneath a running instance is lost.
2. Run the installer with the channel you want. It sets the update channel and
   pre-release visibility, and on a channel change it lists your installed
   packages and then clears the stale records.
3. Start VRCOSC and reinstall the modules it listed, from the Packages tab. The
   versions offered are now the ones that will load.

If you forget step 1 the installer notices: it checks the prefix for a running
VRCOSC and, rather than writing settings that the app would overwrite on exit,
says so and leaves them alone.

## Still open

- Per-channel `packages/remote` copies, so a switch does not need a manual
  reinstall at all (item 4). Everything else is handled.
