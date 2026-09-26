#!/usr/bin/env bash
# A missing dependency is the first thing a new user hits, and "dependency X is
# missing" without a command to run is where they stop. These cover the mapping
# from a missing command to the right instruction for the system in front of them.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
OS_RELEASE_FILE="$WORK/os-release"
printf 'ID=fedora\n' > "$OS_RELEASE_FILE"

# Only the package managers named here exist for a given case. PATH is the stub
# directory and nothing else, because this host really does have rpm-ostree in
# /usr/bin and would win every detection otherwise; the handful of real tools the
# code needs are linked in explicitly.
only() {
    rm -f "$WORK/bin"/*
    local t m
    for t in grep sed; do ln -sf "$(command -v "$t")" "$WORK/bin/$t"; done
    for m in "$@"; do printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/$m"; chmod +x "$WORK/bin/$m"; done
}
detect_with() { PATH="$WORK/bin" detect_package_manager; }

it "detects apt"
only apt-get; assert_eq "apt" "$(detect_with)"

it "detects dnf"
only dnf; assert_eq "dnf" "$(detect_with)"

it "detects pacman"
only pacman; assert_eq "pacman" "$(detect_with)"

it "detects zypper"
only zypper; assert_eq "zypper" "$(detect_with)"

it "detects apk"
only apk; assert_eq "apk" "$(detect_with)"

it "detects xbps"
only xbps-install; assert_eq "xbps" "$(detect_with)"

it "prefers rpm-ostree over dnf on an image-based system"
only rpm-ostree dnf; assert_eq "rpm-ostree" "$(detect_with)"

it "recognises SteamOS ahead of its package manager"
printf 'ID=steamos\nNAME="SteamOS"\n' > "$OS_RELEASE_FILE"
only pacman; assert_eq "steamos" "$(detect_with)"
printf 'ID=fedora\n' > "$OS_RELEASE_FILE"

it "says unknown when it recognises nothing"
only; assert_eq "unknown" "$(detect_with)"

it "maps nsenter to the package that actually provides it"
assert_eq "util-linux" "$(package_for nsenter)"

it "leaves a command that matches its package alone"
assert_eq "unzip" "$(package_for unzip)"

hint_with() { only "$1"; shift; PATH="$WORK/bin" print_install_hint "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }

it "gives an apt command for a Debian-like system"
assert_contains "$(hint_with apt-get nsenter unzip)" "sudo apt-get install -y util-linux unzip"

it "gives a pacman command for an Arch-like system"
assert_contains "$(hint_with pacman nsenter)" "sudo pacman -S --needed util-linux"

it "tells an image-based system that a reboot is involved"
assert_contains "$(hint_with rpm-ostree nsenter)" "reboot"

it "and uses rpm-ostree rather than dnf there"
assert_contains "$(hint_with rpm-ostree nsenter)" "rpm-ostree install util-linux"

it "warns that SteamOS resets its root filesystem"
printf 'ID=steamos\n' > "$OS_RELEASE_FILE"
out="$(hint_with pacman nsenter)"
printf 'ID=fedora\n' > "$OS_RELEASE_FILE"
assert_contains "$out" "steamos-readonly disable"

it "does not pretend a distro package exists for protontricks"
out="$(hint_with apt-get protontricks)"
assert_not_contains "$out" "apt-get install"

it "points at flatpak and pipx for protontricks instead"
assert_contains "$out" "flatpak install"

it "and at pipx as the alternative"
assert_contains "$out" "pipx install protontricks"

it "handles a mix of protontricks and distro packages"
out="$(hint_with dnf protontricks unzip)"
assert_contains "$out" "sudo dnf install -y unzip"

it "and still covers protontricks in the same breath"
assert_contains "$out" "flatpak install"

it "falls back to naming the packages when the system is unrecognised"
assert_contains "$(hint_with nothing-here nsenter)" "util-linux"

summarise
