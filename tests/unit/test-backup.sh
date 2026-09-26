#!/usr/bin/env bash
# --backup exists to be correct immediately before something destructive, so the
# failure that matters is a backup that looks fine and contains nothing.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRY_RUN=0
HOME="$WORK/home"; mkdir -p "$HOME/Desktop"

VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam")"
USERS="$VRC_COMPATDATA/pfx/drive_c/users"

# The config lives outside the prefix and is reached through a symlink, which is
# what cloud-synced setups look like.
REAL_CONFIG="$WORK/cloud/VRCOSC"
mkdir -p "$REAL_CONFIG/configuration" "$REAL_CONFIG/profiles" "$REAL_CONFIG/logs" "$REAL_CONFIG/runtime"
printf '{"setting":"value"}\n' > "$REAL_CONFIG/configuration/settings.json"
printf '{"profile":"default"}\n' > "$REAL_CONFIG/profiles/default.json"
head -c 200000 /dev/zero > "$REAL_CONFIG/logs/big.log"
head -c 200000 /dev/zero > "$REAL_CONFIG/runtime/cache.bin"
mkdir -p "$USERS/steamuser/AppData/Roaming"
ln -sfn "$REAL_CONFIG" "$USERS/steamuser/AppData/Roaming/VRCOSC"

locate_vrchat_prefix() { :; }
out="$(create_backup 2>&1)"
archive="$(ls "$HOME/Desktop"/VRCOSC_backup_* 2>/dev/null | head -1)"

it "produces an archive"
assert_file_exists "$archive"

listing() { if [[ "$archive" == *.7z ]]; then 7z l "$archive" -ba 2>/dev/null; else tar -tf "$archive" 2>/dev/null; fi; }

it "backs up the settings behind the symlink, not the symlink"
assert_contains "$(listing)" "configuration/settings.json"

it "backs up profiles too"
assert_contains "$(listing)" "profiles/default.json"

it "leaves out the regenerated runtime cache"
assert_not_contains "$(listing)" "runtime/cache.bin"

it "leaves out logs"
assert_not_contains "$(listing)" "big.log"

it "says which directories it skipped"
assert_contains "$out" "regenerated cache"

it "includes the prefix registries"
assert_contains "$(listing)" "user.reg"

it "the archive is big enough to actually hold the config"
size=$(stat -c%s "$archive")
assert_eq "yes" "$([ "$size" -gt 200 ] && echo yes || echo no)"

summarise
