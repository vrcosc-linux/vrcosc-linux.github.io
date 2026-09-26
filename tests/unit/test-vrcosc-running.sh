#!/usr/bin/env bash
# The installer must not write settings underneath a running VRCOSC: the app
# rewrites settings.json from memory when it exits, so the write looks applied
# and is gone by the time anyone looks.
#
# The detection matched on the process name until a real install disproved it.
# The generated launcher runs "dotnet.exe .../VRCOSC.dll", so the process is
# called dotnet.exe -- the guard never fired for the one way this installer
# actually starts VRCOSC.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
VRC_COMPATDATA="$WORK/compatdata"
mkdir -p "$VRC_COMPATDATA/pfx"

# A stand-in /proc entry: a process in this prefix with the given command line.
fake_proc() {
    local pid="$1" comm="$2"; shift 2
    local dir="$WORK/proc/$pid"
    mkdir -p "$dir"
    printf 'WINEPREFIX=%s/pfx\0' "$VRC_COMPATDATA" > "$dir/environ"
    printf '%s\0' "$@" > "$dir/cmdline"
    printf '%s\n' "$comm" > "$dir/comm"
}

# Point the scan at the fake tree.
eval "$(declare -f vrcosc_is_running | sed "s|/proc/\[0-9\]\*|$WORK/proc/[0-9]*|")"

it "no processes at all means not running"
vrcosc_is_running
assert_fails "$?"

it "dotnet.exe running VRCOSC.dll is VRCOSC, whatever the process is called"
fake_proc 101 dotnet.exe 'C:\Program Files\dotnet\dotnet.exe' 'C:/users/steamuser/AppData/Local/VRCOSC-beta/VRCOSC.dll'
vrcosc_is_running
assert_ok "$?"

it "a live install is detected too"
rm -rf "$WORK/proc"
fake_proc 102 dotnet.exe 'C:\Program Files\dotnet\dotnet.exe' 'C:/users/steamuser/AppData/Local/VRCOSC/VRCOSC.dll'
vrcosc_is_running
assert_ok "$?"

it "and so is a VRCOSC.exe, for anyone starting it directly"
rm -rf "$WORK/proc"
fake_proc 103 VRCOSC.exe 'C:/users/steamuser/AppData/Local/VRCOSC-beta/VRCOSC.exe'
vrcosc_is_running
assert_ok "$?"

it "an unrelated wine process in the same prefix is not VRCOSC"
rm -rf "$WORK/proc"
fake_proc 104 wineserver '/usr/bin/wineserver'
fake_proc 105 explorer.exe 'C:\windows\explorer.exe'
vrcosc_is_running
assert_fails "$?"

it "and neither is VRChat"
rm -rf "$WORK/proc"
fake_proc 106 VRChat.exe 'Z:/games/VRChat/VRChat.exe'
vrcosc_is_running
assert_fails "$?"

it "a VRCOSC in a different prefix is not ours"
rm -rf "$WORK/proc"
mkdir -p "$WORK/proc/107"
printf 'WINEPREFIX=/some/other/prefix\0' > "$WORK/proc/107/environ"
printf '%s\0' 'dotnet.exe' 'C:/x/VRCOSC.dll' > "$WORK/proc/107/cmdline"
printf 'dotnet.exe\n' > "$WORK/proc/107/comm"
vrcosc_is_running
assert_fails "$?"

summarise
