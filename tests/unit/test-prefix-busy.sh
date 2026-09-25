#!/usr/bin/env bash
# A wine prefix can only be owned by one wineserver at a time. Multiple users
# reported that VRChat and VRCOSC would not run at the same time, with VRCOSC
# crashing inside Velopack's updater ("Access denied" out of EnumProcessModules)
# whenever VRChat held the prefix. The installer and the launcher must detect that
# and say so, rather than proceeding into a wine backtrace.
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

it "the installer refuses to run against a held prefix"
out="$(run_install --skip-firewall)"; rc=$?
assert_fails $rc
it "and says to close VRChat"
assert_contains "$out" "Close VRChat"
it "and offers the override"
assert_contains "$out" "VRCOSC_ALLOW_BUSY_PREFIX=1"

it "VRCOSC_ALLOW_BUSY_PREFIX=1 lets the installer proceed past the check"
out="$(run_install VRCOSC_ALLOW_BUSY_PREFIX=1 --dry-run --skip-firewall)"
assert_contains "$out" "continuing anyway"

stop_holder

it "the installer proceeds once the prefix is free"
out="$(run_install --dry-run --skip-firewall)"
assert_not_contains "$out" "already in use"

# The generated launcher carries the same guard, since that is where users meet
# the problem: a desktop-menu launch with no terminal to read an error from.
it "generates a launcher while the prefix is free"
run_install VRCOSC_ALLOW_BUSY_PREFIX=1 --skip-firewall >/dev/null 2>&1 || true
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

it "the launcher refuses to start while the prefix is held"
: > "$WORK/pt.log"
out="$(env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    bash "$LAUNCHER" 2>&1)"; rc=$?
assert_fails $rc
it "the launcher explains why rather than crashing in wine"
assert_contains "$out" "already in use by"
it "the launcher does not invoke wine at all when the prefix is held"
assert_eq "" "$(cat "$WORK/pt.log")"

it "VRCOSC_ALLOW_BUSY_PREFIX=1 overrides the launcher guard too"
: > "$WORK/pt.log"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    VRCOSC_ALLOW_BUSY_PREFIX=1 bash "$LAUNCHER" >/dev/null 2>&1
assert_contains "$(cat "$WORK/pt.log")" "VRCOSC.dll"

summarise
