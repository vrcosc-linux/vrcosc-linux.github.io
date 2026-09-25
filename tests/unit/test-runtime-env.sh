#!/usr/bin/env bash
# The regression that broke a tester's install: wine invoked with Steam Runtime
# variables leaked in from the calling shell, producing bogus fontconfig
# "out of memory" errors and an install that completes but never runs.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/lib" --dotnet 9.0.14)"
export PATH="$FIXTURES:$PATH"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/protontricks"
export PATH="$WORK:$PATH"
export FAKE_PT_LOG="$WORK/pt.log"

it "maps each runtime mode onto the right protontricks flags"
assert_eq "--no-bwrap" "$(runtime_mode_flags no-bwrap)"
it "maps host mode to --no-runtime"
assert_eq "--no-runtime" "$(runtime_mode_flags host)"
it "maps container mode to no flags"
assert_eq "" "$(runtime_mode_flags container)"

it "lists leaked Steam Runtime variables"
LD_LIBRARY_PATH=/runtime/lib FONTCONFIG_PATH=/runtime/etc/fonts \
    bash -c 'VRCOSC_INSTALL_SH_SOURCED=1 source "$1"; list_contaminated_env | tr "\n" " "' \
    _ "$INSTALL_SH" > "$WORK/leaked"
assert_contains "$(cat "$WORK/leaked")" "LD_LIBRARY_PATH"
it "lists FONTCONFIG_PATH as leaked too"
assert_contains "$(cat "$WORK/leaked")" "FONTCONFIG_PATH"

it "scrubs leaked variables out of the wine call"
: > "$FAKE_PT_LOG"
RESOLVED_RUNTIME_MODE=no-bwrap \
LD_LIBRARY_PATH=/runtime/lib \
FONTCONFIG_PATH=/runtime/etc/fonts \
WINEPREFIX=/some/other/prefix \
    run_in_prefix "wine --version" >/dev/null 2>&1
assert_not_contains "$(cat "$FAKE_PT_LOG")" "ENV: LD_LIBRARY_PATH"
it "scrubs FONTCONFIG_PATH out of the wine call"
assert_not_contains "$(cat "$FAKE_PT_LOG")" "ENV: FONTCONFIG_PATH"
it "scrubs a hijacking WINEPREFIX out of the wine call"
assert_not_contains "$(cat "$FAKE_PT_LOG")" "ENV: WINEPREFIX"

it "passes the mode's flags through to protontricks"
: > "$FAKE_PT_LOG"
RESOLVED_RUNTIME_MODE=host run_in_prefix "wine --version" >/dev/null 2>&1
assert_contains "$(cat "$FAKE_PT_LOG")" "--no-runtime"

it "detects a broken environment from fontconfig noise"
prefix_output_is_broken 'Fontconfig error: "/etc/fonts/fonts.conf", line 86: out of memory'
assert_ok $?
it "does not call a runtime-not-recognized warning alone a broken environment"
prefix_output_is_broken 'protontricks (WARNING): Current Steam Runtime not recognized by Protontricks.'
assert_fails $?

# NOTE: RESOLVED_RUNTIME_MODE must be cleared on its own line -- bash restores
# variables assigned as a prefix to a function call once the function returns.
it "auto-probe picks the only working mode on a fontconfig-mismatched host"
RESOLVED_RUNTIME_MODE=""
RUNTIME_MODE=auto DRY_RUN=0 FAKE_PT_PROFILE=fontconfig-mismatch \
    probe_runtime_mode >/dev/null 2>&1
assert_eq "host" "$RESOLVED_RUNTIME_MODE"

it "auto-probe prefers no-bwrap when the host is healthy"
RESOLVED_RUNTIME_MODE=""
RUNTIME_MODE=auto DRY_RUN=0 FAKE_PT_PROFILE=clean probe_runtime_mode >/dev/null 2>&1
assert_eq "no-bwrap" "$RESOLVED_RUNTIME_MODE"

it "auto-probe falls past container mode when bwrap nesting fails"
RESOLVED_RUNTIME_MODE=""
RUNTIME_MODE=auto DRY_RUN=0 FAKE_PT_PROFILE=bwrap-broken probe_runtime_mode >/dev/null 2>&1
assert_eq "no-bwrap" "$RESOLVED_RUNTIME_MODE"

it "an explicit --runtime is honoured without probing"
RESOLVED_RUNTIME_MODE=""
: > "$FAKE_PT_LOG"
RUNTIME_MODE=container probe_runtime_mode >/dev/null 2>&1
assert_eq "container|" "$RESOLVED_RUNTIME_MODE|$(cat "$FAKE_PT_LOG")"

summarise
