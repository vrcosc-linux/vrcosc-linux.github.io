#!/usr/bin/env bash
# The bridge payload has to be reachable in the way the README tells people to
# install: `curl ... | bash`. There is no script file then, so a path derived
# from BASH_SOURCE points at the caller's cwd and the patch is silently skipped.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
HOME="$WORK/home"
LAUNCH_BRIDGE_CACHE="$HOME/.local/share/vrcosc-linux/vrc-launch-bridge.exe"
DRY_RUN=0
PATCH_LAUNCH=1   # the opt-in default is covered by its own tests at the end

# A fake curl, so nothing here touches the network.
make_curl() {
    cat > "$WORK/bin/curl" <<CURL
#!/usr/bin/env bash
out=""
while [ \$# -gt 0 ]; do
    [ "\$1" = "-o" ] && { out="\$2"; shift 2; continue; }
    shift
done
printf '%s' '$1' > "\$out"
exit ${2:-0}
CURL
    chmod +x "$WORK/bin/curl"
}

it "prefers the bridge sitting beside the script"
assert_eq "$REPO_ROOT/bin/vrc-launch-bridge.exe" "$(resolve_launch_bridge)"

it "the shipped bridge is a real PE binary"
assert_eq "MZ" "$(head -c 2 "$REPO_ROOT/bin/vrc-launch-bridge.exe")"

# From here on, pretend there is no script file at all -- the piped-install case.
get_script_dir() { return 0; }

it "tries the Pages URL before raw GitHub"
assert_contains "${LAUNCH_BRIDGE_URLS[0]}" "vrcosc-linux.github.io/bin/"

it "has a second source to fall back to"
assert_eq "2" "${#LAUNCH_BRIDGE_URLS[@]}"

it "downloads the bridge when there is no script directory"
make_curl 'MZfake-bridge-payload'
bridge="$(PATH="$WORK/bin:$PATH" resolve_launch_bridge)"
assert_eq "$LAUNCH_BRIDGE_CACHE" "$bridge"

it "caches the download for the next run"
assert_file_exists "$LAUNCH_BRIDGE_CACHE"

it "reuses the cache without calling curl again"
rm -f "$WORK/bin/curl"
assert_eq "$LAUNCH_BRIDGE_CACHE" "$(resolve_launch_bridge)"

it "falls back to the second source when the first one fails"
rm -rf "$HOME"
cat > "$WORK/bin/curl" <<'CURL'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        http*) url="$1"; shift ;;
        *) shift ;;
    esac
done
case "$url" in
    https://vrcosc-linux.github.io/*) exit 22 ;;
    *) printf 'MZfrom-raw-github' > "$out" ;;
esac
CURL
chmod +x "$WORK/bin/curl"
bridge="$(PATH="$WORK/bin:$PATH" resolve_launch_bridge)"
assert_eq "MZfrom-raw-github" "$(cat "$bridge" 2>/dev/null)"

it "refuses a download that is not a PE binary"
rm -rf "$HOME"
make_curl '<html>rate limited</html>'
PATH="$WORK/bin:$PATH" resolve_launch_bridge >/dev/null 2>&1
assert_fails "$?"

it "leaves no cache behind after refusing a bad download"
assert_eq "" "$(ls "$(dirname "$LAUNCH_BRIDGE_CACHE")" 2>/dev/null)"

it "reports failure when curl itself fails"
make_curl 'MZwhatever' 22
PATH="$WORK/bin:$PATH" resolve_launch_bridge >/dev/null 2>&1
assert_fails "$?"

it "never downloads under --no-download"
make_curl 'MZfake-bridge-payload'
PATH="$WORK/bin:$PATH" resolve_launch_bridge --no-download >/dev/null 2>&1
assert_fails "$?"

it "never downloads during a dry run"
DRY_RUN=1
PATH="$WORK/bin:$PATH" resolve_launch_bridge >/dev/null 2>&1
assert_fails "$?"
DRY_RUN=0

it "patches a stock launch.exe from the resolved bridge"
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam")"
game_dir="$(get_vrchat_game_dir)"
PATH="$WORK/bin:$PATH" patch_vrchat_launch_bridge >/dev/null 2>&1
assert_eq "MZfake-bridge-payload" "$(cat "$game_dir/launch.exe")"

it "keeps a read-only backup of the original launcher"
assert_eq "MZ stub launch.exe" "$(cat "$game_dir/launch.org.exe")"

it "is idempotent on a second patch"
PATH="$WORK/bin:$PATH" patch_vrchat_launch_bridge >/dev/null 2>&1
assert_eq "MZ stub launch.exe" "$(cat "$game_dir/launch.org.exe")"

# --- the generated launcher re-applies the patch ------------------------------
# Steam restores the stock launch.exe on update or validation, so a one-shot
# patch at install time decays; the launcher runs before every session.
mkdir -p "$WORK/bin"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/bin/protontricks"
RESOLVED_RUNTIME_MODE="no-bwrap"
VRCOSC_BRANCH="live"
make_curl 'MZfake-bridge-payload'
PATH="$WORK/bin:$PATH" create_launchers >/dev/null 2>&1
launcher="$(get_launcher_script)"

it "generates a launcher that knows where the bridge payload is"
assert_contains "$(cat "$launcher")" "BRIDGE_PAYLOAD=\"$(get_launch_bridge_cache)\""

it "the launcher is still syntactically valid"
bash -n "$launcher" 2>"$WORK/err"
assert_eq "" "$(cat "$WORK/err")"

it "the launcher restores the bridge after Steam replaces launch.exe"
chmod 755 "$game_dir/launch.exe"
printf 'MZ stock launcher restored by Steam\n' > "$game_dir/launch.exe"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" VRCOSC_JOIN=0 \
    bash "$launcher" >/dev/null 2>"$WORK/launch.err"
assert_eq "MZfake-bridge-payload" "$(cat "$game_dir/launch.exe")"

it "and says so"
assert_contains "$(cat "$WORK/launch.err")" "re-applied VRChat's launch.exe bridge"

it "does not touch an already-bridged launch.exe"
: > "$WORK/launch.err"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" VRCOSC_JOIN=0 \
    bash "$launcher" >/dev/null 2>"$WORK/launch.err"
assert_not_contains "$(cat "$WORK/launch.err")" "re-applied"

it "keeps the original backup across a re-patch"
assert_eq "MZ stub launch.exe" "$(cat "$game_dir/launch.org.exe")"

it "still starts VRCOSC when the game directory has vanished"
rm -rf "$game_dir"
: > "$WORK/pt.log"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" VRCOSC_JOIN=0 \
    bash "$launcher" >/dev/null 2>&1
assert_contains "$(cat "$WORK/pt.log")" "VRCOSC.dll"

# --- hosts without diffutils --------------------------------------------------
# Minimal Fedora and Arch images have no cmp(1). A missing cmp used to read as
# "the files differ", so the bridge looked permanently unpatched and both the
# installer and the launcher rewrote launch.exe on every single run.
mkdir -p "$WORK/nocmp"
printf '#!/bin/sh\nexit 127\n' > "$WORK/nocmp/cmp"
chmod +x "$WORK/nocmp/cmp"
printf 'same\n' > "$WORK/a"; printf 'same\n' > "$WORK/b"; printf 'other\n' > "$WORK/c"

it "sees identical files as identical without cmp"
PATH="$WORK/nocmp:$PATH" files_identical "$WORK/a" "$WORK/b"
assert_ok "$?"

it "still sees differing files as different without cmp"
PATH="$WORK/nocmp:$PATH" files_identical "$WORK/a" "$WORK/c"
assert_fails "$?"

it "treats a missing file as not identical"
files_identical "$WORK/a" "$WORK/does-not-exist"
assert_fails "$?"

it "the launcher does not re-patch on a host without cmp"
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam2")"
game_dir="$(get_vrchat_game_dir)"
PATH="$WORK/bin:$PATH" create_launchers >/dev/null 2>&1
launcher="$(get_launcher_script)"
env PATH="$WORK/nocmp:$WORK/bin:/usr/bin:/bin" VRCOSC_JOIN=0 \
    bash "$launcher" >/dev/null 2>&1
: > "$WORK/launch.err"
env PATH="$WORK/nocmp:$WORK/bin:/usr/bin:/bin" VRCOSC_JOIN=0 \
    bash "$launcher" >/dev/null 2>"$WORK/launch.err"
assert_not_contains "$(cat "$WORK/launch.err")" "re-applied"

# --- patching is opt-in -------------------------------------------------------
# It writes into VRChat's own install directory, so it happens only on request.
PATCH_LAUNCH=0
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam3")"
game_dir="$(get_vrchat_game_dir)"

it "leaves launch.exe alone without --patch"
out="$(PATH="$WORK/bin:$PATH" patch_vrchat_launch_bridge 2>&1)"
assert_eq "MZ stub launch.exe" "$(cat "$game_dir/launch.exe")"

it "and says how to enable it"
assert_contains "$out" "--patch"

it "makes no backup it did not need"
assert_eq "1" "$([ -e "$game_dir/launch.org.exe" ] && echo 0 || echo 1)"

it "generates a launcher with no payload to re-patch from"
PATH="$WORK/bin:$PATH" create_launchers >/dev/null 2>&1
assert_contains "$(cat "$(get_launcher_script)")" 'BRIDGE_PAYLOAD=""'

it "and that launcher does not touch launch.exe"
env PATH="$WORK/bin:/usr/bin:/bin" VRCOSC_JOIN=0 \
    bash "$(get_launcher_script)" >/dev/null 2>"$WORK/launch.err"
assert_eq "MZ stub launch.exe" "$(cat "$game_dir/launch.exe")"

it "and still starts VRCOSC"
assert_not_contains "$(cat "$WORK/launch.err")" "re-applied"

it "patches once --patch is given"
PATCH_LAUNCH=1
PATH="$WORK/bin:$PATH" patch_vrchat_launch_bridge >/dev/null 2>&1
assert_eq "$(cat "$(get_launch_bridge_cache)")" "$(cat "$game_dir/launch.exe")"

# --patch and --path are the same switch, so a user who types either gets it.
it "--patch turns patching on"
( PATCH_LAUNCH=0; parse_arguments --patch; [ "$PATCH_LAUNCH" -eq 1 ] )
assert_ok "$?"

it "--path is accepted as an alias"
( PATCH_LAUNCH=0; parse_arguments --path; [ "$PATCH_LAUNCH" -eq 1 ] )
assert_ok "$?"

it "neither flag leaves patching off"
( PATCH_LAUNCH=0; parse_arguments --skip-firewall; [ "$PATCH_LAUNCH" -eq 0 ] )
assert_ok "$?"

summarise
