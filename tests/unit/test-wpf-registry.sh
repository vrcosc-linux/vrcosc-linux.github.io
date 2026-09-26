#!/usr/bin/env bash
# A wineserver holds the prefix registry in memory and writes user.reg wholesale
# when it exits. Writing the WPF patch while VRChat's wineserver is alive reports
# success and leaves nothing behind once VRChat closes, which surfaces much later
# as the black-window bug on a machine the installer said it had fixed.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRY_RUN=0
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam")"
USER_REG="$VRC_COMPATDATA/pfx/user.reg"

# Stand in for protontricks, so nothing here starts wine.
run_in_prefix() { echo "run_in_prefix: $*" >> "$WORK/calls"; }
vrchat_running=1
find_vrchat_container_pid() { [ "$vrchat_running" -eq 0 ] && { echo 4242; return 0; }; return 1; }

patched_reg() {
    printf '[Software\\\\Microsoft\\\\Avalon.Graphics]\n"DisableHWAcceleration"=dword:00000001\n' > "$USER_REG"
}

it "an unpatched prefix is reported as unpatched"
printf 'WINE REGISTRY Version 2\n' > "$USER_REG"
wpf_registry_fix_applied
assert_fails "$?"

it "a patched prefix is recognised"
patched_reg
wpf_registry_fix_applied
assert_ok "$?"

it "a prefix with the key but acceleration left on is not patched"
printf '[Software\\\\Microsoft\\\\Avalon.Graphics]\n"DisableHWAcceleration"=dword:00000000\n' > "$USER_REG"
wpf_registry_fix_applied
assert_fails "$?"

it "writes the patch when it is missing and nothing holds the prefix"
printf 'WINE REGISTRY Version 2\n' > "$USER_REG"
rm -f "$WORK/calls"
apply_wpf_registry_fix >/dev/null 2>&1
assert_contains "$(cat "$WORK/calls" 2>/dev/null || true)" "regedit"

it "and reaches wine with an absolute path, not a drive-relative one"
# protontricks runs the command through sh -c unescaped, so a backslash would be
# eaten and "C:\vrcosc..." would arrive as "C:vrcosc...".
assert_contains "$(cat "$WORK/calls")" "C:/vrcosc_disable_hw_acc.reg"

it "does not rewrite a patch that is already there"
patched_reg
rm -f "$WORK/calls"
out="$(apply_wpf_registry_fix 2>&1)"
assert_eq "1" "$([ -e "$WORK/calls" ] && echo 0 || echo 1)"

it "and says so"
assert_contains "$out" "already present"

it "refuses to write while VRChat holds the prefix"
printf 'WINE REGISTRY Version 2\n' > "$USER_REG"
rm -f "$WORK/calls"
vrchat_running=0
out="$(apply_wpf_registry_fix 2>&1)"
assert_eq "1" "$([ -e "$WORK/calls" ] && echo 0 || echo 1)"

it "and explains that the write would be discarded"
assert_contains "$out" "discard ours"

it "and says what to do about it"
assert_contains "$out" "Close VRChat and run the installer again"

it "but does not abort the rest of the install over it"
assert_ok "$?"

it "and an already-patched prefix is fine even with VRChat running"
patched_reg
rm -f "$WORK/calls"
out="$(apply_wpf_registry_fix 2>&1)"
assert_contains "$out" "already present"

summarise
