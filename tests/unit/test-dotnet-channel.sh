#!/usr/bin/env bash
# The .NET channel VRCOSC needs must come from its runtimeconfig.json, since
# rollForward does not cross major versions and a mismatch presents to the user
# as "no runtime installed" despite dotnet.exe being right there.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

make_prefix() { "$FIXTURES/make-prefix.sh" --root "$WORK/$1" "${@:2}"; }

it "reads the channel from a net9.0 runtimeconfig"
VRC_COMPATDATA="$(make_prefix net9 --tfm net9.0-windows)"
assert_eq "9.0" "$(get_required_dotnet_channel)"

it "reads the channel from a net10.0 runtimeconfig"
VRC_COMPATDATA="$(make_prefix net10 --tfm net10.0-windows)"
assert_eq "10.0" "$(get_required_dotnet_channel)"

it "falls back to tfm when no WindowsDesktop framework is listed"
VRC_COMPATDATA="$(make_prefix tfmonly --tfm net8.0-windows --no-frameworks)"
assert_eq "8.0" "$(get_required_dotnet_channel)"

it "fails cleanly when runtimeconfig.json is absent"
VRC_COMPATDATA="$(make_prefix novrcosc --no-vrcosc)"
get_required_dotnet_channel >/dev/null 2>&1
assert_fails $?

it "sees a matching installed runtime as satisfying the channel"
VRC_COMPATDATA="$(make_prefix ok --tfm net9.0-windows --dotnet 9.0.14)"
has_desktop_runtime_channel 9.0
assert_ok $?

it "does not accept a different major version as satisfying the channel"
VRC_COMPATDATA="$(make_prefix wrongmajor --tfm net9.0-windows --dotnet 10.0.7)"
has_desktop_runtime_channel 9.0
assert_fails $?

it "reports every installed WindowsDesktop runtime"
VRC_COMPATDATA="$(make_prefix multi --dotnet 8.0.27,9.0.16,10.0.8)"
assert_eq "8.0.27 9.0.16 10.0.8" "$(get_installed_desktop_runtimes |  sort -V |  tr "\n" " " | sed 's/ $//')"

summarise
