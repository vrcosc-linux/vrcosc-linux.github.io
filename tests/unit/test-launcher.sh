#!/usr/bin/env bash
# The launcher is what users actually run day to day, and it is regenerated on
# every install -- so it must be valid shell and must scrub the environment
# itself, independent of whatever shell the desktop entry is launched from.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
load_install_sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/home" "$WORK/bin"
# get_desktop_dir() shells out to xdg-user-dir, which would answer for the real
# user running the suite. Keep every shortcut inside the fake HOME.
cat > "$WORK/bin/xdg-user-dir" <<'STUB'
#!/usr/bin/env bash
echo "$HOME/Desktop"
STUB
chmod +x "$WORK/bin/xdg-user-dir"
# Stubbed up here, not beside the test that uses it: bash hashes a command the
# first time it resolves one, so the real update-desktop-database found during
# an earlier create_launchers would keep winning over a stub planted later.
cat > "$WORK/bin/update-desktop-database" <<'STUB'
#!/usr/bin/env bash
echo "$1" >> "$UDD_LOG"
STUB
chmod +x "$WORK/bin/update-desktop-database"
export UDD_LOG="$WORK/udd.log"
PATH="$WORK/bin:$PATH"
ln -sf "$FIXTURES/fake-protontricks" "$WORK/bin/protontricks"
HOME="$WORK/home"
VRC_COMPATDATA="$("$FIXTURES/make-prefix.sh" --root "$WORK/steam" --dotnet 9.0.14)"
DRY_RUN=0
MENU_SHORTCUT=1
DESKTOP_SHORTCUT=1

generate_for() {
    RESOLVED_RUNTIME_MODE="$1"
    VRCOSC_BRANCH="${2:-live}"
    rm -f "$(get_launcher_script)"
    create_launchers >/dev/null 2>&1
    get_launcher_script
}

for mode in no-bwrap host container; do
    launcher="$(generate_for "$mode")"

    it "generates a launcher for $mode mode"
    assert_file_exists "$launcher"

    it "the $mode launcher is syntactically valid"
    bash -n "$launcher" 2>"$WORK/err"
    assert_eq "" "$(cat "$WORK/err")"

    it "the $mode launcher scrubs leaked runtime variables at run time"
    : > "$WORK/pt.log"
    env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
        LD_LIBRARY_PATH=/runtime/lib FONTCONFIG_PATH=/runtime/etc/fonts \
        bash "$launcher" >/dev/null 2>&1
    assert_not_contains "$(cat "$WORK/pt.log")" "ENV: "
done

it "bakes the resolved runtime flags into the launcher"
launcher="$(generate_for host)"
assert_contains "$(cat "$launcher")" "--no-runtime"

it "uses no runtime flags for container mode"
launcher="$(generate_for container)"
assert_not_contains "$(cat "$launcher")" "--no-runtime"

it "points the live launcher at the live install directory"
launcher="$(generate_for no-bwrap live)"
assert_contains "$(cat "$launcher")" "AppData/Local/VRCOSC/VRCOSC.dll"

it "points the beta launcher at the beta install directory"
launcher="$(generate_for no-bwrap beta)"
assert_contains "$(cat "$launcher")" "AppData/Local/VRCOSC-beta/VRCOSC.dll"

it "forwards its own arguments through to VRCOSC"
: > "$WORK/pt.log"
env PATH="$WORK/bin:/usr/bin:/bin" FAKE_PT_LOG="$WORK/pt.log" \
    bash "$(generate_for no-bwrap live)" --some-vrcosc-flag >/dev/null 2>&1
assert_contains "$(cat "$WORK/pt.log")" "--some-vrcosc-flag"

# A user who installs beta keeps typing the `vrcosc` they are used to. If that
# script is a leftover from an older installer it runs through protontricks with
# no attempt to join VRChat's wine session, and dies in Velopack whenever VRChat
# is running -- so installing one branch must repair the other branch's script.
it "rewrites a stale launcher left behind for the other branch"
VRCOSC_BRANCH=beta
RESOLVED_RUNTIME_MODE=no-bwrap
stale="$(get_launcher_script live)"
mkdir -p "$(dirname "$stale")"
printf '#!/usr/bin/env bash\nexec protontricks -c "wine old" 438100\n' > "$stale"
create_launchers >/dev/null 2>&1
assert_contains "$(cat "$stale")" "launcher-generation: $LAUNCHER_GENERATION"

it "and keeps it pointed at its own branch"
assert_contains "$(cat "$stale")" "AppData/Local/VRCOSC/VRCOSC.dll"

it "does not invent a launcher for a branch that has none"
rm -f "$(get_launcher_script live)" "$(get_launcher_script beta)"
VRCOSC_BRANCH=beta
create_launchers >/dev/null 2>&1
assert_file_missing "$(get_launcher_script live)"

it "leaves a current launcher for the other branch alone"
VRCOSC_BRANCH=live
create_launchers >/dev/null 2>&1
current="$(get_launcher_script beta)"
VRCOSC_BRANCH=beta
create_launchers >/dev/null 2>&1
before="$(cat "$current")"
VRCOSC_BRANCH=live
create_launchers >/dev/null 2>&1
assert_eq "$before" "$(cat "$current")"

it "warns that VRChat cannot start while VRCOSC owns the prefix"
assert_contains "$(cat "$(get_launcher_script live)")" "VRChat cannot be started"

# Shortcuts. The menu entry has always been written; the desktop icon is new,
# and both must be refusable, because a headless or tidy-desktop install has no
# use for either.
reset_shortcuts() {
    rm -rf "$WORK/home/Desktop" "$WORK/home/.local/share/applications" "$WORK/home/.local/bin"
    MENU_SHORTCUT="$1"
    DESKTOP_SHORTCUT="$2"
    VRCOSC_BRANCH="${3:-live}"
    RESOLVED_RUNTIME_MODE=no-bwrap
    create_launchers >/dev/null 2>&1
}

it "creates a desktop shortcut by default"
reset_shortcuts 1 1
assert_file_exists "$(get_desktop_shortcut live)"

it "and the desktop shortcut is executable, as file managers require"
assert_file_executable "$(get_desktop_shortcut live)"

it "and it runs the launcher, not the dll directly"
assert_contains "$(cat "$(get_desktop_shortcut live)")" "Exec=$(get_launcher_script live)"

it "creates the menu entry by default"
assert_file_exists "$(get_desktop_file live)"

it "--no-desktop-shortcut leaves the desktop alone"
reset_shortcuts 1 0
assert_file_missing "$(get_desktop_shortcut live)"

it "but still writes the menu entry"
assert_file_exists "$(get_desktop_file live)"

it "--no-menu-shortcut leaves the application menu alone"
reset_shortcuts 0 1
assert_file_missing "$(get_desktop_file live)"

it "but still writes the desktop shortcut"
assert_file_exists "$(get_desktop_shortcut live)"

it "both flags together write neither"
reset_shortcuts 0 0
assert_file_missing "$(get_desktop_file live)"

it "and no desktop shortcut either"
assert_file_missing "$(get_desktop_shortcut live)"

it "but the launcher script is still written"
assert_file_exists "$(get_launcher_script live)"

it "names the beta shortcut separately from live"
reset_shortcuts 1 1 beta
assert_contains "$(get_desktop_shortcut beta)" "vrcosc-beta.desktop"

it "and labels it as the beta build"
assert_contains "$(cat "$(get_desktop_shortcut beta)")" "Name=VRCOSC (Beta)"

it "repairing a stale launcher does not add shortcuts the user never had"
reset_shortcuts 1 1 beta
rm -f "$(get_desktop_shortcut live)" "$(get_desktop_file live)"
printf '#!/usr/bin/env bash\nexec protontricks -c "wine old" 438100\n' > "$(get_launcher_script live)"
create_launchers >/dev/null 2>&1
assert_file_missing "$(get_desktop_shortcut live)"

it "but does refresh a shortcut that is already there"
reset_shortcuts 1 1 beta
write_desktop_entry "$(get_desktop_shortcut live)" "stale" "/nonexistent"
printf '#!/usr/bin/env bash\nexec protontricks -c "wine old" 438100\n' > "$(get_launcher_script live)"
create_launchers >/dev/null 2>&1
assert_contains "$(cat "$(get_desktop_shortcut live)")" "Exec=$(get_launcher_script live)"

# Desktops that read the mimeinfo cache rather than watching the directory do
# not show a new entry until it is rebuilt -- which, without this, meant the
# next login.
it "rebuilds the menu database after writing the menu entry"
: > "$UDD_LOG"
reset_shortcuts 1 1
assert_contains "$(cat "$UDD_LOG")" "$WORK/home/.local/share/applications"

it "and does not bother when the menu entry was refused"
: > "$UDD_LOG"
reset_shortcuts 0 1
assert_eq "" "$(cat "$UDD_LOG")"

it "uninstall knows about the desktop shortcuts"
assert_contains "$(get_all_installed_files)" "$(get_desktop_shortcut beta)"

summarise