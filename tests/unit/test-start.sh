#!/usr/bin/env bash
# --start is the one flag that runs the thing it just installed, so it has to
# refuse the cases where starting is wrong: a second instance and a missing
# launcher. The dry-run guard lives in main(), so test-cli.sh covers that one
# through a real run rather than re-implementing the condition here.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/home/.local/bin"
HOME="$WORK/home"
VRCOSC_BRANCH=live
VRC_COMPATDATA="$WORK/compatdata"

# Neither of these may find a real process during the suite.
vrcosc_is_running() { return 1; }
find_vrchat_container_pid() { return 1; }

install_fake_launcher() {
    printf '#!/usr/bin/env bash\necho LAUNCHED "$@"\n' > "$(get_launcher_script)"
    chmod +x "$(get_launcher_script)"
}

await_log() {
    local log="$1" i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$log" ] && return 0
        sleep 0.2
    done
    return 1
}

it "starts the launcher it just installed"
install_fake_launcher
out="$(start_vrcosc 2>&1)"
await_log "$(get_vrcosc_start_log)"
assert_contains "$(cat "$(get_vrcosc_start_log)")" "LAUNCHED"

it "and tells the user where the output went"
assert_contains "$out" "$(get_vrcosc_start_log)"

it "warns that VRChat cannot start alongside a standalone VRCOSC"
assert_contains "$out" "VRChat cannot be started until it exits"

it "refuses to start a second instance"
vrcosc_is_running() { return 0; }
: > "$(get_vrcosc_start_log)"
out="$(start_vrcosc 2>&1)"
assert_contains "$out" "already running"

it "and starts nothing when it refuses"
assert_eq "" "$(cat "$(get_vrcosc_start_log)")"
vrcosc_is_running() { return 1; }

it "fails loudly when the launcher is missing"
rm -f "$(get_launcher_script)"
out="$(start_vrcosc 2>&1)"; rc=$?
assert_fails $rc

it "and names the launcher it could not find"
assert_contains "$out" "$(get_launcher_script)"

it "keeps live and beta output in separate logs"
assert_contains "$(get_vrcosc_start_log beta)" "start-beta.log"

summarise
