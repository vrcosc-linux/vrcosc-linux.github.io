#!/usr/bin/env bash
# --purge deletes settings, which is unrecoverable, so the dry-run guarantee and
# the "only our own directories" rule are the whole point of this suite.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRY_RUN=0
VRCOSC_BRANCH="live"

# A prefix with config for live, beta and a directory we never created, for two
# users -- the shape a real Steam prefix has.
setup() {
    VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/$1")"
    local users="$VRC_COMPATDATA/pfx/drive_c/users"
    local u
    for u in steamuser someone; do
        mkdir -p "$users/$u/AppData/Roaming/VRCOSC/configuration" \
                 "$users/$u/AppData/Roaming/VRCOSC-Beta" \
                 "$users/$u/AppData/Roaming/VRCOSC-Dev"
        printf 'settings\n' > "$users/$u/AppData/Roaming/VRCOSC/configuration/config.json"
        printf 'beta\n'     > "$users/$u/AppData/Roaming/VRCOSC-Beta/config.json"
        printf 'not ours\n' > "$users/$u/AppData/Roaming/VRCOSC-Dev/config.json"
    done
    USERS="$users"
}

it "finds the config directory for every user in the prefix"
setup find1
assert_eq "2" "$(get_vrcosc_config_dirs | wc -l)"

# VRCOSC's APP_NAME is "VRCOSC" for every Release build, so a beta install reads
# and writes the live settings. Looking for VRCOSC-Beta matched nothing and made
# --purge --branch beta claim success while deleting nothing.
it "uses the same directory for beta, because the app does"
assert_eq "$(get_vrcosc_config_dirs)" "$(VRCOSC_BRANCH=beta get_vrcosc_config_dirs)"

it "and does not go looking for a VRCOSC-Beta directory"
assert_not_contains "$(VRCOSC_BRANCH=beta get_vrcosc_config_dirs)" "VRCOSC-Beta"

it "warns that purging beta takes the live settings with it"
setup betawarn
assert_contains "$(VRCOSC_BRANCH=beta DRY_RUN=1 purge_vrcosc_config 2>&1)" "shares its settings with the live install"

it "a dry-run purge deletes nothing"
setup dry1
DRY_RUN=1
out="$(purge_vrcosc_config 2>&1)"
DRY_RUN=0
assert_file_exists "$USERS/steamuser/AppData/Roaming/VRCOSC/configuration/config.json"

it "and says nothing was touched"
assert_contains "$out" "nothing was touched"

it "and still lists what it would delete"
assert_contains "$out" "AppData/Roaming/VRCOSC"

it "a real purge deletes the live config for every user"
setup real1
purge_vrcosc_config >/dev/null 2>&1
gone=""
for u in steamuser someone; do
    [ -e "$USERS/$u/AppData/Roaming/VRCOSC" ] && gone="${gone}present " || gone="${gone}gone "
done
assert_eq "gone gone " "$gone"

it "leaves a hand-made VRCOSC-Beta directory alone"
assert_file_exists "$USERS/steamuser/AppData/Roaming/VRCOSC-Beta/config.json"

it "and never touches a directory it did not create"
assert_file_exists "$USERS/steamuser/AppData/Roaming/VRCOSC-Dev/config.json"

it "follows a symlinked config directory to its target"
setup link1
target="$WORK/elsewhere/VRCOSC"
mkdir -p "$target"; printf 'cloud settings\n' > "$target/config.json"
rm -rf "$USERS/steamuser/AppData/Roaming/VRCOSC"
ln -s "$target" "$USERS/steamuser/AppData/Roaming/VRCOSC"
out="$(purge_vrcosc_config 2>&1)"
assert_eq "1" "$([ -e "$target/config.json" ] && echo 0 || echo 1)"

it "and removes the dangling link as well"
assert_eq "1" "$([ -e "$USERS/steamuser/AppData/Roaming/VRCOSC" ] || [ -L "$USERS/steamuser/AppData/Roaming/VRCOSC" ] && echo 0 || echo 1)"

it "and warns that the symlink target is going too"
assert_contains "$out" "which will be deleted too"

it "says so when there is no config to purge"
setup none1
rm -rf "$USERS"/*/AppData/Roaming/VRCOSC
assert_contains "$(purge_vrcosc_config 2>&1)" "nothing to purge"

it "--purge is documented"
assert_contains "$(print_usage 2>&1)" "--purge"

it "--purge sets purge mode"
( PURGE_MODE=0; parse_arguments --purge; [ "$PURGE_MODE" -eq 1 ] )
assert_ok "$?"

it "and is off by default"
( PURGE_MODE=0; parse_arguments --dry-run; [ "$PURGE_MODE" -eq 0 ] )
assert_ok "$?"

summarise
