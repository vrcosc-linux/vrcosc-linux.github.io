#!/usr/bin/env bash
# The launcher must run VRCOSC inside VRChat's Steam container when the game is
# running: that is the only arrangement in which VRCOSC shares VRChat's wine
# session and can see its process, pipes and windows. Measured on a live system
# (docs/prefix-session-findings.md); reproduced here with stand-ins.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
VRC_PID=""
cleanup() { [ -n "$VRC_PID" ] && kill "$VRC_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$WORK/home" "$WORK/bin"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/bin/protontricks"
ln -sf "$FIXTURES/fake-nsenter" "$WORK/bin/nsenter"
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam" --dotnet 10.0.1 --tfm net10.0)"
HOME="$WORK/home"; DRY_RUN=0; RESOLVED_RUNTIME_MODE=no-bwrap

# A fake Proton wine inside the fixture's Proton build that logs what it ran.
PROTON_DIR="$(get_prefix_proton_dir)"
mkdir -p "$PROTON_DIR/files/bin"
# The launcher runs wine under `env -i` with VRChat's environment, so the log
# path has to be baked in rather than inherited.
cat > "$PROTON_DIR/files/bin/wine" <<W
#!/usr/bin/env bash
{ echo "WINE-ARGS: \$*"; env | grep -E '^(WINEPREFIX|WINEESYNC|MARKER_FROM_VRCHAT|WINEDEBUG)=' | sort; } >> "$WORK/wine.log"
W
chmod +x "$PROTON_DIR/files/bin/wine"

create_launchers >/dev/null 2>&1
LAUNCHER="$(get_launcher_script)"
export FAKE_PT_LOG="$WORK/pt.log" FAKE_NSENTER_LOG="$WORK/ns.log" FAKE_WINE_LOG="$WORK/wine.log"
run_launcher() {
    local -a envs=()
    while [[ "${1:-}" == *=* ]]; do envs+=("$1"); shift; done
    env PATH="$WORK/bin:/usr/bin:/bin" "${envs[@]}" bash "$LAUNCHER" "$@" 2>"$WORK/stderr"
}

it "with VRChat not running, the launcher falls back to protontricks"
: > "$FAKE_PT_LOG"; : > "$FAKE_NSENTER_LOG"
run_launcher >/dev/null || true
assert_contains "$(cat "$FAKE_PT_LOG")" "VRCOSC.dll"
it "and says to start VRChat first for detection"
assert_contains "$(cat "$WORK/stderr")" "start VRChat first"
it "and does not try to enter any namespace"
assert_eq "" "$(cat "$FAKE_NSENTER_LOG")"

# Stand-in for the game: a process named VRChat.exe carrying Proton's markers.
cp /bin/sleep "$WORK/VRChat.exe"
env -i WINEPREFIX="$VRC_COMPATDATA/pfx/" PRESSURE_VESSEL_RUNTIME=steamrt4 WINEESYNC=1 \
    MARKER_FROM_VRCHAT=yes WINELOADERNOEXEC=1 "not-an-identifier=1" PATH=/usr/bin:/bin \
    "$WORK/VRChat.exe" 300 &
VRC_PID=$!
for _ in $(seq 20); do grep -qzF PRESSURE_VESSEL_RUNTIME "/proc/$VRC_PID/environ" 2>/dev/null && break; sleep 0.2; done

it "find_vrchat_container_pid() finds a VRChat.exe running in a Steam container for this prefix"
assert_eq "$VRC_PID" "$(find_vrchat_container_pid)"

it "write_session_env_file() keeps Proton's settings and drops loader state and bad keys"
write_session_env_file "$VRC_PID" "$WORK/env.sh"
assert_contains "$(cat "$WORK/env.sh")" "export WINEESYNC=1"
assert_not_contains "$(cat "$WORK/env.sh")" "WINELOADERNOEXEC"
assert_not_contains "$(cat "$WORK/env.sh")" "not-an-identifier"
bash -n "$WORK/env.sh"; assert_ok $? "and the env file is valid shell"

it "with VRChat running, the launcher enters its namespaces"
: > "$FAKE_PT_LOG"; : > "$FAKE_NSENTER_LOG"; : > "$FAKE_WINE_LOG"
run_launcher --some-arg >/dev/null || true
assert_contains "$(cat "$FAKE_NSENTER_LOG")" "-t $VRC_PID -U -m --preserve-credentials"
it "and runs Proton's wine with dotnet and VRCOSC.dll inside"
assert_contains "$(cat "$FAKE_WINE_LOG")" "WINE-ARGS: C:/Program Files/dotnet/dotnet.exe C:/users/steamuser/AppData/Local/VRCOSC/VRCOSC.dll --some-arg"
it "with VRChat's own environment"
assert_contains "$(cat "$FAKE_WINE_LOG")" "MARKER_FROM_VRCHAT=yes"
it "and does not go through protontricks at all"
assert_eq "" "$(cat "$FAKE_PT_LOG")"
it "and tells the user which session it joined"
assert_contains "$(cat "$WORK/stderr")" "joining VRChat's wine session (pid $VRC_PID)"

it "VRCOSC_JOIN=0 forces the standalone path even with VRChat running"
: > "$FAKE_PT_LOG"; : > "$FAKE_NSENTER_LOG"
run_launcher VRCOSC_JOIN=0 >/dev/null || true
assert_eq "" "$(cat "$FAKE_NSENTER_LOG")"
assert_contains "$(cat "$FAKE_PT_LOG")" "VRCOSC.dll" "and protontricks runs it instead"

it "a VRChat.exe outside any Steam container is not joined"
kill "$VRC_PID"; wait "$VRC_PID" 2>/dev/null
env -i WINEPREFIX="$VRC_COMPATDATA/pfx/" PATH=/usr/bin:/bin "$WORK/VRChat.exe" 300 &
VRC_PID=$!; sleep 0.5
find_vrchat_container_pid >/dev/null; assert_fails $?

summarise
