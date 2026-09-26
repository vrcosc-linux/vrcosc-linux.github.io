#!/usr/bin/env bash
# A beta install whose Packages tab shows only stable builds looks like a broken
# install, not a hidden setting, so the installer turns the setting on itself.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRY_RUN=0
VRCOSC_BRANCH="beta"
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam")"
CFG="$VRC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/VRCOSC/configuration"
setting() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['settings']['AllowPreReleasePackages'])" "$CFG/settings.json" 2>/dev/null; }

it "creates a settings file when there is none yet"
mkdir -p "$(dirname "$CFG")"
enable_prerelease_packages >/dev/null 2>&1
assert_file_exists "$CFG/settings.json"

it "and the setting in it is on"
assert_eq "True" "$(setting)"

it "the file it writes carries the version the app expects"
assert_eq "1" "$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$CFG/settings.json")"

it "flips an existing false without discarding other settings"
python3 - "$CFG/settings.json" <<'PY'
import json,sys
json.dump({"settings":{"AllowPreReleasePackages":False,"StartInTray":True},
           "metadata":{"InstalledVersion":"2026.906.0"},"version":1}, open(sys.argv[1],"w"), indent=2)
PY
enable_prerelease_packages >/dev/null 2>&1
assert_eq "True" "$(setting)"

it "and keeps the unrelated setting"
assert_eq "True" "$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['settings']['StartInTray'])" "$CFG/settings.json")"

it "and keeps the metadata"
assert_contains "$(cat "$CFG/settings.json")" "2026.906.0"

it "works without python3, by flipping the boolean in place"
python3 - "$CFG/settings.json" <<'PY'
import json,sys
json.dump({"settings":{"AllowPreReleasePackages":False},"metadata":{},"version":1}, open(sys.argv[1],"w"), indent=2)
PY
mkdir -p "$WORK/nopython"
printf '#!/bin/sh\nexit 127\n' > "$WORK/nopython/python3"; chmod +x "$WORK/nopython/python3"
PATH="$WORK/nopython:$PATH" enable_prerelease_packages >/dev/null 2>&1
assert_contains "$(cat "$CFG/settings.json")" '"AllowPreReleasePackages": true'

it "changes nothing under --dry-run"
python3 - "$CFG/settings.json" <<'PY'
import json,sys
json.dump({"settings":{"AllowPreReleasePackages":False},"metadata":{},"version":1}, open(sys.argv[1],"w"), indent=2)
PY
DRY_RUN=1
out="$(enable_prerelease_packages 2>&1)"
DRY_RUN=0
assert_eq "False" "$(setting)"

it "and says what it would have done"
assert_contains "$out" "Would enable pre-release packages"

summarise
