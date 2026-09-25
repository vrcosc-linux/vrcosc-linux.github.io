#!/usr/bin/env bash
# The launcher is what users actually run day to day, and it is regenerated on
# every install -- so it must be valid shell and must scrub the environment
# itself, independent of whatever shell the desktop entry is launched from.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/home" "$WORK/bin"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/bin/protontricks"
HOME="$WORK/home"
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam" --dotnet 9.0.14)"
DRY_RUN=0

generate_for() {
    RESOLVED_RUNTIME_MODE="$1"
    VRCOSC_BRANCH="${2:-live}"
    rm -f "$(get_launcher_script)"
    create_launchers >/dev/null 2>&1
    get_launcher_script
}

for mode in no-bwrap host container; do
    launcher="$(generate_for "$mode")"

    it "generates a launcher for $mode mode"
    assert_file_exists "$launcher"

    it "the $mode launcher is syntactically valid"
    bash -n "$launcher" 2>"$WORK/err"
    assert_eq "" "$(cat "$WORK/err")"

    it "the $mode launcher scrubs leaked runtime variables at run time"
    : > "$WORK/pt.log"
    env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
        LD_LIBRARY_PATH=/runtime/lib FONTCONFIG_PATH=/runtime/etc/fonts \
        bash "$launcher" >/dev/null 2>&1
    assert_not_contains "$(cat "$WORK/pt.log")" "ENV: "
done

it "bakes the resolved runtime flags into the launcher"
launcher="$(generate_for host)"
assert_contains "$(cat "$launcher")" "--no-runtime"

it "uses no runtime flags for container mode"
launcher="$(generate_for container)"
assert_not_contains "$(cat "$launcher")" "--no-runtime"

it "points the live launcher at the live install directory"
launcher="$(generate_for no-bwrap live)"
assert_contains "$(cat "$launcher")" "AppData/Local/VRCOSC/VRCOSC.dll"

it "points the beta launcher at the beta install directory"
launcher="$(generate_for no-bwrap beta)"
assert_contains "$(cat "$launcher")" "AppData/Local/VRCOSC-beta/VRCOSC.dll"

it "forwards its own arguments through to VRCOSC"
: > "$WORK/pt.log"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    bash "$(generate_for no-bwrap live)" --some-vrcosc-flag >/dev/null 2>&1
assert_contains "$(cat "$WORK/pt.log")" "--some-vrcosc-flag"

summarise
