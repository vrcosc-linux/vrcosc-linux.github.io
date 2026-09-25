#!/usr/bin/env bash
# Users reported VRCOSC dying inside Velopack's updater ("Access denied" out of
# EnumProcessModules) when VRChat was already running in the same prefix. Testing
# on a live system showed the two DO often run together, so this is reported as a
# note rather than enforced -- but it must be reported, and it must match how both
# Proton and protontricks spell WINEPREFIX (Proton adds a trailing slash).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"

WORK="$(mktemp -d)"
HOLDER_PID=""
cleanup() {
    [ -n "$HOLDER_PID" ] && kill "$HOLDER_PID" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$WORK/home" "$WORK/bin"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/bin/protontricks"
PREFIX="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam" --dotnet 10.0.1 --tfm net10.0)"

run_install() {
    local -a envs=()
    while [[ "${1:-}" == *=* ]]; do envs+=("$1"); shift; done
    env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" TERM=dumb \
        FAKE_PT_LOG="$WORK/pt.log" FAKE_PT_PREFIX="$PREFIX" \
        "${envs[@]}" bash "$INSTALL_SH" --prefix "$PREFIX" "$@" 2>&1
}

# Stand in for VRChat's wineserver: any process whose environment claims this
# prefix is, as far as wine is concerned, the session owner.
start_holder() {
    env -i WINEPREFIX="$PREFIX/pfx" PATH=/usr/bin:/bin sleep 300 &
    HOLDER_PID=$!
    # Wait for /proc/<pid>/environ to be readable before asserting on it.
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        grep -qzF "WINEPREFIX=$PREFIX/pfx" "/proc/$HOLDER_PID/environ" 2>/dev/null && return 0
        sleep 0.2
    done
    return 1
}
stop_holder() {
    kill "$HOLDER_PID" 2>/dev/null
    wait "$HOLDER_PID" 2>/dev/null
    HOLDER_PID=""
}

it "reports no holder for an idle prefix"
out="$(run_install --info)"
assert_contains "$out" "Nothing (free)"

start_holder || { echo "could not start a stand-in prefix holder"; exit 1; }

it "--info names the process holding the prefix"
out="$(run_install --info)"
assert_contains "$out" "Prefix In Use By"
it "--info explains what a held prefix means for VRCOSC"
assert_contains "$out" "Access denied"

it "the installer warns about a held prefix but does not refuse"
out="$(run_install --dry-run --skip-firewall)"
assert_contains "$out" "already using this prefix"
it "and names the Velopack symptom to look for"
assert_contains "$out" "Access denied"

it "detects a holder that spells WINEPREFIX with a trailing slash, as Proton does"
# Proton exports WINEPREFIX=<path>/ ; protontricks exports it without the slash.
# Matching only one spelling made the check miss VRChat entirely.
stop_holder
env -i WINEPREFIX="$PREFIX/pfx/" PATH=/usr/bin:/bin sleep 300 &
HOLDER_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
    grep -qzF "WINEPREFIX=$PREFIX/pfx/" "/proc/$HOLDER_PID/environ" 2>/dev/null && break
    sleep 0.2
done
out="$(run_install --dry-run --skip-firewall)"
assert_contains "$out" "already using this prefix"

stop_holder

it "says nothing about a busy prefix once it is free"
out="$(run_install --dry-run --skip-firewall)"
assert_not_contains "$out" "already using this prefix"

# The generated launcher carries the same guard, since that is where users meet
# the problem: a desktop-menu launch with no terminal to read an error from.
it "generates a launcher while the prefix is free"
run_install --skip-firewall >/dev/null 2>&1 || true
LAUNCHER="$WORK/home/.local/bin/vrcosc"
# The install step needs the network; fall back to generating the launcher alone.
if [ ! -f "$LAUNCHER" ]; then
    env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" TERM=dumb \
        VRCOSC_INSTALL_SH_SOURCED=1 bash -c '
            source "$1"
            VRC_COMPATDATA="$2"; HOME="$3"; DRY_RUN=0; RESOLVED_RUNTIME_MODE=host
            create_launchers >/dev/null 2>&1' _ "$INSTALL_SH" "$PREFIX" "$WORK/home"
fi
assert_file_exists "$LAUNCHER"

it "the launcher starts VRCOSC when the prefix is free"
: > "$WORK/pt.log"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    bash "$LAUNCHER" >/dev/null 2>&1
assert_contains "$(cat "$WORK/pt.log")" "VRCOSC.dll"

start_holder || { echo "could not restart the stand-in prefix holder"; exit 1; }

it "the launcher notes a held prefix on stderr"
: > "$WORK/pt.log"
out="$(env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    bash "$LAUNCHER" 2>&1)"
assert_contains "$out" "already using this wine prefix"

it "but still starts VRCOSC, since the two usually coexist"
assert_contains "$(cat "$WORK/pt.log")" "VRCOSC.dll"

it "VRCOSC_QUIET=1 suppresses the note"
out="$(env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    VRCOSC_QUIET=1 bash "$LAUNCHER" 2>&1)"
assert_not_contains "$out" "already using this wine prefix"

summarise
