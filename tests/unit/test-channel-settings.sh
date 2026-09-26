#!/usr/bin/env bash
# Installing the other channel hands the new app the old one's shared settings
# and package records. Getting that wrong is not cosmetic: a beta install left
# on the live channel replaces itself with the stable build, and stale package
# records report modules as installed whose DLLs cannot load.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRY_RUN=0
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam")"
CFG="$VRC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/VRCOSC/configuration"
mkdir -p "$CFG"

get() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['settings'].get(sys.argv[2]))" "$CFG/settings.json" "$1" 2>/dev/null; }
write_settings() { python3 -c "import json,sys;open(sys.argv[1],'w').write(sys.argv[2])" "$CFG/settings.json" "$1"; }

# --- the enum mapping, which everything else is derived from ---

it "live is channel 0"
assert_eq "0" "$(channel_value_for_branch live)"

it "beta is channel 1"
assert_eq "1" "$(channel_value_for_branch beta)"

# --- a first install, where there is nothing to switch from ---

rm -f "$CFG/settings.json"
VRCOSC_BRANCH="beta"
it "writes a settings file when there is none yet"
apply_channel_settings >/dev/null 2>&1
assert_file_exists "$CFG/settings.json"

it "and it names the beta channel"
assert_eq "1" "$(get UpdateChannel)"

it "and it turns pre-release packages on"
assert_eq "True" "$(get AllowPreReleasePackages)"

it "and it carries the version the app expects, or the file is ignored"
assert_eq "1" "$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$CFG/settings.json")"

it "a fresh live install writes channel 0"
rm -f "$CFG/settings.json"
VRCOSC_BRANCH="live"
apply_channel_settings >/dev/null 2>&1
assert_eq "0" "$(get UpdateChannel)"

it "and does not touch pre-release visibility, which is not ours to force"
assert_eq "None" "$(get AllowPreReleasePackages)"

# --- editing an existing file ---

it "sets the channel without discarding other settings"
write_settings '{"settings":{"UpdateChannel":0,"StartInTray":true},"metadata":{"InstalledVersion":"2026.807.0"},"version":1}'
VRCOSC_BRANCH="beta"
apply_channel_settings >/dev/null 2>&1
assert_eq "1" "$(get UpdateChannel)"

it "and keeps the unrelated setting"
assert_eq "True" "$(get StartInTray)"

it "and keeps the metadata"
assert_contains "$(cat "$CFG/settings.json")" "2026.807.0"

it "adds the channel key when the file has no such key yet"
write_settings '{"settings":{"StartInTray":true},"metadata":{},"version":1}'
VRCOSC_BRANCH="beta"
apply_channel_settings >/dev/null 2>&1
assert_eq "1" "$(get UpdateChannel)"

# --- switching back to live, the direction that was never tested ---

it "switching to live turns pre-release packages back off"
write_settings '{"settings":{"UpdateChannel":1,"AllowPreReleasePackages":true},"metadata":{},"version":1}'
VRCOSC_BRANCH="live"
apply_channel_settings >/dev/null 2>&1
assert_eq "False" "$(get AllowPreReleasePackages)"

it "and moves the channel to live"
assert_eq "0" "$(get UpdateChannel)"

it "re-running a live install leaves a deliberate pre-release choice alone"
write_settings '{"settings":{"UpdateChannel":0,"AllowPreReleasePackages":true},"metadata":{},"version":1}'
VRCOSC_BRANCH="live"
apply_channel_settings >/dev/null 2>&1
assert_eq "True" "$(get AllowPreReleasePackages)"

# --- the package cache, which only a switch may clear ---

# The shape VRCOSC actually writes, copied from a real packages.json: a list of
# {package_id, version} under "installed", beside a "cache" holding the whole
# remote catalogue. Getting this wrong is not academic -- the first version of
# this code treated the file as a flat id->version map and printed "cache" at the
# user instead of the two modules they had to reinstall.
seed_packages() {
    cat > "$CFG/packages.json" <<'PKG'
{
  "installed": [
    {"package_id": "volcanicarts.vrcosc.officialmodules", "version": "2026.906.1"},
    {"package_id": "bluscream.vrcosc.modules", "version": "2026.0926.0"}
  ],
  "cache_expire_time": "2026-09-27T03:15:35.4474707+02:00",
  "cache": [
    {"owner": "VolcanicArts", "name": "VRCOSC-Modules", "repository": {"default_branch": "main"}}
  ],
  "version": 1
}
PKG
}

it "a channel switch clears the package cache"
write_settings '{"settings":{"UpdateChannel":0},"metadata":{},"version":1}'
seed_packages
VRCOSC_BRANCH="beta"
out="$(apply_channel_settings 2>&1)"
assert_eq "0" "$([ -f "$CFG/packages.json" ] && echo 1 || echo 0)"

it "and prints what was installed, since that list is the only record"
assert_contains "$out" "volcanicarts.vrcosc.officialmodules 2026.906.1"

it "and prints every installed package, not just the first"
assert_contains "$out" "bluscream.vrcosc.modules 2026.0926.0"

it "and does not offer the remote catalogue as something to reinstall"
assert_not_contains "$out" "* cache"

it "re-running the same channel keeps the package cache"
write_settings '{"settings":{"UpdateChannel":1},"metadata":{},"version":1}'
seed_packages
VRCOSC_BRANCH="beta"
apply_channel_settings >/dev/null 2>&1
assert_file_exists "$CFG/packages.json"

it "a first install keeps it too, having nothing to switch from"
rm -f "$CFG/settings.json"
seed_packages
VRCOSC_BRANCH="beta"
apply_channel_settings >/dev/null 2>&1
assert_file_exists "$CFG/packages.json"

# --- hosts without python3 ---

it "without python3, the channel is still flipped where the key exists"
write_settings '{"settings":{"UpdateChannel":0,"AllowPreReleasePackages":false},"metadata":{},"version":1}'
mkdir -p "$WORK/nopython"
printf '#!/bin/sh\nexit 127\n' > "$WORK/nopython/python3"; chmod +x "$WORK/nopython/python3"
VRCOSC_BRANCH="beta"
PATH="$WORK/nopython:$PATH" apply_channel_settings >/dev/null 2>&1
assert_contains "$(cat "$CFG/settings.json")" '"UpdateChannel": 1'

it "and so is pre-release visibility"
assert_contains "$(cat "$CFG/settings.json")" '"AllowPreReleasePackages": true'

it "without python3, the package ids are still recovered before deletion"
write_settings '{"settings":{"UpdateChannel":0},"metadata":{},"version":1}'
seed_packages
VRCOSC_BRANCH="beta"
out="$(PATH="$WORK/nopython:$PATH" apply_channel_settings 2>&1)"
assert_contains "$out" "bluscream.vrcosc.modules"

it "and a switch detected without python3 still clears the cache"
write_settings '{"settings":{"UpdateChannel":0},"metadata":{},"version":1}'
seed_packages
VRCOSC_BRANCH="beta"
PATH="$WORK/nopython:$PATH" apply_channel_settings >/dev/null 2>&1
assert_eq "0" "$([ -f "$CFG/packages.json" ] && echo 1 || echo 0)"

# --- dry run ---

it "changes no setting under --dry-run"
write_settings '{"settings":{"UpdateChannel":0,"AllowPreReleasePackages":false},"metadata":{},"version":1}'
seed_packages
VRCOSC_BRANCH="beta"
DRY_RUN=1
out="$(apply_channel_settings 2>&1)"
DRY_RUN=0
assert_eq "0" "$(get UpdateChannel)"

it "and deletes no package cache under --dry-run"
assert_file_exists "$CFG/packages.json"

it "and says what it would have done"
assert_contains "$out" "Would set update channel to beta"

it "and says it would clear the cache"
assert_contains "$out" "Would delete"

# --- the app rewrites settings on exit, so writing under it is a silent no-op ---

it "refuses to write while VRCOSC is running"
write_settings '{"settings":{"UpdateChannel":0},"metadata":{},"version":1}'
seed_packages
VRCOSC_BRANCH="beta"
get_prefix_holders() { echo "4242 VRCOSC.exe"; }
out="$(apply_channel_settings 2>&1)"
assert_eq "0" "$(get UpdateChannel)"

it "and leaves the package cache alone, since it did not switch anything"
assert_file_exists "$CFG/packages.json"

it "and says what to do about it"
assert_contains "$out" "Close it and run the installer again"

it "but an unrelated wine process is not VRCOSC"
get_prefix_holders() { echo "4242 wineserver"; }
apply_channel_settings >/dev/null 2>&1
assert_eq "1" "$(get UpdateChannel)"

summarise
