#!/usr/bin/env bash

# VRCOSC automated installer, updater, and runner setup script for Bazzite / Linux
set -euo pipefail

# Visual styling
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0;0m' # No Color

readonly DISCORD_INVITE="https://discord.gg/vrcosc-1000862183963496519"
readonly DISCORD_THREAD="https://discord.com/channels/1000862183963496519/1466540047149957374"
readonly DEFAULT_DOTNET_CHANNEL="10.0"
readonly ICON_URL="https://raw.githubusercontent.com/VolcanicArts/VRCOSC/main/Logo.png"

# Default state variables (configured solely via command-line arguments)
VRCOSC_BRANCH="live" # live or beta
FORCE_INSTALL=0
UNINSTALL_MODE=0
BACKUP_MODE=0
INFO_MODE=0
DRY_RUN=0
SKIP_FIREWALL=0
VRC_COMPATDATA=""
RUNTIME_MODE="auto"        # auto | no-bwrap | host | container
RESOLVED_RUNTIME_MODE=""   # filled in by probe_runtime_mode()

log_info()    { echo -e "${BLUE}$*${NC}"; }
log_success() { echo -e "${GREEN}$*${NC}"; }
log_warn()    { echo -e "${YELLOW}$*${NC}"; }
log_error()   { echo -e "${RED}$*${NC}"; }

on_error() {
    local exit_code="$?"
    local line_no="$1"
    echo ""
    log_error "============================================================"
    log_error " Installation encountered an error (exit code $exit_code at line $line_no)!"
    log_error "============================================================"
    echo -e "${YELLOW}Need help or ran into an unexpected bug? Join the VRCOSC Discord:${NC}"
    echo -e "  * Server Invite:  ${CYAN}${DISCORD_INVITE}${NC}"
    echo -e "  * Linux Thread:   ${CYAN}${DISCORD_THREAD}${NC}"
    echo ""
    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

# --- Path & Integration Helper Functions ---
get_launcher_script() {
    [ "${1:-$VRCOSC_BRANCH}" = "beta" ] && echo "$HOME/.local/bin/vrcosc-beta" || echo "$HOME/.local/bin/vrcosc"
}

get_desktop_file() {
    [ "${1:-$VRCOSC_BRANCH}" = "beta" ] && echo "$HOME/.local/share/applications/vrcosc-beta.desktop" || echo "$HOME/.local/share/applications/vrcosc.desktop"
}

get_app_icon_path() {
    echo "$HOME/.local/share/icons/hicolor/256x256/apps/vrcosc.png"
}

get_vrcosc_install_dir() {
    local base="$VRC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local"
    [ "${1:-$VRCOSC_BRANCH}" = "beta" ] && echo "$base/VRCOSC-beta" || echo "$base/VRCOSC"
}

get_vrchat_game_dir() {
    local steamapps_dir="$(dirname "$(dirname "$VRC_COMPATDATA")")"
    echo "$steamapps_dir/common/VRChat"
}

get_all_installed_files() {
    echo "$(get_launcher_script live)" \
         "$(get_launcher_script beta)" \
         "$(get_desktop_file live)" \
         "$(get_desktop_file beta)" \
         "$(get_app_icon_path)"
}

get_vrcosc_version_from_dir() {
    local dir="$1"
    local deps="$dir/VRCOSC.deps.json"
    local dll="$dir/VRCOSC.dll"
    if [ -f "$deps" ]; then
        local v
        v="$(grep -o '"VRCOSC.App": "[^"]*"' "$deps" 2>/dev/null | head -n 1 | cut -d'"' -f4 || true)"
        [ -n "$v" ] && echo "$v" && return 0
    fi
    [ -f "$dll" ] && echo "Installed" && return 0
    echo "Not installed"
}

# GET a GitHub API URL. Uses GITHUB_TOKEN/GH_TOKEN when the caller has one,
# because the unauthenticated limit is 60 requests/hour per IP and shared or
# NAT'd addresses hit it routinely -- which otherwise looks like "GitHub is down".
# The token is only ever sent to api.github.com, and never echoed.
github_api() {
    local url="$1"
    local -a auth=()
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    if [ -n "$token" ] && [[ "$url" == https://api.github.com/* ]]; then
        auth=(-H "Authorization: Bearer $token")
    fi
    curl -fsS --connect-timeout 10 \
        -H "User-Agent: vrcosc-installer" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${auth[@]}" "$url" 2>&1 || true
}

# Drops trailing ".0" components so the four-part version recorded in
# VRCOSC.deps.json ("2026.812.0.0") compares equal to the three-part release tag
# it came from ("2026.812.0").
normalise_version() {
    local v="$1"
    while [ "$v" != "${v%.0}" ]; do
        v="${v%.0}"
    done
    echo "$v"
}

# Echoes "newer", "older" or "same" for version $1 relative to $2.
compare_versions() {
    local a b highest
    a="$(normalise_version "$1")"
    b="$(normalise_version "$2")"

    [ "$a" = "$b" ] && { echo "same"; return 0; }

    highest="$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n 1)"
    if [ "$highest" = "$a" ]; then
        echo "newer"
    else
        echo "older"
    fi
}

# The version a release asset URL delivers, taken from the tag in its path:
# .../releases/download/2026.807.0/VRCOSC-2026.807.0-live-full.nupkg
get_version_from_asset_url() {
    sed -n 's|.*/releases/download/\([^/]*\)/.*|\1|p' <<< "$1"
}

print_usage() {
    echo -e "${BOLD}VRCOSC Linux Installer & Manager${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  bash install.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -i, --info                Display diagnostic system, prefix, runtime, and VRCOSC environment info"
    echo "  -b, --backup              Create a high-compression backup of VRCOSC configs & prefix registries to Desktop"
    echo "  -f, --force               Force re-download and re-installation of .NET and VRCOSC"
    echo "      --branch <live|beta>  Specify release channel to install (default: live)"
    echo "  -u, --uninstall           Uninstall VRCOSC binaries, launcher script, and desktop shortcut"
    echo "      --dry-run             Simulate actions without writing files or running installers"
    echo "      --skip-firewall       Do not attempt firewall port configuration"
    echo "      --prefix <PATH>       Explicitly specify the VRChat compatdata/438100 folder"
    echo "      --runtime <MODE>      Steam Runtime mode for wine calls (default: auto)"
    echo "                              auto       probe modes below and use the first clean one"
    echo "                              no-bwrap   Steam Runtime without bwrap containerisation"
    echo "                              host       no Steam Runtime; use host libraries only"
    echo "                              container  Steam Runtime with bwrap containerisation"
    echo "  -h, --help                Show this help message"
}

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--info)
                INFO_MODE=1
                shift
                ;;
            -b|--backup)
                BACKUP_MODE=1
                shift
                ;;
            -f|--force)
                FORCE_INSTALL=1
                shift
                ;;
            -u|--uninstall)
                UNINSTALL_MODE=1
                shift
                ;;
            --branch)
                if [ -n "${2:-}" ]; then
                    VRCOSC_BRANCH="$2"
                    shift 2
                else
                    log_error "Error: --branch requires an argument (live or beta)."
                    exit 1
                fi
                ;;
            --prefix)
                if [ -n "${2:-}" ]; then
                    VRC_COMPATDATA="$2"
                    shift 2
                else
                    log_error "Error: --prefix requires a directory path."
                    exit 1
                fi
                ;;
            --runtime)
                case "${2:-}" in
                    auto|no-bwrap|host|container)
                        RUNTIME_MODE="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Error: --runtime requires one of: auto, no-bwrap, host, container."
                        exit 1
                        ;;
                esac
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --skip-firewall)
                SKIP_FIREWALL=1
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_warn "Unknown argument: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

check_dependencies() {
    log_info "Verifying dependencies..."
    local missing=()
    for cmd in protontricks curl unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Error: The following required dependencies are missing: ${missing[*]}"
        exit 1
    fi

    if ! command -v nsenter &>/dev/null; then
        log_warn "nsenter (util-linux) not found: VRCOSC will run in its own wine session and will not see VRChat."
    fi
}

# --- Proton / Steam Runtime Environment Hygiene ---

# Variables a Steam-launched shell (or a half-initialised Steam Runtime) exports
# into our environment. Left in place they make wine load the runtime's pinned
# libraries while still reading the host's config files, which surfaces as
# misleading errors such as:
#   Fontconfig error: "/etc/fonts/fonts.conf", line 86: out of memory
# fontconfig reports every config parse failure as "out of memory" -- there is no
# actual memory pressure, the library and the config file simply disagree.
readonly -a CONTAMINATING_ENV_VARS=(
    LD_LIBRARY_PATH LD_PRELOAD LD_AUDIT
    FONTCONFIG_PATH FONTCONFIG_FILE
    GTK_PATH GDK_PIXBUF_MODULE_FILE GIO_MODULE_DIR
    GST_PLUGIN_SYSTEM_PATH GST_PLUGIN_SYSTEM_PATH_1_0
    STEAM_RUNTIME STEAM_RUNTIME_LIBRARY_PATH SYSTEM_LD_LIBRARY_PATH
    PRESSURE_VESSEL_RUNTIME PRESSURE_VESSEL_RUNTIME_BASE PRESSURE_VESSEL_PREFIX
    WINEPREFIX WINEDLLPATH WINELOADER WINESERVER
)

# Prints the names of contaminating variables that are currently set.
list_contaminated_env() {
    local v
    for v in "${CONTAMINATING_ENV_VARS[@]}"; do
        [ -n "${!v:-}" ] && echo "$v"
    done
    return 0
}

# Maps a runtime mode onto the protontricks flags that implement it.
runtime_mode_flags() {
    case "$1" in
        no-bwrap)  echo "--no-bwrap" ;;
        host)      echo "--no-runtime" ;;
        container) echo "" ;;
        *)         echo "--no-bwrap" ;;
    esac
}

# Runs a wine command inside the VRChat prefix with a sanitised environment.
# Every protontricks invocation in this script goes through here so the runtime
# mode and the environment scrubbing are configured in exactly one place.
run_in_prefix() {
    local mode="${RESOLVED_RUNTIME_MODE:-$RUNTIME_MODE}"
    [ "$mode" = "auto" ] && mode="no-bwrap"

    local -a flags=()
    read -r -a flags <<< "$(runtime_mode_flags "$mode")"

    local -a scrub=()
    local v
    for v in "${CONTAMINATING_ENV_VARS[@]}"; do
        scrub+=("-u" "$v")
    done

    env "${scrub[@]}" timeout "${PREFIX_CMD_TIMEOUT:-0}" \
        protontricks "${flags[@]}" -c "$1" 438100
}

# True when wine output shows a broken library/config environment rather than a
# genuine application failure.
prefix_output_is_broken() {
    grep -qE 'Fontconfig error|error while loading shared libraries|wine: (failed|cannot|could not)' <<< "$1"
}

# Processes currently holding this prefix, as "<pid> <name>" lines.
#
# A wine prefix can only be owned by one wineserver at a time, and Steam's Proton
# and a protontricks-launched wine set that session up differently -- different
# environment, different container, no Proton session handshake. Whichever starts
# second either refuses to run or comes up unable to query the wineserver. That
# is why VRChat and VRCOSC appear mutually exclusive, and why VRCOSC crashed in
# Velopack's updater (`GetCurrentProcessPath` -> `EnumProcessModules` ->
# "Access denied") when it was started while VRChat was already running.
get_prefix_holders() {
    local pfx="$VRC_COMPATDATA/pfx"
    local proc pid name
    for proc in /proc/[0-9]*; do
        [ -r "$proc/environ" ] || continue
        # Proton exports "WINEPREFIX=<path>/" with a trailing slash while
        # protontricks exports it without, so both spellings must match.
        tr '\0' '\n' < "$proc/environ" 2>/dev/null \
            | grep -qxF -e "WINEPREFIX=$pfx" -e "WINEPREFIX=$pfx/" || continue
        pid="${proc#/proc/}"
        name="$(cat "$proc/comm" 2>/dev/null || true)"
        echo "$pid ${name:-unknown}"
    done
    return 0
}

# Notes when a wine session other than VRChat's is using this prefix.
#
# VRChat itself holding the prefix is normal and expected -- the launcher joins
# that session on purpose. A different session (a VRCOSC already running under
# protontricks, say) is worth mentioning before we write into the prefix.
warn_if_prefix_busy() {
    local holders others
    holders="$(get_prefix_holders)"
    [ -n "$holders" ] || return 0

    find_vrchat_container_pid >/dev/null 2>&1 && return 0

    others="$(printf '%s' "$holders" | awk '{print $2}' | sort -u | tr '\n' ' ')"
    log_warn "Wine processes are already running in this prefix: ${others}"
    echo -e "${YELLOW}Installing should still work. If VRCOSC later fails to start, close it${NC}"
    echo -e "${YELLOW}and VRChat, wait for wineserver to exit, and run the installer again.${NC}"
}

# Runtime modes tried by "auto", in order. no-bwrap first so hosts that already
# work keep their behaviour; host next, since it is what fixes a Proton build
# protontricks cannot pair with a runtime; container last.
readonly -a RUNTIME_MODE_CANDIDATES=(no-bwrap host container)

# Smoke-tests one runtime mode by asking wine for its version. Echoes a short
# human-readable result and returns 0 only when the environment came back clean.
test_runtime_mode() {
    local candidate="$1" out rc=0
    out="$(PREFIX_CMD_TIMEOUT=180 RESOLVED_RUNTIME_MODE="$candidate" \
        run_in_prefix "wine --version" 2>&1)" || rc=$?

    if [ "$rc" -eq 0 ] && ! prefix_output_is_broken "$out"; then
        echo "$(grep -oE 'wine-[0-9][^[:space:]]*' <<< "$out" | head -n 1 || echo 'wine ok')"
        return 0
    fi

    local reason
    reason="$(grep -E 'Fontconfig error|error while loading|wine: ' <<< "$out" \
        | head -n 1 | sed 's/^[[:space:]]*//' || true)"
    echo "exit=$rc${reason:+ -- $reason}"
    return 1
}

# The Proton build a prefix was last created or updated with. config_info holds
# the version string on line 1 and <proton root>/files/share/fonts/ on line 2.
get_prefix_proton_version() {
    local ci="$VRC_COMPATDATA/config_info"
    [ -f "$ci" ] || return 1
    head -n 1 "$ci"
}

get_prefix_proton_dir() {
    local ci="$VRC_COMPATDATA/config_info"
    [ -f "$ci" ] || return 1
    local fonts_dir
    fonts_dir="$(sed -n '2p' "$ci")"
    [ -n "$fonts_dir" ] || return 1
    fonts_dir="${fonts_dir%/}"                       # .../files/share/fonts
    echo "$(dirname "$(dirname "$(dirname "$fonts_dir")")")"
}

# The pid of a running VRChat.exe that owns this prefix inside Steam's
# pressure-vessel container, or nothing.
#
# Steam runs the game inside its own user+mount namespace. A wine process
# started from the host cannot usefully join that wineserver: it does connect,
# but the wineserver cannot read a process outside its user namespace, so the
# first module query -- Velopack's GetCurrentProcessPath() -- fails with
# "Access denied" and VRCOSC dies before it has a window. Entering the game's
# namespaces first (nsenter -U -m, allowed unprivileged because we own them)
# puts VRCOSC in the same wine session as VRChat: same process table, same named
# pipes, same windows, which is what VRChatClient needs to ever report the game
# as open.
find_vrchat_container_pid() {
    local pfx="$VRC_COMPATDATA/pfx"
    local proc
    for proc in /proc/[0-9]*; do
        [ "$(cat "$proc/comm" 2>/dev/null)" = "VRChat.exe" ] || continue
        [ -r "$proc/environ" ] || continue
        tr '\0' '\n' < "$proc/environ" 2>/dev/null \
            | grep -qxF -e "WINEPREFIX=$pfx" -e "WINEPREFIX=$pfx/" || continue
        tr '\0' '\n' < "$proc/environ" 2>/dev/null | grep -q '^PRESSURE_VESSEL_RUNTIME=' || continue
        echo "${proc#/proc/}"
        return 0
    done
    return 1
}

# Writes VRChat's own environment as a sourceable file, so a joining process
# runs with exactly Proton's settings (WINEDLLOVERRIDES, esync/fsync, paths).
# Per-process loader state is dropped; so is anything that is not a valid shell
# identifier, since some launchers export odd keys.
write_session_env_file() {
    local pid="$1" out="$2"
    tr '\0' '\n' < "/proc/$pid/environ" \
        | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' \
        | grep -vE '^(WINELOADERNOEXEC|WINEPRELOADRESERVE|WINEDEBUG|_|PWD|OLDPWD|SHLVL)=' \
        | while IFS= read -r line; do
            printf 'export %s=%q\n' "${line%%=*}" "${line#*=}"
        done > "$out"
}

# The Steam Runtime app id a Proton build demands, if it declares one. A build
# that requires a runtime protontricks cannot locate is the usual source of
# "Current Steam Runtime not recognized by Protontricks".
get_prefix_runtime_appid() {
    local proton_dir
    proton_dir="$(get_prefix_proton_dir)" || return 1
    local manifest="$proton_dir/toolmanifest.vdf"
    [ -f "$manifest" ] || return 1
    grep -oE '"require_tool_appid"[[:space:]]*"[0-9]+"' "$manifest" \
        | grep -oE '[0-9]+' | head -n 1
}

# Picks the runtime mode to use for every subsequent wine call. An explicit
# --runtime is honoured as-is; "auto" probes candidates and takes the first one
# that yields a clean `wine --version`.
probe_runtime_mode() {
    if [ "$RUNTIME_MODE" != "auto" ]; then
        RESOLVED_RUNTIME_MODE="$RUNTIME_MODE"
        log_info "Using requested Proton runtime mode: ${BOLD}${RESOLVED_RUNTIME_MODE}${NC}"
        return 0
    fi

    local contaminated
    contaminated="$(list_contaminated_env | tr '\n' ' ')"
    if [ -n "$contaminated" ]; then
        log_warn "Scrubbing leaked Steam Runtime variables from wine calls: $contaminated"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        RESOLVED_RUNTIME_MODE="no-bwrap"
        log_info "Dry run: skipping runtime probe, assuming mode '$RESOLVED_RUNTIME_MODE'."
        return 0
    fi

    local candidate result
    for candidate in "${RUNTIME_MODE_CANDIDATES[@]}"; do
        log_info "Probing Proton runtime mode '$candidate'..."
        if result="$(test_runtime_mode "$candidate")"; then
            RESOLVED_RUNTIME_MODE="$candidate"
            log_success "Runtime mode '$candidate' is usable (${result})."
            return 0
        fi
        log_warn "Runtime mode '$candidate' produced a broken wine environment: ${result}"
    done

    log_error "No Steam Runtime mode produced a working wine environment."
    echo -e "${YELLOW}This usually means protontricks cannot pair your Proton build with a Steam Runtime.${NC}"
    echo -e "Try launching VRChat once through Steam, then re-run this script."
    echo -e "You can also force a mode explicitly, e.g. ${CYAN}--runtime host${NC}."
    exit 1
}

find_prefix_silently() {
    if [ -n "$VRC_COMPATDATA" ]; then
        VRC_COMPATDATA="${VRC_COMPATDATA/#\~/$HOME}"
        if [ -d "$VRC_COMPATDATA/pfx" ]; then
            return 0
        elif [ -d "$VRC_COMPATDATA/compatdata/438100/pfx" ]; then
            VRC_COMPATDATA="$VRC_COMPATDATA/compatdata/438100"
            return 0
        fi
    fi

    local candidate_paths=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
        "/run/media/system/Data/Games/Steam"
        "/media/media-automount/Data/Games/Steam"
    )

    for vdf in "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
               "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
               "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf"; do
        if [ -f "$vdf" ]; then
            while IFS= read -r line; do
                if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                    candidate_paths+=("${BASH_REMATCH[1]}")
                fi
            done < "$vdf"
        fi
    done

    for p in "${candidate_paths[@]}"; do
        for check_dir in "$p" "$p/steamapps"; do
            if [ -d "$check_dir/compatdata/438100/pfx" ]; then
                VRC_COMPATDATA="$check_dir/compatdata/438100"
                return 0
            fi
        done
    done
    return 1
}

locate_vrchat_prefix() {
    log_info "Locating VRChat Proton prefix..."

    if find_prefix_silently; then
        log_success "Found VRChat compatibility data at: $VRC_COMPATDATA"
        return 0
    fi

    # Fallback to interactive user input if available
    log_warn "Could not automatically locate the VRChat (438100) Proton prefix."
    if [ -t 0 ]; then
        while [ -z "$VRC_COMPATDATA" ]; do
            log_info "Please enter the path to your SteamLibrary or the 438100 compatdata folder:"
            read -r -p "Path: " user_path
            user_path="${user_path/#\~/$HOME}"

            if [ -d "$user_path/pfx" ] && [[ "$user_path" == *"438100"* ]]; then
                VRC_COMPATDATA="$user_path"
            elif [ -d "$user_path/compatdata/438100/pfx" ]; then
                VRC_COMPATDATA="$user_path/compatdata/438100"
            elif [ -d "$user_path/steamapps/compatdata/438100/pfx" ]; then
                VRC_COMPATDATA="$user_path/steamapps/compatdata/438100"
            else
                log_error "Invalid path. Could not find 'pfx' folder for app 438100 under '$user_path'. Please try again."
            fi
        done
        log_success "Using VRChat prefix at: $VRC_COMPATDATA"
    else
        log_error "Error: Running non-interactively and prefix was not found."
        echo "Pass --prefix <PATH> explicitly."
        exit 1
    fi
}

show_diagnostics() {
    # Diagnostics are best-effort by nature: a probe that fails is itself a
    # finding, so nothing in here may abort the report. Without this, a single
    # non-zero `protontricks --version` (or any grep that matches nothing, under
    # `set -o pipefail`) tripped the ERR trap and truncated the output at
    # whichever section happened to be printing.
    set +e
    trap - ERR

    log_info "Collecting diagnostic and environment information..."
    echo ""

    # System & OS Information
    echo -e "${BOLD}=== System & OS Environment ===${NC}"
    local os_pretty="Unknown"
    [ -f /etc/os-release ] && os_pretty="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2- | tr -d '"' || true)"
    local kernel_ver="$(uname -r 2>/dev/null || echo 'Unknown')"
    local arch="$(uname -m 2>/dev/null || echo 'Unknown')"
    local de="${XDG_CURRENT_DESKTOP:-Unknown}"
    local session_type="${XDG_SESSION_TYPE:-Unknown}"
    local desktop_session="${DESKTOP_SESSION:-Unknown}"

    echo -e "  * OS:                    ${CYAN}${os_pretty}${NC}"
    echo -e "  * Kernel:                ${CYAN}${kernel_ver} (${arch})${NC}"
    echo -e "  * Desktop Environment:   ${CYAN}${de} (${session_type})${NC}"
    echo -e "  * Session:               ${CYAN}${desktop_session}${NC}"

    # Tooling
    echo ""
    echo -e "${BOLD}=== Tooling & Runtime Dependencies ===${NC}"
    local pt_ver="Not installed"
    command -v protontricks &>/dev/null && pt_ver="$(protontricks --version 2>&1 | grep -vi 'warning\|deprecat' | head -n 1 || true)"
    local curl_ver="Not installed"
    command -v curl &>/dev/null && curl_ver="$(curl --version 2>&1 | head -n 1 | awk '{print $1, $2}' || true)"
    local unzip_ver="Not installed"
    command -v unzip &>/dev/null && unzip_ver="Installed ($(command -v unzip || true))"
    local archiver="tar/xz"
    if command -v 7z &>/dev/null; then
        local z7_ver="$(7z 2>&1 | grep -i '7-Zip' | head -n 1 | awk '{print $2}' || true)"
        archiver="7z (${z7_ver:-installed})"
    fi

    echo -e "  * Protontricks:          ${CYAN}${pt_ver}${NC}"
    echo -e "  * cURL:                  ${CYAN}${curl_ver}${NC}"
    echo -e "  * Unzip:                 ${CYAN}${unzip_ver}${NC}"
    echo -e "  * Compression Tool:      ${CYAN}${archiver}${NC}"

    # Prefix & Wine Configuration
    echo ""
    echo -e "${BOLD}=== VRChat Proton Prefix ===${NC}"
    find_prefix_silently || true

    if [ -n "$VRC_COMPATDATA" ] && [ -d "$VRC_COMPATDATA/pfx" ]; then
        echo -e "  * Prefix Root:           ${CYAN}${VRC_COMPATDATA}${NC}"
        echo -e "  * Prefix pfx:            ${CYAN}${VRC_COMPATDATA}/pfx${NC}"

        local proton_ver proton_dir runtime_appid
        proton_ver="$(get_prefix_proton_version || echo 'Unknown (prefix never launched?)')"
        proton_dir="$(get_prefix_proton_dir || echo 'Unknown')"
        runtime_appid="$(get_prefix_runtime_appid || echo '')"
        echo -e "  * Proton Build:          ${CYAN}${proton_ver}${NC}"
        echo -e "  * Proton Path:           ${CYAN}${proton_dir}${NC}"
        if [ -n "$runtime_appid" ]; then
            echo -e "  * Required Steam Runtime: ${CYAN}appid ${runtime_appid}${NC}"
        else
            echo -e "  * Required Steam Runtime: ${YELLOW}None declared (custom Proton; protontricks may not find a runtime)${NC}"
        fi

        local user_reg_status="Missing"
        [ -f "$VRC_COMPATDATA/pfx/user.reg" ] && user_reg_status="Present"
        local sys_reg_status="Missing"
        [ -f "$VRC_COMPATDATA/pfx/system.reg" ] && sys_reg_status="Present"

        echo -e "  * Registry (user.reg):   ${CYAN}${VRC_COMPATDATA}/pfx/user.reg${NC} (${user_reg_status})"
        echo -e "  * Registry (system.reg): ${CYAN}${VRC_COMPATDATA}/pfx/system.reg${NC} (${sys_reg_status})"

        local wpf_disabled=0
        if [ -f "$VRC_COMPATDATA/pfx/user.reg" ] && grep -q 'DisableHWAcceleration' "$VRC_COMPATDATA/pfx/user.reg"; then
            wpf_disabled=1
        elif [ -f "$VRC_COMPATDATA/pfx/system.reg" ] && grep -q 'DisableHWAcceleration' "$VRC_COMPATDATA/pfx/system.reg"; then
            wpf_disabled=1
        fi
        if [ "$wpf_disabled" -eq 1 ]; then
            echo -e "  * WPF HW Accel Patch:    ${GREEN}Applied (DisableHWAcceleration=1)${NC}"
        else
            echo -e "  * WPF HW Accel Patch:    ${YELLOW}Not detected (Black window issue may occur)${NC}"
        fi

        local dotnet_exe="$VRC_COMPATDATA/pfx/drive_c/Program Files/dotnet/dotnet.exe"
        local dotnet_status="Not installed"
        [ -f "$dotnet_exe" ] && dotnet_status="Installed ($dotnet_exe)"
        echo -e "  * .NET Binary:           ${CYAN}${dotnet_status}${NC}"

        local desktop_runtimes=()
        local shared_dir="$VRC_COMPATDATA/pfx/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App"
        if [ -d "$shared_dir" ]; then
            for d in "$shared_dir/"*; do
                [ -d "$d" ] && desktop_runtimes+=("$(basename "$d")")
            done
        fi
        if [ ${#desktop_runtimes[@]} -gt 0 ]; then
            echo -e "  * .NET WindowsDesktop:   ${CYAN}${desktop_runtimes[*]}${NC}"
        else
            echo -e "  * .NET WindowsDesktop:   ${YELLOW}None detected${NC}"
        fi

        local required_channel
        required_channel="$(get_required_dotnet_channel "$(get_vrcosc_install_dir)" || echo '')"
        if [ -z "$required_channel" ]; then
            echo -e "  * .NET Required by App:  ${YELLOW}Unknown (VRCOSC.runtimeconfig.json not readable)${NC}"
        elif has_desktop_runtime_channel "$required_channel"; then
            echo -e "  * .NET Required by App:  ${GREEN}${required_channel}.x (satisfied)${NC}"
        else
            echo -e "  * .NET Required by App:  ${RED}${required_channel}.x (MISSING -- VRCOSC will not start)${NC}"
            echo -e "    ${YELLOW}.NET does not roll forward across major versions; run install.sh again to fix.${NC}"
        fi

        echo ""
        echo -e "${BOLD}=== Wine Environment Health ===${NC}"
        local contaminated
        contaminated="$(list_contaminated_env | tr '\n' ' ')"
        if [ -n "$contaminated" ]; then
            echo -e "  * Leaked Runtime Vars:   ${YELLOW}${contaminated}${NC}"
            echo -e "    ${YELLOW}These are scrubbed from wine calls; unscrubbed they cause bogus errors${NC}"
            echo -e "    ${YELLOW}such as 'Fontconfig error: /etc/fonts/fonts.conf: out of memory'.${NC}"
        else
            echo -e "  * Leaked Runtime Vars:   ${GREEN}None${NC}"
        fi

        local vrc_pid
        if vrc_pid="$(find_vrchat_container_pid)"; then
            if command -v nsenter &>/dev/null; then
                echo -e "  * VRChat Session:        ${GREEN}Running in Steam's container (pid ${vrc_pid}); launcher will join it${NC}"
            else
                echo -e "  * VRChat Session:        ${YELLOW}Running (pid ${vrc_pid}) but nsenter is missing; cannot join it${NC}"
            fi
        else
            echo -e "  * VRChat Session:        ${CYAN}Not running (VRCOSC will start a session of its own)${NC}"
        fi

        local holders holder_count
        holders="$(get_prefix_holders)"
        holder_count="$(printf '%s' "$holders" | grep -c . || true)"
        if [ "$holder_count" -gt 0 ]; then
            echo -e "  * Wine Processes In Prefix: ${CYAN}${holder_count}${NC} ($(printf '%s' "$holders" | awk '{print $2}' | sort -u | head -n 4 | tr '\n' ' ')...)"
        else
            echo -e "  * Wine Processes In Prefix: ${GREEN}None (prefix idle)${NC}"
        fi

        local candidate result
        for candidate in "${RUNTIME_MODE_CANDIDATES[@]}"; do
            if result="$(test_runtime_mode "$candidate")"; then
                printf '  * Runtime [%-9s]:  ' "$candidate"
                echo -e "${GREEN}OK (${result})${NC}"
            else
                printf '  * Runtime [%-9s]:  ' "$candidate"
                echo -e "${RED}Broken${NC} ${YELLOW}${result}${NC}"
            fi
        done

        echo ""
        echo -e "${BOLD}=== VRCOSC User Config Directories ===${NC}"
        local cfgs_found=0
        for u in "$VRC_COMPATDATA/pfx/drive_c/users/"*; do
            local uname="$(basename "$u")"
            for ch in "VRCOSC:Live" "VRCOSC-Beta:Beta"; do
                local folder="${ch%%:*}"
                local label="${ch##*:}"
                local cfg_dir="$u/AppData/Roaming/$folder"
                if [ -d "$cfg_dir" ]; then
                    local real_tgt=""
                    [ -L "$cfg_dir" ] && real_tgt=" -> $(readlink "$cfg_dir")"
                    echo -e "  * User [${uname}] (${label}):     ${CYAN}${cfg_dir}${NC}${real_tgt}"
                    cfgs_found=1
                fi
            done
        done
        [ "$cfgs_found" -eq 0 ] && echo -e "  * ${YELLOW}No active VRCOSC AppData config directories found.${NC}"

        echo ""
        echo -e "${BOLD}=== VRCOSC Installation & Versions ===${NC}"
        echo -e "  * Local Version (Live):   ${CYAN}$(get_vrcosc_version_from_dir "$(get_vrcosc_install_dir live)")${NC}"
        echo -e "  * Local Version (Beta):   ${CYAN}$(get_vrcosc_version_from_dir "$(get_vrcosc_install_dir beta)")${NC}"
    else
        echo -e "  * Prefix Root:           ${YELLOW}Not detected (use --prefix <PATH> if located on an external drive)${NC}"
    fi

    # Remote GitHub Releases
    local remote_live="Unavailable (Network/Rate-limited)"
    local remote_beta="Unavailable (Network/Rate-limited)"
    local releases_json
    releases_json="$(github_api https://api.github.com/repos/VolcanicArts/VRCOSC/releases)"
    if [ -n "$releases_json" ]; then
        if command -v python3 &>/dev/null; then
            remote_live="$(python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(next((r['tag_name'] for r in data if not r.get('prerelease')), 'Unavailable'))" <<< "$releases_json" 2>/dev/null || echo 'Unavailable')"
            remote_beta="$(python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(next((r['tag_name'] for r in data if r.get('prerelease')), 'Unavailable'))" <<< "$releases_json" 2>/dev/null || echo 'Unavailable')"
        else
            remote_live="$(echo "$releases_json" | grep -B 10 -A 2 '"prerelease": false' | grep '"tag_name":' | head -n 1 | cut -d'"' -f4 || echo 'Unavailable')"
            remote_beta="$(echo "$releases_json" | grep -B 10 -A 2 '"prerelease": true' | grep '"tag_name":' | head -n 1 | cut -d'"' -f4 || echo 'Unavailable')"
        fi
    fi
    if grep -qE 'error: 403|rate limit' <<< "$releases_json"; then
        remote_live="Rate-limited (export GITHUB_TOKEN to check)"
        remote_beta="$remote_live"
    fi
    echo -e "  * Remote Latest (Live):   ${CYAN}${remote_live}${NC}"
    echo -e "  * Remote Latest (Beta):   ${CYAN}${remote_beta}${NC}"

    echo ""
    echo -e "${BOLD}=== Integration & Launchers ===${NC}"
    local v_live="$(get_launcher_script live)"
    local v_beta="$(get_launcher_script beta)"
    local d_live="$(get_desktop_file live)"
    local d_beta="$(get_desktop_file beta)"
    local icon_path="$(get_app_icon_path)"

    echo -e "  * Command (vrcosc):        $([ -f "$v_live" ] && echo -e "${CYAN}Installed ($v_live)${NC}" || echo -e "${YELLOW}Missing${NC}")"
    echo -e "  * Command (vrcosc-beta):   $([ -f "$v_beta" ] && echo -e "${CYAN}Installed ($v_beta)${NC}" || echo -e "${YELLOW}Missing${NC}")"
    echo -e "  * Desktop (Live):          $([ -f "$d_live" ] && echo -e "${CYAN}Present ($d_live)${NC}" || echo -e "${YELLOW}Missing${NC}")"
    echo -e "  * Desktop (Beta):          $([ -f "$d_beta" ] && echo -e "${CYAN}Present ($d_beta)${NC}" || echo -e "${YELLOW}Missing${NC}")"
    echo -e "  * Icon:                    $([ -f "$icon_path" ] && echo -e "${CYAN}Present ($icon_path)${NC}" || echo -e "${YELLOW}Missing${NC}")"

    local vrc_game_dir="$(get_vrchat_game_dir)"
    local target_launch="$vrc_game_dir/launch.exe"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_bridge="$script_dir/bin/vrc-launch-bridge.exe"
    local bridge_status="${YELLOW}Unpatched / Missing${NC}"
    if [ -f "$target_launch" ] && [ -f "$source_bridge" ] && cmp -s "$source_bridge" "$target_launch"; then
        bridge_status="${GREEN}Patched (Linux IPC Named-Pipe Bridge)${NC}"
    elif [ -f "$target_launch" ]; then
        bridge_status="${YELLOW}Stock launch.exe (Unpatched)${NC}"
    fi
    echo -e "  * VRChat Launch Bridge:    ${bridge_status}"

    echo ""
    echo -e "${BOLD}=== Community & Support ===${NC}"
    echo -e "  * Server Invite:           ${CYAN}${DISCORD_INVITE}${NC}"
    echo -e "  * Linux Discussion:        ${CYAN}${DISCORD_THREAD}${NC}"
    echo ""
}

create_backup() {
    log_info "Initiating VRCOSC and prefix backup..."
    locate_vrchat_prefix

    local desktop_dir
    desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
    mkdir -p "$desktop_dir"

    local timestamp="$(date +%s)"
    local stage_dir="/tmp/vrcosc_backup_${timestamp}"
    mkdir -p "$stage_dir"

    local items_found=0

    # 1. Config directories (Roaming/VRCOSC, Roaming/VRCOSC-Beta)
    for u in "$VRC_COMPATDATA/pfx/drive_c/users/"*; do
        local username="$(basename "$u")"
        for folder in "VRCOSC" "VRCOSC-Beta"; do
            if [ -d "$u/AppData/Roaming/$folder" ]; then
                mkdir -p "$stage_dir/users/${username}/AppData/Roaming"
                cp -a "$u/AppData/Roaming/$folder" "$stage_dir/users/${username}/AppData/Roaming/"
                items_found=1
            fi
        done
    done

    # Prune any broken or circular symbolic links to avoid compression errors
    find "$stage_dir" -xtype l -delete 2>/dev/null || true

    # 2. Wine prefix registry files
    for reg in "user.reg" "system.reg"; do
        if [ -f "$VRC_COMPATDATA/pfx/$reg" ]; then
            cp "$VRC_COMPATDATA/pfx/$reg" "$stage_dir/"
            items_found=1
        fi
    done

    # 3. Launchers & desktop shortcuts
    for f in $(get_all_installed_files); do
        if [ -f "$f" ]; then
            mkdir -p "$stage_dir/launchers"
            cp "$f" "$stage_dir/launchers/"
            items_found=1
        fi
    done

    if [ "$items_found" -eq 0 ]; then
        log_warn "No VRCOSC configurations or registries found to backup."
        rm -rf "$stage_dir"
        return 0
    fi

    local archive_path=""
    if command -v 7z &>/dev/null; then
        archive_path="$desktop_dir/VRCOSC_backup_${timestamp}.7z"
        log_info "Compressing backup using 7z (LZMA2 ultra compression)..."
        7z a -t7z -m0=lzma2 -mx=9 -snl -bso0 -bsp0 "$archive_path" "$stage_dir"/*
    elif command -v tar &>/dev/null && command -v xz &>/dev/null; then
        archive_path="$desktop_dir/VRCOSC_backup_${timestamp}.tar.xz"
        log_info "Compressing backup using tar.xz (max compression)..."
        XZ_OPT="-9e" tar -cJf "$archive_path" -C "$stage_dir" .
    else
        archive_path="$desktop_dir/VRCOSC_backup_${timestamp}.tar.gz"
        log_info "Compressing backup using tar.gz..."
        tar -czf "$archive_path" -C "$stage_dir" .
    fi

    rm -rf "$stage_dir"
    log_success "Backup created successfully:"
    echo -e "  * ${CYAN}${archive_path}${NC}"
}

configure_protontricks_permissions() {
    if flatpak list 2>/dev/null | grep -q "protontricks"; then
        log_info "Updating flatpak sandbox permissions for protontricks..."
        [ "$DRY_RUN" -eq 1 ] && return 0
        flatpak override --user --filesystem=host com.github.Matoking.protontricks || true
        flatpak override --user --talk-name=org.mpris.MediaPlayer2.* com.github.Matoking.protontricks || true
        flatpak override --user --talk-name=org.freedesktop.Flatpak com.github.Matoking.protontricks || true
    fi
}

apply_wpf_registry_fix() {
    log_info "Applying WPF hardware acceleration registry fix (prevents black window bug)..."
    [ "$DRY_RUN" -eq 1 ] && return 0

    local reg_file="$VRC_COMPATDATA/pfx/drive_c/vrcosc_disable_hw_acc.reg"

    cat << 'EOF_REG' > "$reg_file"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Avalon.Graphics]
"DisableHWAcceleration"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Microsoft\Avalon.Graphics]
"DisableHWAcceleration"=dword:00000001
EOF_REG

    run_in_prefix "wine regedit C:\\vrcosc_disable_hw_acc.reg"
    rm -f "$reg_file"
    log_success "WPF registry patch applied successfully."
}

# Reads the .NET runtime band VRCOSC actually asks for out of its
# runtimeconfig.json, as a "<major>.<minor>" channel. .NET's default rollForward
# policy does not cross major versions, so installing the wrong major (10.0 for
# a net9.0 build, say) leaves VRCOSC reporting that no runtime is installed even
# though dotnet.exe sits right there in the same prefix.
get_required_dotnet_channel() {
    local dir="${1:-$(get_vrcosc_install_dir)}"
    local cfg="$dir/VRCOSC.runtimeconfig.json"
    [ -f "$cfg" ] || return 1

    local channel=""
    if command -v python3 &>/dev/null; then
        channel="$(python3 - "$cfg" <<'PY' 2>/dev/null || true
import json, re, sys

with open(sys.argv[1]) as fh:
    opts = json.load(fh).get("runtimeOptions", {})

frameworks = opts.get("frameworks", [])
if "framework" in opts:
    frameworks = [opts["framework"]] + list(frameworks)

for fw in frameworks:
    if fw.get("name") == "Microsoft.WindowsDesktop.App" and fw.get("version"):
        print(".".join(fw["version"].split(".")[:2]))
        break
else:
    match = re.match(r"net(\d+\.\d+)", opts.get("tfm", ""))
    if match:
        print(match.group(1))
PY
)"
    fi

    # Fallback for hosts without python3: first version-looking field wins.
    if [ -z "$channel" ]; then
        channel="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+' "$cfg" \
            | head -n 1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
    fi
    if [ -z "$channel" ]; then
        channel="$(grep -oE '"tfm"[[:space:]]*:[[:space:]]*"net[0-9]+\.[0-9]+' "$cfg" \
            | head -n 1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
    fi

    [ -n "$channel" ] || return 1
    echo "$channel"
}

# Lists the Microsoft.WindowsDesktop.App versions present in the prefix.
get_installed_desktop_runtimes() {
    local shared_dir="$VRC_COMPATDATA/pfx/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App"
    [ -d "$shared_dir" ] || return 0
    local d
    for d in "$shared_dir"/*; do
        [ -d "$d" ] && basename "$d"
    done
}

# True when a runtime matching the requested "<major>.<minor>" channel is present.
has_desktop_runtime_channel() {
    local channel="$1" installed
    while IFS= read -r installed; do
        [ -n "$installed" ] || continue
        [[ "$installed" == "$channel".* ]] && return 0
    done < <(get_installed_desktop_runtimes)
    return 1
}

install_dotnet_runtime() {
    local channel
    if channel="$(get_required_dotnet_channel)"; then
        log_info "VRCOSC requires the .NET ${channel} Desktop Runtime (from VRCOSC.runtimeconfig.json)."
    else
        channel="$DEFAULT_DOTNET_CHANNEL"
        log_warn "Could not read the required runtime from VRCOSC.runtimeconfig.json; assuming .NET ${channel}."
    fi

    local installed_dotnet="$VRC_COMPATDATA/pfx/drive_c/Program Files/dotnet/dotnet.exe"
    if [ -f "$installed_dotnet" ] && has_desktop_runtime_channel "$channel" && [ "$FORCE_INSTALL" -ne 1 ]; then
        log_success ".NET ${channel} Desktop Runtime already present in prefix. Skipping download (use -f/--force to reinstall)."
        return 0
    fi

    if [ -f "$installed_dotnet" ] && ! has_desktop_runtime_channel "$channel"; then
        local present
        present="$(get_installed_desktop_runtimes | tr '\n' ' ')"
        log_warn "Prefix has .NET Desktop Runtime(s) [${present:-none}] but VRCOSC needs ${channel}.x -- installing it alongside."
    fi

    log_info "Fetching latest .NET ${channel} Desktop Runtime download URL..."
    local releases_json dotnet_url
    releases_json="$(curl -fsS --connect-timeout 10 \
        "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${channel}/releases.json" 2>&1 || true)"
    dotnet_url="$(grep -o 'https://[^"]*windowsdesktop-runtime-[0-9.]*-win-x64.exe' <<< "$releases_json" \
        | head -n 1 || true)"

    if [ -z "$dotnet_url" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log_warn "Dry run: could not reach the .NET release metadata; skipping runtime install."
            return 0
        fi
        log_error "Error: Failed to fetch the .NET ${channel} Desktop Runtime download URL."
        echo -e "${YELLOW}Check your network, and that channel ${channel} exists at${NC}"
        echo -e "  ${CYAN}https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${NC}"
        exit 1
    fi

    log_info "Downloading .NET ${channel} from: $dotnet_url"
    # Name the installer after its channel: self-describing if it is ever left
    # behind, and it lets tests assert which runtime was actually requested.
    local dotnet_installer="$VRC_COMPATDATA/pfx/drive_c/windowsdesktop-runtime-${channel}.exe"
    [ "$DRY_RUN" -eq 1 ] && return 0

    curl -L -o "$dotnet_installer" "$dotnet_url"

    log_info "Installing .NET ${channel} Desktop Runtime in VRChat prefix..."
    run_in_prefix "wine C:\\windowsdesktop-runtime-${channel}.exe /quiet /norestart"
    rm -f "$dotnet_installer"

    verify_dotnet_runtime "$channel"
}

# Fails loudly when the runtime VRCOSC needs is not actually in the prefix after
# installing. Silently proceeding here is what produced "installed fine but
# VRCOSC says there is no runtime" reports.
verify_dotnet_runtime() {
    local channel="$1"
    local installed
    installed="$(get_installed_desktop_runtimes | tr '\n' ' ')"

    if ! has_desktop_runtime_channel "$channel"; then
        log_error "Error: .NET ${channel} Desktop Runtime is missing from the prefix after installation."
        echo -e "  * Expected: ${CYAN}Microsoft.WindowsDesktop.App ${channel}.x${NC}"
        echo -e "  * Present:  ${YELLOW}${installed:-none}${NC}"
        echo -e "${YELLOW}The installer ran but wrote nothing usable. This is normally a broken wine${NC}"
        echo -e "${YELLOW}environment -- try re-running with ${CYAN}--runtime host${YELLOW} or ${CYAN}--runtime container${YELLOW}.${NC}"
        exit 1
    fi

    log_success ".NET Desktop Runtime verified in prefix: ${installed}"
}

install_vrcosc() {
    log_info "Fetching latest VRCOSC release version (channel: $VRCOSC_BRANCH)..."
    local latest_release_json nupkg_url
    latest_release_json="$(github_api https://api.github.com/repos/VolcanicArts/VRCOSC/releases/latest)"

    local pkg_pattern="live-full.nupkg"
    [ "$VRCOSC_BRANCH" = "beta" ] && pkg_pattern="beta-full.nupkg"

    nupkg_url="$(grep -o "https://github.com/VolcanicArts/VRCOSC/releases/download/[^\"]*${pkg_pattern}" \
        <<< "$latest_release_json" | head -n 1 || true)"

    # Fallback to any full nupkg if channel-specific filename differs
    if [ -z "$nupkg_url" ]; then
        nupkg_url="$(grep -o 'https://github.com/VolcanicArts/VRCOSC/releases/download/[^"]*-full.nupkg' \
            <<< "$latest_release_json" | head -n 1 || true)"
    fi

    if [ -z "$nupkg_url" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log_warn "Dry run: could not reach the GitHub releases API; skipping VRCOSC download."
            return 0
        fi
        log_error "Error: Failed to fetch the VRCOSC $VRCOSC_BRANCH package URL."
        if grep -qE 'error: 403|rate limit' <<< "$latest_release_json"; then
            echo -e "${YELLOW}GitHub is rate-limiting this address (60 requests/hour when unauthenticated).${NC}"
            echo -e "Wait an hour, or export a token first: ${CYAN}export GITHUB_TOKEN=\$(gh auth token)${NC}"
        else
            echo -e "${YELLOW}GitHub may be unreachable. Response was:${NC}"
            printf '%s\n' "$latest_release_json" | head -n 5 | sed 's/^/  /'
        fi
        exit 1
    fi

    # Do not clobber a newer local build. The maintainer routinely runs a build
    # ahead of the published release, and this function deletes the install
    # directory before unpacking, so an unconditional install is a downgrade.
    local remote_version local_version
    remote_version="$(get_version_from_asset_url "$nupkg_url")"
    local_version="$(get_vrcosc_version_from_dir "$(get_vrcosc_install_dir)")"

    if [ "$FORCE_INSTALL" -ne 1 ] && [ -n "$remote_version" ]; then
        case "$local_version" in
            "Not installed")
                : # nothing there yet
                ;;
            "Installed")
                log_warn "Installed VRCOSC has no readable version (no VRCOSC.deps.json); reinstalling $remote_version."
                ;;
            *)
                case "$(compare_versions "$local_version" "$remote_version")" in
                    same)
                        log_success "VRCOSC $local_version is already the latest $VRCOSC_BRANCH release. Skipping download (use -f/--force to reinstall)."
                        return 0
                        ;;
                    newer)
                        log_warn "Installed VRCOSC $local_version is newer than the latest $VRCOSC_BRANCH release ($remote_version); not downgrading."
                        echo -e "Use ${CYAN}-f/--force${NC} to install ${remote_version} over it anyway."
                        return 0
                        ;;
                esac
                ;;
        esac
    fi

    log_info "Downloading VRCOSC package from: $nupkg_url"
    local nupkg_file="/tmp/vrcosc-latest.nupkg"
    [ "$DRY_RUN" -eq 1 ] && return 0

    curl -L -o "$nupkg_file" "$nupkg_url"

    local vrcosc_dir="$(get_vrcosc_install_dir)"
    log_info "Installing VRCOSC to $vrcosc_dir..."
    mkdir -p "$vrcosc_dir"

    # Clean previous installation binaries
    rm -rf "${vrcosc_dir:?}"/*

    local temp_extract="/tmp/vrcosc-extract"
    rm -rf "$temp_extract"
    mkdir -p "$temp_extract"
    unzip -q "$nupkg_file" -d "$temp_extract"

    cp -r "$temp_extract/lib/app/"* "$vrcosc_dir/"
    rm -f "$nupkg_file"
    rm -rf "$temp_extract"
    log_success "VRCOSC files extracted successfully."
}

configure_firewall() {
    if [ "$SKIP_FIREWALL" -eq 1 ]; then
        log_info "Skipping firewall configuration (--skip-firewall)."
        return 0
    fi

    log_info "Checking firewall configuration for OSC and OSCQuery mDNS ports (9000/9001/5353 UDP)..."
    [ "$DRY_RUN" -eq 1 ] && return 0

    local applied=0
    if command -v firewall-cmd &>/dev/null && sudo -n true 2>/dev/null; then
        log_info "Applying firewalld rules..."
        sudo -n firewall-cmd --add-port=9000/udp --permanent 2>/dev/null || true
        sudo -n firewall-cmd --add-port=9001/udp --permanent 2>/dev/null || true
        sudo -n firewall-cmd --add-port=5353/udp --permanent 2>/dev/null || true
        sudo -n firewall-cmd --reload 2>/dev/null || true
        applied=1
    elif command -v ufw &>/dev/null && sudo -n true 2>/dev/null; then
        log_info "Applying UFW rules..."
        sudo -n ufw allow 9000/udp 2>/dev/null || true
        sudo -n ufw allow 9001/udp 2>/dev/null || true
        sudo -n ufw allow 5353/udp 2>/dev/null || true
        sudo -n ufw reload 2>/dev/null || true
        applied=1
    elif command -v iptables &>/dev/null && sudo -n true 2>/dev/null; then
        log_info "Applying iptables rules..."
        sudo -n iptables -I INPUT -p udp --dport 9000 -j ACCEPT 2>/dev/null || true
        sudo -n iptables -I INPUT -p udp --dport 9001 -j ACCEPT 2>/dev/null || true
        sudo -n iptables -I INPUT -p udp --dport 5353 -j ACCEPT 2>/dev/null || true
        applied=1
    fi

    if [ "$applied" -eq 0 ]; then
        log_warn "Note: Automatic firewall rules were skipped (root privileges required)."
        echo -e "If VRChat fails to auto-discover VRCOSC, manually allow UDP ports 9000, 9001, and 5353 in your firewall."
    else
        log_success "Firewall rules configured successfully."
    fi
}

install_application_icon() {
    log_info "Installing VRCOSC application icon..."
    [ "$DRY_RUN" -eq 1 ] && return 0

    local icon_path="$(get_app_icon_path)"
    mkdir -p "$(dirname "$icon_path")"
    curl -fsSL --connect-timeout 10 -o "$icon_path" "$ICON_URL" 2>/dev/null || {
        log_warn "Could not download the application icon; the desktop entry will use a fallback."
        rm -f "$icon_path"
        return 0
    }
    if [ -f "$icon_path" ]; then
        log_success "Application icon installed: $icon_path"
    fi
}

patch_vrchat_launch_bridge() {
    log_info "Checking VRChat launch.exe for Linux IPC named-pipe bridge patch..."
    [ "$DRY_RUN" -eq 1 ] && return 0

    local vrc_game_dir="$(get_vrchat_game_dir)"
    local target_launch="$vrc_game_dir/launch.exe"
    local backup_launch="$vrc_game_dir/launch.org.exe"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_bridge="$script_dir/bin/vrc-launch-bridge.exe"

    if [ ! -d "$vrc_game_dir" ]; then
        log_warn "VRChat game directory not found ($vrc_game_dir). Skipping launch.exe patch."
        return 0
    fi

    if [ ! -f "$source_bridge" ]; then
        log_warn "vrc-launch-bridge.exe not found at $source_bridge. Skipping patch."
        return 0
    fi

    # Backup original launch.exe if launch.org.exe does not exist
    if [ ! -f "$backup_launch" ]; then
        if [ -f "$target_launch" ]; then
            log_info "Creating read-only backup of original launch.exe -> launch.org.exe..."
            cp -p "$target_launch" "$backup_launch"
            chmod 444 "$backup_launch"
        fi
    fi

    # Compare checksum or size to see if already patched
    if [ -f "$target_launch" ] && cmp -s "$source_bridge" "$target_launch"; then
        log_success "VRChat launch.exe is already patched with the Linux IPC bridge."
        chmod 555 "$target_launch" 2>/dev/null || true
        return 0
    fi

    log_info "Installing Linux IPC launch.exe wrapper into VRChat directory..."
    # If target is read-only, remove write protection temporarily to replace
    rm -f "$target_launch" 2>/dev/null || chmod 755 "$target_launch" 2>/dev/null || true
    cp "$source_bridge" "$target_launch"
    chmod 555 "$target_launch"
    log_success "VRChat launch.exe patched successfully (read-only 555)."
}

create_launchers() {
    log_info "Creating launch script and desktop entry..."
    [ "$DRY_RUN" -eq 1 ] && return 0

    local launch_script="$(get_launcher_script)"
    local win_entry="C:/users/steamuser/AppData/Local/VRCOSC/VRCOSC.dll"
    local desktop_entry="$(get_desktop_file)"
    local app_name="VRCOSC"

    if [ "$VRCOSC_BRANCH" = "beta" ]; then
        win_entry="C:/users/steamuser/AppData/Local/VRCOSC-beta/VRCOSC.dll"
        app_name="VRCOSC (Beta)"
    fi

    mkdir -p "$(dirname "$launch_script")"
    local runtime_flags
    runtime_flags="$(runtime_mode_flags "${RESOLVED_RUNTIME_MODE:-no-bwrap}")"

    cat << EOF_LAUNCHER > "$launch_script"
#!/usr/bin/env bash
# VRCOSC Launcher for Linux/Proton -- generated by install.sh
set -euo pipefail

ENTRY="$win_entry"
DOTNET="C:/Program Files/dotnet/dotnet.exe"
COMPATDATA="$VRC_COMPATDATA"
PFX="\$COMPATDATA/pfx"

# --- Preferred path: join VRChat's own wine session ---------------------------
# Steam runs VRChat inside a user+mount namespace with its own wineserver. A
# VRCOSC started outside it lands in a separate wine session (or, if it does
# connect, dies in Velopack with "Access denied"), and can never see VRChat.exe,
# its named pipes or its windows. Entering the game's namespaces first puts
# VRCOSC in the same session. Set VRCOSC_JOIN=0 to skip this.
find_vrchat_pid() {
    local proc
    for proc in /proc/[0-9]*; do
        [ "\$(cat "\$proc/comm" 2>/dev/null)" = "VRChat.exe" ] || continue
        [ -r "\$proc/environ" ] || continue
        tr '\\0' '\\n' < "\$proc/environ" 2>/dev/null \\
            | grep -qxF -e "WINEPREFIX=\$PFX" -e "WINEPREFIX=\$PFX/" || continue
        tr '\\0' '\\n' < "\$proc/environ" 2>/dev/null | grep -q '^PRESSURE_VESSEL_RUNTIME=' || continue
        echo "\${proc#/proc/}"
        return 0
    done
    return 1
}

# Proton's wine for this prefix: config_info line 2 is <proton>/files/share/fonts/.
proton_wine() {
    local fonts
    fonts="\$(sed -n '2p' "\$COMPATDATA/config_info" 2>/dev/null)" || return 1
    fonts="\${fonts%/}"
    echo "\$(dirname "\$(dirname "\$fonts")")/bin/wine"
}

if [ "\${VRCOSC_JOIN:-1}" != "0" ] && command -v nsenter >/dev/null && vrc_pid="\$(find_vrchat_pid)"; then
    wine="\$(proton_wine)"
    if [ -n "\$wine" ] && [ -x "\$wine" ]; then
        envfile="\$(mktemp)"
        tr '\\0' '\\n' < "/proc/\$vrc_pid/environ" \\
            | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' \\
            | grep -vE '^(WINELOADERNOEXEC|WINEPRELOADRESERVE|WINEDEBUG|_|PWD|OLDPWD|SHLVL)=' \\
            | while IFS= read -r line; do printf 'export %s=%q\\n' "\${line%%=*}" "\${line#*=}"; done > "\$envfile"
        echo "VRCOSC: joining VRChat's wine session (pid \$vrc_pid)" >&2
        exec nsenter -t "\$vrc_pid" -U -m --preserve-credentials env -i bash -c \\
            'source "\$1"; rm -f "\$1"; export WINEDEBUG=-all; exec "\$2" "\$3" "\$4" "\${@:5}"' \\
            _ "\$envfile" "\$wine" "\$DOTNET" "\$ENTRY" "\$@"
    fi
    echo "VRCOSC: VRChat is running but its Proton wine was not found; falling back to protontricks." >&2
fi

# --- Fallback: own wine session via protontricks ------------------------------
# Used when VRChat is not running. VRCOSC works standalone here, but it will not
# see VRChat if the game is started afterwards -- start VRChat first for full
# integration, then VRCOSC.
if [ -z "\${vrc_pid:-}" ]; then
    echo "VRCOSC: VRChat is not running; starting VRCOSC in its own wine session." >&2
    echo "VRCOSC: for VRChat detection, start VRChat first, then VRCOSC." >&2
fi

# Drop Steam Runtime variables leaked in by the calling shell. With them set,
# wine mixes runtime libraries with host config files and fails with misleading
# errors such as 'Fontconfig error: "/etc/fonts/fonts.conf": out of memory'.
SCRUB=($(printf -- '-u %s ' "${CONTAMINATING_ENV_VARS[@]}"))
RUNTIME_FLAGS=(${runtime_flags})

exec env "\${SCRUB[@]}" protontricks "\${RUNTIME_FLAGS[@]}" \\
    -c "wine \\"\$DOTNET\\" \\"\$ENTRY\\" \$*" 438100
EOF_LAUNCHER
    chmod +x "$launch_script"

    mkdir -p "$(dirname "$desktop_entry")"
    cat << EOF_DESKTOP > "$desktop_entry"
[Desktop Entry]
Name=$app_name
Comment=OSC controller for VRChat
Exec=$launch_script
Icon=vrcosc
Terminal=false
Type=Application
Categories=Game;Utility;
StartupWMClass=VRCOSC
EOF_DESKTOP

    local vrcosc_dir="$(get_vrcosc_install_dir)"
    log_success "=== VRCOSC Setup Complete! ==="
    echo -e "You can launch VRCOSC from your application menu, or run '${BLUE}$(basename "$launch_script")${NC}' in the terminal."
    echo -e "\n${BLUE}VRCOSC Directory Paths:${NC}"
    echo -e "  * ${GREEN}Config Folder (Profiles & Settings):${NC}"
    echo -e "    $VRC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/VRCOSC"
    echo -e "  * ${GREEN}Executable Folder (App Files):${NC}"
    echo -e "    $vrcosc_dir"
}

uninstall_vrcosc() {
    log_warn "Starting VRCOSC uninstallation..."
    locate_vrchat_prefix

    local removed=0
    # Remove installation directories
    for dir in "$(get_vrcosc_install_dir live)" "$(get_vrcosc_install_dir beta)"; do
        if [ -d "$dir" ]; then
            log_info "Removing binaries: $dir"
            rm -rf "$dir"
            removed=1
        fi
    done

    # Remove launchers, shortcuts, and icon
    for f in $(get_all_installed_files); do
        if [ -f "$f" ]; then
            log_info "Removing file: $f"
            rm -f "$f"
            removed=1
        fi
    done

    if [ "$removed" -eq 1 ]; then
        log_success "VRCOSC successfully uninstalled."
        echo -e "${YELLOW}Note: Your configurations in AppData/Roaming/VRCOSC have been preserved.${NC}"
    else
        log_info "Nothing found to uninstall."
    fi
}

main() {
    parse_arguments "$@"

    if [ "$INFO_MODE" -eq 1 ]; then
        show_diagnostics
        exit 0
    fi

    if [ "$BACKUP_MODE" -eq 1 ]; then
        create_backup
        exit 0
    fi

    if [ "$UNINSTALL_MODE" -eq 1 ]; then
        uninstall_vrcosc
        exit 0
    fi

    echo -e "${BLUE}=== VRCOSC Bazzite/Linux Installer ===${NC}"
    check_dependencies
    locate_vrchat_prefix
    warn_if_prefix_busy
    configure_protontricks_permissions
    probe_runtime_mode
    apply_wpf_registry_fix
    install_vrcosc
    install_dotnet_runtime
    configure_firewall
    install_application_icon
    patch_vrchat_launch_bridge
    create_launchers
}

# Sourced by tests/ to exercise individual functions; run main() only when this
# script is executed directly.
if [ "${VRCOSC_INSTALL_SH_SOURCED:-0}" != "1" ]; then
    main "$@"
fi
