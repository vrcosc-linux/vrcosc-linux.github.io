#!/usr/bin/env bash
# install_vrcosc() deletes the install directory before unpacking, so installing
# without comparing versions is a downgrade. Observed on the maintainer's machine:
# --info reported a local 2026.812.0.0 against a latest live release of 2026.807.0.
#
# Note the two version shapes: VRCOSC.deps.json records four components
# ("2026.812.0.0") while the release tag has three ("2026.807.0"), so the same
# release must not look like an upgrade or a downgrade to itself.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

it "normalises away trailing zero components"
assert_eq "2026.812" "$(normalise_version 2026.812.0.0)"
it "leaves a meaningful trailing component alone"
assert_eq "2026.418.1" "$(normalise_version 2026.418.1)"

it "sees a four-part local build as newer than an older three-part tag"
assert_eq "newer" "$(compare_versions 2026.812.0.0 2026.807.0)"
it "sees an older local build as older"
assert_eq "older" "$(compare_versions 2026.807.0 2026.812.0)"
it "sees the same release written both ways as the same"
assert_eq "same" "$(compare_versions 2026.812.0.0 2026.812.0)"
it "compares the last component numerically, not lexically"
assert_eq "newer" "$(compare_versions 2026.418.10 2026.418.9)"

it "reads the version a release asset delivers out of its URL"
assert_eq "2026.807.0" "$(get_version_from_asset_url \
    https://github.com/VolcanicArts/VRCOSC/releases/download/2026.807.0/VRCOSC-2026.807.0-live-full.nupkg)"

# install_vrcosc() is exercised with the releases API stubbed and DRY_RUN=1, which
# returns just after the "Downloading" line -- so that line is the signal that it
# decided to install, and its absence that it declined.
RELEASE_TAG=2026.807.0
github_api() {
    cat <<JSON
{ "tag_name": "$RELEASE_TAG",
  "assets": [ { "browser_download_url":
    "https://github.com/VolcanicArts/VRCOSC/releases/download/$RELEASE_TAG/VRCOSC-$RELEASE_TAG-live-full.nupkg" } ] }
JSON
}
DRY_RUN=1
VRCOSC_BRANCH=live
FORCE_INSTALL=0

with_local_version() {
    local name="$1"
    shift
    VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/$name" "$@")"
}

it "declines to overwrite a newer local build"
with_local_version newer --vrcosc-version 2026.812.0.0
out="$(install_vrcosc 2>&1)"
assert_not_contains "$out" "Downloading VRCOSC package"
it "and says why, naming both versions"
assert_contains "$out" "2026.812.0.0 is newer than the latest live release (2026.807.0)"
it "and points at --force"
assert_contains "$out" "--force"

it "skips an install that would change nothing"
with_local_version same --vrcosc-version 2026.807.0
out="$(install_vrcosc 2>&1)"
assert_not_contains "$out" "Downloading VRCOSC package"
it "and says it is already current"
assert_contains "$out" "already the latest live release"

it "treats the same release written with four components as current"
with_local_version samewide --vrcosc-version 2026.807.0.0
out="$(install_vrcosc 2>&1)"
assert_not_contains "$out" "Downloading VRCOSC package"

it "installs when the release is newer than the local build"
with_local_version older --vrcosc-version 2026.708.0
out="$(install_vrcosc 2>&1)"
assert_contains "$out" "Downloading VRCOSC package"

it "installs when nothing is there yet"
with_local_version fresh --no-vrcosc
out="$(install_vrcosc 2>&1)"
assert_contains "$out" "Downloading VRCOSC package"

it "reinstalls when the local version cannot be read"
with_local_version unreadable --vrcosc-version 2026.812.0.0
rm -f "$(get_vrcosc_install_dir)/VRCOSC.deps.json"
out="$(install_vrcosc 2>&1)"
assert_contains "$out" "Downloading VRCOSC package"
it "and says the version was unreadable"
assert_contains "$out" "no readable version"

it "--force overrides the downgrade guard"
with_local_version forced --vrcosc-version 2026.812.0.0
FORCE_INSTALL=1
out="$(install_vrcosc 2>&1)"
assert_contains "$out" "Downloading VRCOSC package"
FORCE_INSTALL=0

summarise
