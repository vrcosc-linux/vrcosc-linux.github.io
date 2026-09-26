# Switching between live and beta

Notes for making `--branch live` ↔ `--branch beta` a clean operation. Written
2026-09-26 after switching a real install back and forth several times; each
item below is something that actually went wrong, not a precaution.

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

**Automate:** set `settings.UpdateChannel` to match `--branch` on every install.
Right now the installer sets neither, so a beta install sits there claiming to
be on the live channel.

### 2. Pre-release visibility, both directions

`PackageSource.filterReleases()` hides pre-releases unless
`settings.AllowPreReleasePackages` is true. Module builds for a beta SDK are
published as pre-releases, so beta needs it on.

The installer turns it on for `--branch beta` (done). **It never turns it off
again**, so switching back to live leaves live offering beta-SDK packages, which
cannot load there. Switching to live should set it false.

### 3. The installed-package records, which are now wrong

`configuration/packages.json` records a version per package id. After a switch
those versions belong to the other channel's SDK line, and the app will happily
report them as installed while the DLLs on disk refuse to load.

Deleting `configuration/packages.json` while the app is closed forces a clean
rebuild; measured on this machine it went from 14 stale entries to a correct
re-resolved set, and the cache then offered the right builds for the channel.

**Automate:** invalidate it on a channel change, not on every install.

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

### 5. What the profiles expect

ChatBox clips reference module variables. If the modules those clips came from
are not installed, the app opens with *"ChatBox could not load all data"* and
the log says `ChatBox could not validate all data`. Nothing is broken and
nothing is lost; the clips resolve again once the modules are back.

**Automate:** after a switch, print the package list read out of the previous
`packages.json` so the user knows exactly what to reinstall.

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

## Until it is automated

1. Close VRCOSC.
2. Run the installer with the channel you want.
3. Set **Update Channel** in VRCOSC's settings to match that channel.
4. Set **Allow Pre-Release Packages** on for beta, off for live.
5. Delete `configuration/packages.json`.
6. Start VRCOSC and reinstall your modules from the Packages tab; with the
   setting from step 4, the versions offered are the ones that will load.
