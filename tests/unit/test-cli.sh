#!/usr/bin/env bash
# Black-box tests: run install.sh as a user would, against a synthetic prefix
# and a fake protontricks, with $HOME redirected so nothing touches the real one.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/home" "$WORK/bin"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/bin/protontricks"

PREFIX="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam" --dotnet 9.0.14 --tfm net9.0-windows)"

# Runs install.sh in a sealed environment. Extra env goes in via `VAR=value`
# arguments before the flags.
run_install() {
    local -a envs=()
    while [[ "${1:-}" == *=* ]]; do
        envs+=("$1")
        shift
    done
    env -i \
        HOME="$WORK/home" \
        PATH="$WORK/bin:/usr/bin:/bin" \
        TERM=dumb \
        FAKE_PT_LOG="$WORK/pt.log" \
        FAKE_PT_PREFIX="$PREFIX" \
        "${envs[@]}" \
        bash "$INSTALL_SH" --prefix "$PREFIX" "$@" 2>&1
}

it "--help exits successfully and documents --runtime"
out="$(run_install --help)"; rc=$?
assert_contains "$out$rc" "--runtime <MODE>"

it "--help documents how to refuse the launch.exe patch"
assert_contains "$out" "--no-patch"

it "--help documents the firewall flag under its current name"
assert_contains "$out" "--no-firewall"

it "rejects an unknown --runtime value"
out="$(run_install --runtime nonsense)"; rc=$?
assert_fails $rc
it "explains which --runtime values are valid"
assert_contains "$out" "auto, no-bwrap, host, container"

it "--info runs to completion when protontricks --version fails"
# Regression: the ERR trap plus pipefail used to abort the report right after
# the tooling header, which is exactly what a tester's log showed.
out="$(run_install FAKE_PT_PROFILE=version-fails --info)"
assert_contains "$out" "=== Community & Support ==="

it "--info still reports the prefix when protontricks --version fails"
assert_contains "$out" "=== VRChat Proton Prefix ==="

it "--info names the Proton build from config_info"
out="$(run_install --info)"
assert_contains "$out" "proton-rtsp-11.0-20260609-4"

it "--info flags the .NET runtime the app needs as satisfied"
assert_contains "$out" "9.0.x (satisfied)"

it "--info flags leaked Steam Runtime variables"
out="$(run_install LD_LIBRARY_PATH=/runtime/lib --info)"
assert_contains "$out" "LD_LIBRARY_PATH"

it "--info marks a fontconfig-broken runtime mode as broken"
out="$(run_install FAKE_PT_PROFILE=fontconfig-mismatch --info)"
assert_contains "$out" "out of memory"

it "--info reports host mode as the working one on such a host"
assert_contains "$out" "Runtime [host     ]"

it "--dry-run writes no launcher"
run_install --dry-run --no-firewall >/dev/null
launcher_exists=0
[ -e "$WORK/home/.local/bin/vrcosc" ] && launcher_exists=1
assert_eq "0" "$launcher_exists"

it "--info warns when the app needs a runtime the prefix lacks"
WRONG="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam-wrong" --dotnet 10.0.7 --tfm net9.0-windows)"
out="$(PREFIX="$WRONG"; run_install --info)"
assert_contains "$out" "9.0.x (MISSING"

it "--dry-run survives with no network at all"
# Regression: install_vrcosc() curled GitHub before honouring DRY_RUN, so an
# offline --dry-run died with a bare curl exit code through the ERR trap.
out="$(env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" TERM=dumb \
    FAKE_PT_LOG="$WORK/pt.log" http_proxy=http://127.0.0.1:9 \
    https_proxy=http://127.0.0.1:9 \
    bash "$INSTALL_SH" --prefix "$PREFIX" --dry-run --no-firewall 2>&1)"
rc=$?
assert_ok $rc

it "--dry-run says why it skipped the download when offline"
assert_contains "$out" "Dry run: could not reach"

# --- --no-firewall still reports ----------------------------------------------
# Refusing to change the firewall is not the same as refusing to look at it: a
# blocked 9001 looks exactly like VRCOSC not working.
it "--no-firewall still inspects the firewall"
out="$(run_install --dry-run --no-firewall)"
assert_contains "$out" "Checking firewall configuration"

it "and says it is adding nothing"
assert_contains "$out" "Not adding any firewall rules"

it "and names the ports either way"
# On a host with no firewall tool at all it must still say which ports it could
# not check -- a reader of this output is trying to find out if 9001 is blocked.
assert_contains "$out" "9001/udp"

summarise
