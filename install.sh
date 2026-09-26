#!/usr/bin/env bash
# Written in [Amber](https://amber-lang.com/)
# version: 0.6.0-alpha
[ "$EUID" -ne 0 ] && { { command -v sudo >/dev/null 2>&1 && __sudo=sudo; } || { command -v doas >/dev/null 2>&1 && __sudo=doas; }; }
if [ -n "$ZSH_VERSION" ]; then
    EXEC_SHELL="zsh"
    IFS='.' read -A EXEC_SHELL_VERSION <<< "$ZSH_VERSION"
elif [ -n "$KSH_VERSION" ]; then
    EXEC_SHELL="ksh"
    __exec_shell_version="${.sh.version##*/}"
    IFS='.' read -a EXEC_SHELL_VERSION <<< "${__exec_shell_version%% *}"
else
    EXEC_SHELL="bash"
    EXEC_SHELL_VERSION=("${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}")
fi
# Values that never change while the installer runs: colours, URLs, the
# installer's own version and the digest of the bridge it ships with.
# Visual styling. The escape bytes are produced by printf once at start-up, since
# Amber text literals do not interpret \e or \x1b themselves.
command_0="$(printf '\e[0;31m')"
__status=$?
__RED_0="${command_0}"
command_1="$(printf '\e[0;32m')"
__status=$?
__GREEN_1="${command_1}"
command_2="$(printf '\e[0;34m')"
__status=$?
__BLUE_2="${command_2}"
command_3="$(printf '\e[1;33m')"
__status=$?
__YELLOW_3="${command_3}"
command_4="$(printf '\e[0;36m')"
__status=$?
__CYAN_4="${command_4}"
command_5="$(printf '\e[1m')"
__status=$?
__BOLD_5="${command_5}"
command_6="$(printf '\e[0;0m')"
__status=$?
__NC_6="${command_6}"
# No Color
__DISCORD_INVITE_7="https://discord.gg/vrcosc-1000862183963496519"
__DISCORD_THREAD_8="https://discord.com/channels/1000862183963496519/1466540047149957374"
__DEFAULT_DOTNET_CHANNEL_9="10.0"
__ICON_URL_10="https://raw.githubusercontent.com/VolcanicArts/VRCOSC/main/Logo.png"
# This installer's own version, independent of the VRCOSC release it installs.
# Bump it when cutting a tag; --version and --info report it, and it is the first
# thing to ask for in a bug report.
__SCRIPT_VERSION_11="1.0.1"
# Where this script is published, for messages that tell people how to re-run it.
__INSTALL_URL_12="https://vrcosc-linux.github.io/install.sh"
# Where the launch bridge payload is fetched from when there is no local copy.
# The Pages domain first, since that is the short URL people install from; raw
# GitHub second, because Pages serves a build that can lag behind a push.
array_7=("https://vrcosc-linux.github.io/bin/vrc-launch-bridge.exe" "https://raw.githubusercontent.com/vrcosc-linux/vrcosc-linux.github.io/main/bin/vrc-launch-bridge.exe")
__LAUNCH_BRIDGE_URLS_13=("${array_7[@]}")
# sha256 of bin/vrc-launch-bridge.exe in this repo. The script and the payload are
# versioned together, so the expected digest can simply be written down here. It
# does two things an MZ check cannot: it tells a cached bridge from an older
# install apart from the current one, so piped installs stop keeping the first
# bridge they ever fetched forever, and it makes the raw.githubusercontent
# fallback meaningful when Pages is serving a build behind main.
# 
# Regenerate with: sha256sum bin/vrc-launch-bridge.exe
# The mutable copy the code actually consults lives in state.ab, so tests can
# point it at their own fake payload and exercise this code path rather than
# stubbing it out.
__SHIPPED_LAUNCH_BRIDGE_SHA256_14="7496e1f85b494970542055882df20ca2bbedde5cb54f3d2136c412e15d94484b"
# Variables a Steam-launched shell (or a half-initialised Steam Runtime) exports
# into our environment. Left in place they make wine load the runtime's pinned
# libraries while still reading the host's config files, which surfaces as
# misleading errors such as:
# Fontconfig error: "/etc/fonts/fonts.conf", line 86: out of memory
# fontconfig reports every config parse failure as "out of memory" -- there is no
# actual memory pressure, the library and the config file simply disagree.
array_8=("LD_LIBRARY_PATH" "LD_PRELOAD" "LD_AUDIT" "FONTCONFIG_PATH" "FONTCONFIG_FILE" "GTK_PATH" "GDK_PIXBUF_MODULE_FILE" "GIO_MODULE_DIR" "GST_PLUGIN_SYSTEM_PATH" "GST_PLUGIN_SYSTEM_PATH_1_0" "STEAM_RUNTIME" "STEAM_RUNTIME_LIBRARY_PATH" "SYSTEM_LD_LIBRARY_PATH" "PRESSURE_VESSEL_RUNTIME" "PRESSURE_VESSEL_RUNTIME_BASE" "PRESSURE_VESSEL_PREFIX" "WINEPREFIX" "WINEDLLPATH" "WINELOADER" "WINESERVER")
__CONTAMINATING_ENV_VARS_15=("${array_8[@]}")
# Runtime modes tried by "auto", in order. no-bwrap first so hosts that already
# work keep their behaviour; host next, since it is what fixes a Proton build
# protontricks cannot pair with a runtime; container last.
array_9=("no-bwrap" "host" "container")
__RUNTIME_MODE_CANDIDATES_16=("${array_9[@]}")
# The flatpak overrides this installer adds, each with the reason it is needed.
# They are listed in one place because uninstall has to be able to take them back
# off again, and because a sandbox escape is not something to grant silently.
array_10=("--filesystem=host" "--talk-name=org.mpris.MediaPlayer2.*" "--talk-name=org.freedesktop.Flatpak")
__PROTONTRICKS_OVERRIDES_17=("${array_10[@]}")
__PROTONTRICKS_FLATPAK_ID_18="com.github.Matoking.protontricks"
__VRCHAT_APP_ID_19="438100"
# The installer's run-time state: what the command line asked for and what was
# discovered along the way. Configured solely via command-line arguments in
# normal use; tests set these directly to exercise single functions.
__VRCOSC_BRANCH_23="live"
# live or beta
__FORCE_INSTALL_24=0
__UNINSTALL_MODE_25=0
__BACKUP_MODE_26=0
__INFO_MODE_27=0
__DRY_RUN_28=0
__NO_FIREWALL_29=0
__PATCH_LAUNCH_30=1
# patching VRChat's launch.exe; refuse it with --no-patch
__PURGE_MODE_31=0
# delete settings and profiles as well; see --purge
__VRC_COMPATDATA_32=""
__RUNTIME_MODE_33="auto"
# auto | no-bwrap | host | container
__RESOLVED_RUNTIME_MODE_34=""
# filled in by probe_runtime_mode()
# The digest a bridge payload must have to count as current. Starts as the
# shipped pin; tests point it at their own fake payload.
__LAUNCH_BRIDGE_SHA256_35="${__SHIPPED_LAUNCH_BRIDGE_SHA256_14}"
# The file this script was loaded from, or empty when there is no script file --
# which is the normal case for the documented `curl ... | bash` install, where
# nothing useful is in BASH_SOURCE and a naive dirname silently yields the
# caller's cwd. Recorded once at start-up; tests set it to simulate either case.
command_11="$(printf '%s' "${BASH_SOURCE[0]:-}")"
__status=$?
__SCRIPT_SOURCE_36="${command_11}"
# Coloured output, and the banner shown when the installer stops on an error.
# log_info(message: Text)
log_info__0_v0() {
    local message_2900="${1}"
    printf '%s\n' "${__BLUE_2}${message_2900}${__NC_6}"
}

# log_success(message: Text)
log_success__1_v0() {
    local message_3050="${1}"
    printf '%s\n' "${__GREEN_1}${message_3050}${__NC_6}"
}

# log_warn(message: Text)
log_warn__2_v0() {
    local message_2899="${1}"
    printf '%s\n' "${__YELLOW_3}${message_2899}${__NC_6}"
}

# log_error(message: Text)
log_error__3_v0() {
    local message_2896="${1}"
    printf '%s\n' "${__RED_0}${message_2896}${__NC_6}"
}

# Printed when a step fails in a way the installer did not plan for. The exit
# code is what a bug report needs first, along with --version.
# on_error(exit_code: Int)
on_error__4_v0() {
    local exit_code_3198="${1}"
    printf '%s\n' ""
    log_error__3_v0 "============================================================"
    log_error__3_v0 " Installation encountered an error (exit code ${exit_code_3198})"'!'""
    log_error__3_v0 "============================================================"
    printf '%s\n' "${__YELLOW_3}Need help or ran into an unexpected bug? Join the VRCOSC Discord:${__NC_6}"
    echo "  * Server Invite:  ${__CYAN_4}${__DISCORD_INVITE_7}${__NC_6}"
    echo "  * Linux Thread:   ${__CYAN_4}${__DISCORD_THREAD_8}${__NC_6}"
    printf '%s\n' ""
    exit "${exit_code_3198}"
}

# The command line: usage text and argument parsing.
# print_usage()
print_usage__8_v0() {
    printf '%s\n' "${__BOLD_5}VRCOSC Linux Installer & Manager${__NC_6} ${__CYAN_4}v${__SCRIPT_VERSION_11}${__NC_6}"
    printf '%s\n' ""
    printf '%s\n' "${__BOLD_5}Usage:${__NC_6}"
    echo "  bash install.sh [OPTIONS]"
    printf '%s\n' ""
    printf '%s\n' "${__BOLD_5}Options:${__NC_6}"
    echo "  -V, --version             Print this installer's version and exit"
    echo "  -i, --info                Display diagnostic system, prefix, runtime, and VRCOSC environment info"
    echo "  -b, --backup              Create a high-compression backup of VRCOSC configs & prefix registries to Desktop"
    echo "  -f, --force               Force re-download and re-installation of .NET and VRCOSC"
    echo "      --branch <live|beta>  Specify release channel to install (default: live)"
    echo "  -u, --uninstall           Uninstall VRCOSC binaries, launcher script, and desktop shortcut"
    echo "      --purge               Also delete VRCOSC's settings, profiles and logs for the"
    echo "                            selected --branch. Use with --uninstall to remove binaries"
    echo "                            too, or on its own to delete only settings. Installs"
    echo "                            nothing. Follows the config directory if it is a symlink."
    echo "      --dry-run             Simulate actions without writing files or running installers"
    echo "      --no-firewall         Inspect firewall rules but add none"
    echo "      --no-patch            Leave VRChat's launch.exe alone. The bridge is what makes"
    echo "                            vrchat:// navigation work from VRCOSC and companion tools;"
    echo "                            without it everything else still works."
    echo "      --prefix <PATH>       Explicitly specify the VRChat compatdata/438100 folder"
    echo "      --runtime <MODE>      Steam Runtime mode for wine calls (default: auto)"
    echo "                              auto       probe modes below and use the first clean one"
    echo "                              no-bwrap   Steam Runtime without bwrap containerisation"
    echo "                              host       no Steam Runtime; use host libraries only"
    echo "                              container  Steam Runtime with bwrap containerisation"
    echo "  -h, --help                Show this help message"
}

# The value following an option, or empty when there is none.
# value_after(args: [Text], index: Int)
value_after__9_v0() {
    local args_2893=("${!1}")
    local index_2894="${2}"
    local __length_12=("${args_2893[@]}")
    if [ "$(( $(( index_2894 + 1 )) < ${#__length_12[@]} ))" != 0 ]; then
        ret_value_after9_v0="${args_2893[$(( index_2894 + 1 ))]?"Index out of bounds (at src/cli.ab:40:21)"}"
        return 0
    fi
    ret_value_after9_v0=""
    return 0
}

# Reads the flags into the state module. Options that take a value consume the
# next argument.
# parse_arguments(args: [Text])
parse_arguments__10_v0() {
    local args_2890=("${!1}")
    local i_2891=0
    local __length_13=("${args_2890[@]}")
    while [ "$(( i_2891 < ${#__length_13[@]} ))" != 0 ]; do
        local arg_2892="${args_2890[${i_2891}]?"Index out of bounds (at src/cli.ab:50:26)"}"
        if [ "$(( $([ "_${arg_2892}" != "_-i" ]; echo $?) || $([ "_${arg_2892}" != "_--info" ]; echo $?) ))" != 0 ]; then
            __INFO_MODE_27=1
        elif [ "$(( $([ "_${arg_2892}" != "_-b" ]; echo $?) || $([ "_${arg_2892}" != "_--backup" ]; echo $?) ))" != 0 ]; then
            __BACKUP_MODE_26=1
        elif [ "$(( $([ "_${arg_2892}" != "_-f" ]; echo $?) || $([ "_${arg_2892}" != "_--force" ]; echo $?) ))" != 0 ]; then
            __FORCE_INSTALL_24=1
        elif [ "$(( $([ "_${arg_2892}" != "_-u" ]; echo $?) || $([ "_${arg_2892}" != "_--uninstall" ]; echo $?) ))" != 0 ]; then
            __UNINSTALL_MODE_25=1
        elif [ "$([ "_${arg_2892}" != "_--purge" ]; echo $?)" != 0 ]; then
            __PURGE_MODE_31=1
        elif [ "$([ "_${arg_2892}" != "_--branch" ]; echo $?)" != 0 ]; then
            value_after__9_v0 args_2890[@] "${i_2891}"
            local ret_value_after9_v0__68_31="${ret_value_after9_v0}"
            local value_2895="${ret_value_after9_v0__68_31}"
            if [ "$([ "_${value_2895}" != "_" ]; echo $?)" != 0 ]; then
                log_error__3_v0 "Error: --branch requires an argument (live or beta)."
                exit 1
            fi
            if [ "$(( $([ "_${value_2895}" == "_live" ]; echo $?) && $([ "_${value_2895}" == "_beta" ]; echo $?) ))" != 0 ]; then
                # Only "beta" was ever special-cased, so a typo installed
                # live under whatever name the user typed.
                log_error__3_v0 "Error: unknown branch '${value_2895}'. Use 'live' or 'beta'."
                exit 1
            fi
            __VRCOSC_BRANCH_23="${value_2895}"
            i_2891="$(( i_2891 + 1 ))"
        elif [ "$([ "_${arg_2892}" != "_--prefix" ]; echo $?)" != 0 ]; then
            value_after__9_v0 args_2890[@] "${i_2891}"
            local ret_value_after9_v0__83_31="${ret_value_after9_v0}"
            local value_2897="${ret_value_after9_v0__83_31}"
            if [ "$([ "_${value_2897}" != "_" ]; echo $?)" != 0 ]; then
                log_error__3_v0 "Error: --prefix requires a directory path."
                exit 1
            fi
            __VRC_COMPATDATA_32="${value_2897}"
            i_2891="$(( i_2891 + 1 ))"
        elif [ "$([ "_${arg_2892}" != "_--runtime" ]; echo $?)" != 0 ]; then
            value_after__9_v0 args_2890[@] "${i_2891}"
            local ret_value_after9_v0__92_31="${ret_value_after9_v0}"
            local value_2898="${ret_value_after9_v0__92_31}"
            if [ "$(( $(( $(( $([ "_${value_2898}" == "_auto" ]; echo $?) && $([ "_${value_2898}" == "_no-bwrap" ]; echo $?) )) && $([ "_${value_2898}" == "_host" ]; echo $?) )) && $([ "_${value_2898}" == "_container" ]; echo $?) ))" != 0 ]; then
                log_error__3_v0 "Error: --runtime requires one of: auto, no-bwrap, host, container."
                exit 1
            fi
            __RUNTIME_MODE_33="${value_2898}"
            i_2891="$(( i_2891 + 1 ))"
        elif [ "$([ "_${arg_2892}" != "_--dry-run" ]; echo $?)" != 0 ]; then
            __DRY_RUN_28=1
        elif [ "$(( $([ "_${arg_2892}" != "_--no-firewall" ]; echo $?) || $([ "_${arg_2892}" != "_--skip-firewall" ]; echo $?) ))" != 0 ]; then
            __NO_FIREWALL_29=1
        elif [ "$([ "_${arg_2892}" != "_--no-patch" ]; echo $?)" != 0 ]; then
            __PATCH_LAUNCH_30=0
        elif [ "$(( $([ "_${arg_2892}" != "_--patch" ]; echo $?) || $([ "_${arg_2892}" != "_--path" ]; echo $?) ))" != 0 ]; then
            # Accepted because it was briefly the documented spelling; patching is
            # the default now, so this only states it explicitly.
            __PATCH_LAUNCH_30=1
        elif [ "$(( $([ "_${arg_2892}" != "_-V" ]; echo $?) || $([ "_${arg_2892}" != "_--version" ]; echo $?) ))" != 0 ]; then
            echo "vrcosc-linux install.sh ${__SCRIPT_VERSION_11}"
            exit 0
        elif [ "$(( $([ "_${arg_2892}" != "_-h" ]; echo $?) || $([ "_${arg_2892}" != "_--help" ]; echo $?) ))" != 0 ]; then
            print_usage__8_v0 
            exit 0
        else
            log_warn__2_v0 "Unknown argument: ${arg_2892}"
            print_usage__8_v0 
            exit 1
        fi
        i_2891="$(( i_2891 + 1 ))"
    done
}

# Small shell helpers the rest of the installer is written in terms of.
# The current user's home directory.
# home()
home__15_v0() {
    local command_14
    command_14="$(printf '%s' "$HOME")"
    __status=$?
    ret_home15_v0="${command_14}"
    return 0
}

# An environment variable's value, or the fallback when it is unset or empty.
# env_or(name: Text, fallback: Text)
env_or__16_v0() {
    local name_2905="${1}"
    local fallback_2906="${2}"
    local command_15
    command_15="$(printf '%s' "${!name_2905:-${fallback_2906}}")"
    __status=$?
    ret_env_or16_v0="${command_15}"
    return 0
}

# True when the variable is set to a non-empty value.
# env_is_set(name: Text)
env_is_set__17_v0() {
    local name_2976="${1}"
    env_or__16_v0 "${name_2976}" ""
    local ret_env_or16_v0__15_12="${ret_env_or16_v0}"
    ret_env_is_set17_v0="$([ "_${ret_env_or16_v0__15_12}" == "_" ]; echo $?)"
    return 0
}

# True when a command is on PATH.
# have_cmd(name: Text)
have_cmd__18_v0() {
    local name_2911="${1}"
    command -v "${name_2911}">/dev/null 2>&1
    __status=$?
    ret_have_cmd18_v0="$(( __status == 0 ))"
    return 0
}

# Every path matching a shell glob, one per element; empty when nothing matches.
# glob(pattern: Text)
glob__19_v0() {
    local pattern_2958="${1}"
    local array_16=()
    local matches_2959=("${array_16[@]}")
    mapfile -t matches_2959 < <(compgen -G "${pattern_2958}" 2>/dev/null)
    __status=$?
    ret_glob19_v0=("${matches_2959[@]}")
    return 0
}

# The lines of a text, keeping empty ones. std/text's split_lines collapses
# consecutive newlines, which loses information when the text is a file listing.
# lines_of(text: Text)
lines_of__20_v0() {
    local text_2931="${1}"
    local array_17=()
    local out_2932=("${array_17[@]}")
    if [ "$([ "_${text_2931}" != "_" ]; echo $?)" != 0 ]; then
        ret_lines_of20_v0=("${out_2932[@]}")
        return 0
    fi
    mapfile -t out_2932 <<< "${text_2931}"
    __status=$?
    ret_lines_of20_v0=("${out_2932[@]}")
    return 0
}

# The non-empty lines of a text.
# nonempty_lines(text: Text)
nonempty_lines__21_v0() {
    local text_2929="${1}"
    local array_18=()
    local out_2930=("${array_18[@]}")
    lines_of__20_v0 "${text_2929}"
    local ret_lines_of20_v0__45_17=("${ret_lines_of20_v0[@]}")
    for line_2933 in "${ret_lines_of20_v0__45_17[@]}"; do
        if [ "$([ "_${line_2933}" == "_" ]; echo $?)" != 0 ]; then
            local array_21=("${line_2933}")
            out_2930+=("${array_21[@]}")
        fi
    done
    ret_nonempty_lines21_v0=("${out_2930[@]}")
    return 0
}

# path_exists(path: Text)
path_exists__22_v0() {
    local path_3065="${1}"
    [ -e "${path_3065}" ]
    __status=$?
    ret_path_exists22_v0="$(( __status == 0 ))"
    return 0
}

# file_exists(path: Text)
file_exists__23_v0() {
    local path_2902="${1}"
    [ -f "${path_2902}" ]
    __status=$?
    ret_file_exists23_v0="$(( __status == 0 ))"
    return 0
}

# dir_exists(path: Text)
dir_exists__24_v0() {
    local path_2923="${1}"
    [ -d "${path_2923}" ]
    __status=$?
    ret_dir_exists24_v0="$(( __status == 0 ))"
    return 0
}

# is_symlink(path: Text)
is_symlink__25_v0() {
    local path_3018="${1}"
    [ -L "${path_3018}" ]
    __status=$?
    ret_is_symlink25_v0="$(( __status == 0 ))"
    return 0
}

# is_readable(path: Text)
is_readable__26_v0() {
    local path_3103="${1}"
    [ -r "${path_3103}" ]
    __status=$?
    ret_is_readable26_v0="$(( __status == 0 ))"
    return 0
}

# dirname(path: Text)
dirname__27_v0() {
    local path_2943="${1}"
    local command_22
    command_22="$(dirname "${path_2943}")"
    __status=$?
    ret_dirname27_v0="${command_22}"
    return 0
}

# basename(path: Text)
basename__28_v0() {
    local path_2961="${1}"
    local command_23
    command_23="$(basename "${path_2961}")"
    __status=$?
    ret_basename28_v0="${command_23}"
    return 0
}

# A file's contents; empty when it cannot be read.
# read_file(path: Text)
read_file__29_v0() {
    local path_2998="${1}"
    local command_24
    command_24="$(cat "${path_2998}" 2>/dev/null)"
    __status=$?
    ret_read_file29_v0="${command_24}"
    return 0
}

# The first line of a file, or empty.
# first_line(path: Text)
first_line__30_v0() {
    local path_2937="${1}"
    local command_25
    command_25="$(head -n 1 "${path_2937}" 2>/dev/null)"
    __status=$?
    ret_first_line30_v0="${command_25}"
    return 0
}

# The first n bytes of a file.
# head_bytes(path: Text, count: Int)
head_bytes__31_v0() {
    local path_3042="${1}"
    local count_3043="${2}"
    local command_26
    command_26="$(head -c ${count_3043} "${path_3042}" 2>/dev/null)"
    __status=$?
    ret_head_bytes31_v0="${command_26}"
    return 0
}

# mkdir_p(path: Text)
mkdir_p__32_v0() {
    local path_3044="${1}"
    mkdir -p "${path_3044}">/dev/null 2>&1
    __status=$?
    ret_mkdir_p32_v0="$(( __status == 0 ))"
    return 0
}

# True when stdin is a terminal, i.e. someone is there to answer a prompt.
# stdin_is_tty()
stdin_is_tty__33_v0() {
    [ -t 0 ]
    __status=$?
    ret_stdin_is_tty33_v0="$(( __status == 0 ))"
    return 0
}

# Writes a line to stderr.
# True when the text contains the search string, as a plain substring.
# contains(haystack: Text, needle: Text)
contains__35_v0() {
    local haystack_3053="${1}"
    local needle_3054="${2}"
    [[ "${haystack_3053}" == *"${needle_3054}"* ]]
    __status=$?
    ret_contains35_v0="$(( __status == 0 ))"
    return 0
}

# True when the text matches an extended regular expression.
# matches(text: Text, regex: Text)
matches__36_v0() {
    local text_3002="${1}"
    local regex_3003="${2}"
    grep -qE "${regex_3003}" <<< "${text_3002}"
    __status=$?
    ret_matches36_v0="$(( __status == 0 ))"
    return 0
}

# The first match of an extended regular expression in the text, or empty.
# first_match(text: Text, regex: Text)
first_match__37_v0() {
    local text_3004="${1}"
    local regex_3005="${2}"
    local command_27
    command_27="$(grep -oE "${regex_3005}" <<< "${text_3004}" | head -n 1)"
    __status=$?
    ret_first_match37_v0="${command_27}"
    return 0
}

# Text with the given trailing suffix removed once, if present.
# strip_suffix(text: Text, suffix: Text)
strip_suffix__38_v0() {
    local text_2941="${1}"
    local suffix_2942="${2}"
    local command_28
    command_28="$(printf '%s' "${text_2941%"${suffix_2942}"}")"
    __status=$?
    ret_strip_suffix38_v0="${command_28}"
    return 0
}

# Text with the given leading prefix removed once, if present.
# strip_prefix(text: Text, prefix: Text)
strip_prefix__39_v0() {
    local text_2921="${1}"
    local prefix_2922="${2}"
    local command_29
    command_29="$(printf '%s' "${text_2921#"${prefix_2922}"}")"
    __status=$?
    ret_strip_prefix39_v0="${command_29}"
    return 0
}

# Joins the elements with a single space.
# join_words(items: [Text])
join_words__40_v0() {
    local items_2963=("${!1}")
    local command_30
    command_30="$(printf '%s' "${items_2963[*]}")"
    __status=$?
    ret_join_words40_v0="${command_30}"
    return 0
}

# Required tools, and how to install a missing one on the system in front of us.
# Which package manager this system uses. Checked in order of specificity: an
# image-based system has rpm-ostree *and* dnf, and installing with dnf there
# either fails or writes to a layer that the next update discards.
# detect_package_manager()
detect_package_manager__45_v0() {
    env_or__16_v0 "OS_RELEASE_FILE" "/etc/os-release"
    local ret_env_or16_v0__10_24="${ret_env_or16_v0}"
    local os_release_3102="${ret_env_or16_v0__10_24}"
    is_readable__26_v0 "${os_release_3102}"
    local ret_is_readable26_v0__11_8="${ret_is_readable26_v0}"
    if [ "${ret_is_readable26_v0__11_8}" != 0 ]; then
        grep -qE '^ID=steamos' "${os_release_3102}">/dev/null 2>&1
        __status=$?
        if [ "$(( __status == 0 ))" != 0 ]; then
            ret_detect_package_manager45_v0="steamos"
            return 0
        fi
    fi
    have_cmd__18_v0 "rpm-ostree"
    local ret_have_cmd18_v0__18_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "apt-get"
    local ret_have_cmd18_v0__19_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "dnf"
    local ret_have_cmd18_v0__20_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "pacman"
    local ret_have_cmd18_v0__21_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "zypper"
    local ret_have_cmd18_v0__22_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "apk"
    local ret_have_cmd18_v0__23_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "xbps-install"
    local ret_have_cmd18_v0__24_9="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__18_9}" != 0 ]; then
        ret_detect_package_manager45_v0="rpm-ostree"
        return 0
    elif [ "${ret_have_cmd18_v0__19_9}" != 0 ]; then
        ret_detect_package_manager45_v0="apt"
        return 0
    elif [ "${ret_have_cmd18_v0__20_9}" != 0 ]; then
        ret_detect_package_manager45_v0="dnf"
        return 0
    elif [ "${ret_have_cmd18_v0__21_9}" != 0 ]; then
        ret_detect_package_manager45_v0="pacman"
        return 0
    elif [ "${ret_have_cmd18_v0__22_9}" != 0 ]; then
        ret_detect_package_manager45_v0="zypper"
        return 0
    elif [ "${ret_have_cmd18_v0__23_9}" != 0 ]; then
        ret_detect_package_manager45_v0="apk"
        return 0
    elif [ "${ret_have_cmd18_v0__24_9}" != 0 ]; then
        ret_detect_package_manager45_v0="xbps"
        return 0
    fi
    ret_detect_package_manager45_v0="unknown"
    return 0
}

# The package that provides a command. nsenter is the only one whose package name
# differs from the command: it ships in util-linux, which is why it is present on
# essentially every system without anyone installing it.
# package_for(command: Text)
package_for__46_v0() {
    local command_3100="${1}"
    if [ "$([ "_${command_3100}" != "_nsenter" ]; echo $?)" != 0 ]; then
        ret_package_for46_v0="util-linux"
        return 0
    fi
    ret_package_for46_v0="${command_3100}"
    return 0
}

# Print the exact command for this system. protontricks is deliberately not in the
# distro list: most repositories either do not carry it or carry a version too old
# to know about modern Proton, and its own project recommends Flatpak or pipx.
# print_install_hint(commands: [Text])
print_install_hint__47_v0() {
    local commands_3096=("${!1}")
    local array_31=()
    local pkgs_3097=("${array_31[@]}")
    local needs_protontricks_3098=0
    for command_3099 in "${commands_3096[@]}"; do
        if [ "$([ "_${command_3099}" != "_protontricks" ]; echo $?)" != 0 ]; then
            needs_protontricks_3098=1
        else
            package_for__46_v0 "${command_3099}"
            local ret_package_for46_v0__49_22="${ret_package_for46_v0}"
            local array_34=("${ret_package_for46_v0__49_22}")
            pkgs_3097+=("${array_34[@]}")
        fi
    done
    local __length_35=("${pkgs_3097[@]}")
    if [ "$(( ${#__length_35[@]} > 0 ))" != 0 ]; then
        join_words__40_v0 pkgs_3097[@]
        local ret_join_words40_v0__54_22="${ret_join_words40_v0}"
        local list_3101="${ret_join_words40_v0__54_22}"
        printf '%s\n' "${__YELLOW_3}Install the missing packages with:${__NC_6}"
        detect_package_manager__45_v0 
        local ret_detect_package_manager45_v0__56_25="${ret_detect_package_manager45_v0}"
        local manager_3104="${ret_detect_package_manager45_v0__56_25}"
        if [ "$([ "_${manager_3104}" != "_apt" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo apt-get install -y ${list_3101}${__NC_6}"
        elif [ "$([ "_${manager_3104}" != "_dnf" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo dnf install -y ${list_3101}${__NC_6}"
        elif [ "$([ "_${manager_3104}" != "_pacman" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo pacman -S --needed ${list_3101}${__NC_6}"
        elif [ "$([ "_${manager_3104}" != "_zypper" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo zypper install -y ${list_3101}${__NC_6}"
        elif [ "$([ "_${manager_3104}" != "_apk" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo apk add ${list_3101}${__NC_6}"
        elif [ "$([ "_${manager_3104}" != "_xbps" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo xbps-install -S ${list_3101}${__NC_6}"
        elif [ "$([ "_${manager_3104}" != "_rpm-ostree" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}rpm-ostree install ${list_3101}${__NC_6}  (image-based system: takes effect after a reboot)"
        elif [ "$([ "_${manager_3104}" != "_steamos" ]; echo $?)" != 0 ]; then
            echo "  ${__CYAN_4}sudo steamos-readonly disable && sudo pacman -S --needed ${list_3101}${__NC_6}"
            echo "  ${__YELLOW_3}SteamOS resets its root filesystem on update, so this may need repeating.${__NC_6}"
        else
            echo "  ${__CYAN_4}${list_3101}${__NC_6} — install these with your distribution's package manager."
        fi
    fi
    if [ "${needs_protontricks_3098}" != 0 ]; then
        printf '%s\n' "${__YELLOW_3}Install protontricks with either:${__NC_6}"
        echo "  ${__CYAN_4}flatpak install -y flathub com.github.Matoking.protontricks${__NC_6}"
        echo "  ${__CYAN_4}pipx install protontricks${__NC_6}"
        echo "  Bazzite and SteamOS ship it already; on SteamOS prefer the Flatpak."
    fi
}

# check_dependencies()
check_dependencies__48_v0() {
    log_info__0_v0 "Verifying dependencies..."
    local array_36=()
    local missing_3094=("${array_36[@]}")
    local array_39=("protontricks" "curl" "unzip")
    for command_3095 in "${array_39[@]}"; do
        have_cmd__18_v0 "${command_3095}"
        local ret_have_cmd18_v0__85_16="${ret_have_cmd18_v0}"
        if [ "$(( ! ret_have_cmd18_v0__85_16 ))" != 0 ]; then
            local array_40=("${command_3095}")
            missing_3094+=("${array_40[@]}")
        fi
    done
    local __length_41=("${missing_3094[@]}")
    if [ "$(( ${#__length_41[@]} > 0 ))" != 0 ]; then
        join_words__40_v0 missing_3094[@]
        local ret_join_words40_v0__91_77="${ret_join_words40_v0}"
        log_error__3_v0 "Error: The following required dependencies are missing: ${ret_join_words40_v0__91_77}"
        print_install_hint__47_v0 missing_3094[@]
        exit 1
    fi
    have_cmd__18_v0 "nsenter"
    local ret_have_cmd18_v0__96_12="${ret_have_cmd18_v0}"
    if [ "$(( ! ret_have_cmd18_v0__96_12 ))" != 0 ]; then
        log_warn__2_v0 "nsenter (util-linux) not found: VRCOSC will run in its own wine session and will not see VRChat."
        local array_42=("nsenter")
        print_install_hint__47_v0 array_42[@]
    fi
}

# replace_one(source: Text, search: Text, replace: Text)
replace_one__62_v0() {
    local source_3081="${1}"
    local search_3082="${2}"
    local replace_3083="${3}"
    # Here we use a command to avoid #646
    local result_3084=""
    left_comp=("${EXEC_SHELL_VERSION[@]}")
    local array_43=(4 3)
    right_comp=("${array_43[@]}")
    local comp
    comp="$(
        # Compare if left array >= right array
        len_comp="$( (( "${#left_comp[@]}" < "${#right_comp[@]}" )) && echo "${#left_comp[@]}"|| echo "${#right_comp[@]}")"
        for (( i=0; i<len_comp; i++ )); do
            left="${left_comp[i]?"Index out of bounds (at unknown)"}"
            right="${right_comp[i]?"Index out of bounds (at unknown)"}"
            if (( "${left}" > "${right}" )); then
                echo 1
                exit
            elif (( "${left}" < "${right}" )); then
                echo 0
                exit
            fi
        done
        (( "${#left_comp[@]}" == "${#right_comp[@]}" || "${#left_comp[@]}" > "${#right_comp[@]}" )) && echo 1 || echo 0
)"
    if [ "$(( $([ "_${EXEC_SHELL}" != "_ksh" ]; echo $?) || $(( $([ "_${EXEC_SHELL}" != "_bash" ]; echo $?) && comp )) ))" != 0 ]; then
        result_3084="${source_3081/"${search_3082}"/"${replace_3083}"}"
        __status=$?
    else
        result_3084="${source_3081/"${search_3082}"/${replace_3083}}"
        __status=$?
    fi
    ret_replace_one62_v0="${result_3084}"
    return 0
}

__SED_VERSION_UNKNOWN_73=0
__SED_VERSION_GNU_74=1
__SED_VERSION_BUSYBOX_75=2
# starts_with(text: Text, prefix: Text)
starts_with__83_v0() {
    local text_2919="${1}"
    local prefix_2920="${2}"
    [[ "${text_2919}" == "${prefix_2920}"* ]]
    __status=$?
    ret_starts_with83_v0="$(( __status == 0 ))"
    return 0
}

# ends_with(text: Text, suffix: Text)
ends_with__84_v0() {
    local text_3127="${1}"
    local suffix_3128="${2}"
    [[ "${text_3127}" == *"${suffix_3128}" ]]
    __status=$?
    ret_ends_with84_v0="$(( __status == 0 ))"
    return 0
}

# input_prompt(prompt: Text)
input_prompt__185_v0() {
    local prompt_3051="${1}"
    if [ "$([ "_${EXEC_SHELL}" != "_bash" ]; echo $?)" != 0 ]; then
        read -p "$prompt_3051" || read -p "$prompt_3051" < /dev/tty
        __status=$?
    elif [ "$([ "_${EXEC_SHELL}" != "_zsh" ]; echo $?)" != 0 ]; then
        read "?${prompt_3051}" || read "?${prompt_3051}" < /dev/tty
        __status=$?
    elif [ "$([ "_${EXEC_SHELL}" != "_ksh" ]; echo $?)" != 0 ]; then
        read REPLY?"${prompt_3051}"
        __status=$?
    fi
    local command_44
    command_44="$(printf '%s
' $REPLY)"
    __status=$?
    ret_input_prompt185_v0="${command_44}"
    return 0
}

# Finding the VRChat (438100) Proton prefix.
# "~/..." with the tilde expanded, as a shell would have done for an unquoted path.
# expand_tilde(path: Text)
expand_tilde__220_v0() {
    local path_2918="${1}"
    starts_with__83_v0 "${path_2918}" "~"
    local ret_starts_with83_v0__11_8="${ret_starts_with83_v0}"
    if [ "${ret_starts_with83_v0__11_8}" != 0 ]; then
        home__15_v0 
        local ret_home15_v0__12_16="${ret_home15_v0}"
        strip_prefix__39_v0 "${path_2918}" "~"
        local ret_strip_prefix39_v0__12_25="${ret_strip_prefix39_v0}"
        ret_expand_tilde220_v0="${ret_home15_v0__12_16}""${ret_strip_prefix39_v0__12_25}"
        return 0
    fi
    ret_expand_tilde220_v0="${path_2918}"
    return 0
}

# Every library path a libraryfolders.vdf names.
# library_paths_from(vdf: Text)
library_paths_from__221_v0() {
    local vdf_2927="${1}"
    file_exists__23_v0 "${vdf_2927}"
    local ret_file_exists23_v0__19_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__19_12 ))" != 0 ]; then
        local array_45=()
        ret_library_paths_from221_v0=("${array_45[@]}")
        return 0
    fi
    local command_46
    command_46="$(grep -oE '"path"[[:space:]]*"[^"]+"' "${vdf_2927}" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')"
    __status=$?
    local found_2928="${command_46}"
    nonempty_lines__21_v0 "${found_2928}"
    local ret_nonempty_lines21_v0__23_12=("${ret_nonempty_lines21_v0[@]}")
    ret_library_paths_from221_v0=("${ret_nonempty_lines21_v0__23_12[@]}")
    return 0
}

# find_prefix_silently()
find_prefix_silently__222_v0() {
    if [ "$([ "_${__VRC_COMPATDATA_32}" == "_" ]; echo $?)" != 0 ]; then
        expand_tilde__220_v0 "${__VRC_COMPATDATA_32}"
        local ret_expand_tilde220_v0__28_26="${ret_expand_tilde220_v0}"
        __VRC_COMPATDATA_32="${ret_expand_tilde220_v0__28_26}"
        dir_exists__24_v0 "${__VRC_COMPATDATA_32}/pfx"
        local ret_dir_exists24_v0__29_12="${ret_dir_exists24_v0}"
        if [ "${ret_dir_exists24_v0__29_12}" != 0 ]; then
            ret_find_prefix_silently222_v0=1
            return 0
        fi
        dir_exists__24_v0 "${__VRC_COMPATDATA_32}/compatdata/${__VRCHAT_APP_ID_19}/pfx"
        local ret_dir_exists24_v0__32_12="${ret_dir_exists24_v0}"
        if [ "${ret_dir_exists24_v0__32_12}" != 0 ]; then
            __VRC_COMPATDATA_32="${__VRC_COMPATDATA_32}/compatdata/${__VRCHAT_APP_ID_19}"
            ret_find_prefix_silently222_v0=1
            return 0
        fi
    fi
    home__15_v0 
    local ret_home15_v0__38_15="${ret_home15_v0}"
    local h_2924="${ret_home15_v0__38_15}"
    local array_47=("${h_2924}/.local/share/Steam" "${h_2924}/.steam/steam" "${h_2924}/.var/app/com.valvesoftware.Steam/.local/share/Steam" "${h_2924}/.var/app/com.valvesoftware.Steam/.steam/steam" "/run/media/system/Data/Games/Steam" "/media/media-automount/Data/Games/Steam")
    local candidate_paths_2925=("${array_47[@]}")
    local array_50=("${h_2924}/.local/share/Steam/steamapps/libraryfolders.vdf" "${h_2924}/.steam/steam/steamapps/libraryfolders.vdf" "${h_2924}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf")
    for vdf_2926 in "${array_50[@]}"; do
        library_paths_from__221_v0 "${vdf_2926}"
        local ret_library_paths_from221_v0__53_28=("${ret_library_paths_from221_v0[@]}")
        candidate_paths_2925+=("${ret_library_paths_from221_v0__53_28[@]}")
    done
    for p_2934 in "${candidate_paths_2925[@]}"; do
        local array_55=("${p_2934}" "${p_2934}/steamapps")
        for check_dir_2935 in "${array_55[@]}"; do
            dir_exists__24_v0 "${check_dir_2935}/compatdata/${__VRCHAT_APP_ID_19}/pfx"
            local ret_dir_exists24_v0__58_16="${ret_dir_exists24_v0}"
            if [ "${ret_dir_exists24_v0__58_16}" != 0 ]; then
                __VRC_COMPATDATA_32="${check_dir_2935}/compatdata/${__VRCHAT_APP_ID_19}"
                ret_find_prefix_silently222_v0=1
                return 0
            fi
        done
    done
    ret_find_prefix_silently222_v0=0
    return 0
}

# locate_vrchat_prefix()
locate_vrchat_prefix__223_v0() {
    log_info__0_v0 "Locating VRChat Proton prefix..."
    find_prefix_silently__222_v0 
    local ret_find_prefix_silently222_v0__70_8="${ret_find_prefix_silently222_v0}"
    if [ "${ret_find_prefix_silently222_v0__70_8}" != 0 ]; then
        log_success__1_v0 "Found VRChat compatibility data at: ${__VRC_COMPATDATA_32}"
        ret_locate_vrchat_prefix223_v0=''
        return 0
    fi
    # Fallback to interactive user input if available
    log_warn__2_v0 "Could not automatically locate the VRChat (${__VRCHAT_APP_ID_19}) Proton prefix."
    stdin_is_tty__33_v0 
    local ret_stdin_is_tty33_v0__77_8="${ret_stdin_is_tty33_v0}"
    if [ "${ret_stdin_is_tty33_v0__77_8}" != 0 ]; then
        while [ "$([ "_${__VRC_COMPATDATA_32}" != "_" ]; echo $?)" != 0 ]; do
            log_info__0_v0 "Please enter the path to your SteamLibrary or the ${__VRCHAT_APP_ID_19} compatdata folder:"
            input_prompt__185_v0 "Path: "
            local ret_input_prompt185_v0__80_44="${ret_input_prompt185_v0}"
            expand_tilde__220_v0 "${ret_input_prompt185_v0__80_44}"
            local ret_expand_tilde220_v0__80_31="${ret_expand_tilde220_v0}"
            local user_path_3052="${ret_expand_tilde220_v0__80_31}"
            dir_exists__24_v0 "${user_path_3052}/pfx"
            local ret_dir_exists24_v0__83_17="${ret_dir_exists24_v0}"
            contains__35_v0 "${user_path_3052}" "${__VRCHAT_APP_ID_19}"
            local ret_contains35_v0__83_51="${ret_contains35_v0}"
            dir_exists__24_v0 "${user_path_3052}/compatdata/${__VRCHAT_APP_ID_19}/pfx"
            local ret_dir_exists24_v0__86_17="${ret_dir_exists24_v0}"
            dir_exists__24_v0 "${user_path_3052}/steamapps/compatdata/${__VRCHAT_APP_ID_19}/pfx"
            local ret_dir_exists24_v0__89_17="${ret_dir_exists24_v0}"
            if [ "$(( ret_dir_exists24_v0__83_17 && ret_contains35_v0__83_51 ))" != 0 ]; then
                __VRC_COMPATDATA_32="${user_path_3052}"
            elif [ "${ret_dir_exists24_v0__86_17}" != 0 ]; then
                __VRC_COMPATDATA_32="${user_path_3052}/compatdata/${__VRCHAT_APP_ID_19}"
            elif [ "${ret_dir_exists24_v0__89_17}" != 0 ]; then
                __VRC_COMPATDATA_32="${user_path_3052}/steamapps/compatdata/${__VRCHAT_APP_ID_19}"
            else
                log_error__3_v0 "Invalid path. Could not find 'pfx' folder for app ${__VRCHAT_APP_ID_19} under '${user_path_3052}'. Please try again."
            fi
        done
        log_success__1_v0 "Using VRChat prefix at: ${__VRC_COMPATDATA_32}"
    else
        # A piped install has no TTY, so the prompt above never appears. Say how to
        # pass the flag through a pipe, where bare flags would go to bash instead.
        log_error__3_v0 "Error: Running non-interactively and prefix was not found."
        echo "Pass --prefix <PATH> explicitly:"
        echo "  curl -sSL ${__INSTALL_URL_12} | bash -s -- --prefix /path/to/compatdata/${__VRCHAT_APP_ID_19}"
        exit 1
    fi
}

# Proton / Steam Runtime environment hygiene: which protontricks flags to use,
# scrubbing leaked runtime variables, and what is currently holding the prefix.
# The names of contaminating variables that are currently set.
# list_contaminated_env()
list_contaminated_env__239_v0() {
    local array_56=()
    local leaked_2974=("${array_56[@]}")
    for v_2975 in "${__CONTAMINATING_ENV_VARS_15[@]}"; do
        env_is_set__17_v0 "${v_2975}"
        local ret_env_is_set17_v0__12_12="${ret_env_is_set17_v0}"
        if [ "${ret_env_is_set17_v0__12_12}" != 0 ]; then
            local array_59=("${v_2975}")
            leaked_2974+=("${array_59[@]}")
        fi
    done
    ret_list_contaminated_env239_v0=("${leaked_2974[@]}")
    return 0
}

# Maps a runtime mode onto the protontricks flags that implement it.
# runtime_mode_flags(mode: Text)
runtime_mode_flags__240_v0() {
    local mode_2992="${1}"
    if [ "$([ "_${mode_2992}" != "_no-bwrap" ]; echo $?)" != 0 ]; then
        ret_runtime_mode_flags240_v0="--no-bwrap"
        return 0
    elif [ "$([ "_${mode_2992}" != "_host" ]; echo $?)" != 0 ]; then
        ret_runtime_mode_flags240_v0="--no-runtime"
        return 0
    elif [ "$([ "_${mode_2992}" != "_container" ]; echo $?)" != 0 ]; then
        ret_runtime_mode_flags240_v0=""
        return 0
    fi
    ret_runtime_mode_flags240_v0="--no-bwrap"
    return 0
}

# "-u VAR -u VAR ...": the env(1) arguments that drop every contaminating variable.
# scrub_arguments()
scrub_arguments__241_v0() {
    local array_60=()
    local parts_2994=("${array_60[@]}")
    for v_2995 in "${__CONTAMINATING_ENV_VARS_15[@]}"; do
        local array_63=("-u" "${v_2995}")
        parts_2994+=("${array_63[@]}")
    done
    join_words__40_v0 parts_2994[@]
    local ret_join_words40_v0__35_12="${ret_join_words40_v0}"
    ret_scrub_arguments241_v0="${ret_join_words40_v0__35_12}"
    return 0
}

# The mode every wine call uses: the probed one, else the requested one, with
# "auto" meaning no-bwrap when nothing has been probed yet.
# effective_runtime_mode()
effective_runtime_mode__242_v0() {
    local mode_3114="${__RESOLVED_RUNTIME_MODE_34}"
    if [ "$([ "_${mode_3114}" != "_" ]; echo $?)" != 0 ]; then
        mode_3114="${__RUNTIME_MODE_33}"
    fi
    if [ "$([ "_${mode_3114}" != "_auto" ]; echo $?)" != 0 ]; then
        mode_3114="no-bwrap"
    fi
    ret_effective_runtime_mode242_v0="${mode_3114}"
    return 0
}

# Runs a wine command inside the VRChat prefix with a sanitised environment.
# Every protontricks invocation in this script goes through here so the runtime
# mode and the environment scrubbing are configured in exactly one place. Output
# goes wherever ours does; a failure is the caller's to handle.
# run_in_prefix(command: Text)
run_in_prefix__243_v0() {
    local command_3113="${1}"
    effective_runtime_mode__242_v0 
    local ret_effective_runtime_mode242_v0__56_38="${ret_effective_runtime_mode242_v0}"
    runtime_mode_flags__240_v0 "${ret_effective_runtime_mode242_v0__56_38}"
    local ret_runtime_mode_flags240_v0__56_19="${ret_runtime_mode_flags240_v0}"
    local flags_3115="${ret_runtime_mode_flags240_v0__56_19}"
    scrub_arguments__241_v0 
    local ret_scrub_arguments241_v0__57_19="${ret_scrub_arguments241_v0}"
    local scrub_3116="${ret_scrub_arguments241_v0__57_19}"
    env ${scrub_3116} timeout 0 protontricks ${flags_3115} -c "${command_3113}" ${__VRCHAT_APP_ID_19}
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_run_in_prefix243_v0=''
        return "${__status}"
    fi
}

# The same, capturing combined output for inspection. Sets the status the way a
# command would; the output is returned whether or not the command succeeded,
# because the diagnosis is in the failure text.
__LAST_PREFIX_OUTPUT_87=""
__LAST_PREFIX_STATUS_88=0
# run_in_prefix_captured(command: Text, mode: Text, timeout_secs: Int)
run_in_prefix_captured__244_v0() {
    local command_2989="${1}"
    local mode_2990="${2}"
    local timeout_secs_2991="${3}"
    runtime_mode_flags__240_v0 "${mode_2990}"
    local ret_runtime_mode_flags240_v0__69_19="${ret_runtime_mode_flags240_v0}"
    local flags_2993="${ret_runtime_mode_flags240_v0__69_19}"
    scrub_arguments__241_v0 
    local ret_scrub_arguments241_v0__70_19="${ret_scrub_arguments241_v0}"
    local scrub_2996="${ret_scrub_arguments241_v0__70_19}"
    local command_64
    command_64="$(mktemp)"
    __status=$?
    local capture_2997="${command_64}"
    env ${scrub_2996} timeout ${timeout_secs_2991} protontricks ${flags_2993} -c "${command_2989}" ${__VRCHAT_APP_ID_19} > "${capture_2997}" 2>&1
    __status=$?
    __LAST_PREFIX_STATUS_88="${__status}"
    read_file__29_v0 "${capture_2997}"
    local ret_read_file29_v0__74_26="${ret_read_file29_v0}"
    __LAST_PREFIX_OUTPUT_87="${ret_read_file29_v0__74_26}"
    rm -f "${capture_2997}"
    __status=$?
    ret_run_in_prefix_captured244_v0="$(( __LAST_PREFIX_STATUS_88 == 0 ))"
    return 0
}

# True when wine output shows a broken library/config environment rather than a
# genuine application failure.
# prefix_output_is_broken(output: Text)
prefix_output_is_broken__245_v0() {
    local output_3001="${1}"
    matches__36_v0 "${output_3001}" "Fontconfig error|error while loading shared libraries|wine: (failed|cannot|could not)"
    local ret_matches36_v0__82_12="${ret_matches36_v0}"
    ret_prefix_output_is_broken245_v0="${ret_matches36_v0__82_12}"
    return 0
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
# get_prefix_holders()
get_prefix_holders__246_v0() {
    local pfx_2980="${__VRC_COMPATDATA_32}/pfx"
    # Proton exports "WINEPREFIX=<path>/" with a trailing slash while
    # protontricks exports it without, so both spellings must match.
    # 
    # cat, not a redirect: reading /proc/PID/environ needs PTRACE_MODE_READ, so
    # [ -r ] can say yes and the open still fail with EACCES -- and a failing
    # shell redirect prints its own error that no 2>/dev/null on tr can silence.
    local command_65
    command_65="$(for proc in /proc/[0-9]*; do
            [ -r "$proc/environ" ] || continue
            cat "$proc/environ" 2>/dev/null | tr '\0' '\n'                 | grep -qxF -e "WINEPREFIX=${pfx_2980}" -e "WINEPREFIX=${pfx_2980}/" || continue
            name="$(cat "$proc/comm" 2>/dev/null || true)"
            printf '%s %s
' "${proc#/proc/}" "${name:-unknown}"
        done)"
    __status=$?
    local found_2981="${command_65}"
    nonempty_lines__21_v0 "${found_2981}"
    local ret_nonempty_lines21_v0__111_12=("${ret_nonempty_lines21_v0[@]}")
    ret_get_prefix_holders246_v0=("${ret_nonempty_lines21_v0__111_12[@]}")
    return 0
}

# The process names out of "<pid> <name>" lines.
# holder_names(holders: [Text])
holder_names__247_v0() {
    local holders_2983=("${!1}")
    local array_66=()
    local names_2984=("${array_66[@]}")
    for holder_2985 in "${holders_2983[@]}"; do
        local command_70
        command_70="$(printf '%s' "${holder_2985}" | awk '{print $2}')"
        __status=$?
        local array_69=("${command_70}")
        names_2984+=("${array_69[@]}")
    done
    ret_holder_names247_v0=("${names_2984[@]}")
    return 0
}

# True when a VRCOSC process is holding the prefix. VRCOSC rewrites settings.json
# from memory when it exits, so anything written underneath a running instance is
# silently discarded -- the settings would look applied here and be gone by the
# time the user looked.
# vrcosc_is_running()
vrcosc_is_running__248_v0() {
    get_prefix_holders__246_v0 
    local ret_get_prefix_holders246_v0__128_30=("${ret_get_prefix_holders246_v0[@]}")
    holder_names__247_v0 ret_get_prefix_holders246_v0__128_30[@]
    local ret_holder_names247_v0__128_17=("${ret_holder_names247_v0[@]}")
    for name_3150 in "${ret_holder_names247_v0__128_17[@]}"; do
        matches__36_v0 "${name_3150}" "^[Vv][Rr][Cc][Oo][Ss][Cc]"
        local ret_matches36_v0__129_12="${ret_matches36_v0}"
        if [ "${ret_matches36_v0__129_12}" != 0 ]; then
            ret_vrcosc_is_running248_v0=1
            return 0
        fi
    done
    ret_vrcosc_is_running248_v0=0
    return 0
}

# The pid of a running VRChat.exe that owns this prefix inside Steam's
# pressure-vessel container, or empty.
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
# find_vrchat_container_pid()
find_vrchat_container_pid__249_v0() {
    local pfx_2978="${__VRC_COMPATDATA_32}/pfx"
    local command_73
    command_73="$(for proc in /proc/[0-9]*; do
            [ "$(cat "$proc/comm" 2>/dev/null)" = "VRChat.exe" ] || continue
            [ -r "$proc/environ" ] || continue
            cat "$proc/environ" 2>/dev/null | tr '\0' '\n'                 | grep -qxF -e "WINEPREFIX=${pfx_2978}" -e "WINEPREFIX=${pfx_2978}/" || continue
            cat "$proc/environ" 2>/dev/null | tr '\0' '\n' | grep -q '^PRESSURE_VESSEL_RUNTIME=' || continue
            printf '%s
' "${proc#/proc/}"
            break
        done)"
    __status=$?
    ret_find_vrchat_container_pid249_v0="${command_73}"
    return 0
}

# vrchat_is_running()
vrchat_is_running__250_v0() {
    find_vrchat_container_pid__249_v0 
    local ret_find_vrchat_container_pid249_v0__164_12="${ret_find_vrchat_container_pid249_v0}"
    ret_vrchat_is_running250_v0="$([ "_${ret_find_vrchat_container_pid249_v0__164_12}" == "_" ]; echo $?)"
    return 0
}

# Writes VRChat's own environment as a sourceable file, so a joining process
# runs with exactly Proton's settings (WINEDLLOVERRIDES, esync/fsync, paths).
# Per-process loader state is dropped; so is anything that is not a valid shell
# identifier, since some launchers export odd keys.
# Notes when a wine session other than VRChat's is using this prefix.
# 
# VRChat itself holding the prefix is normal and expected -- the launcher joins
# that session on purpose. A different session (a VRCOSC already running under
# protontricks, say) is worth mentioning before we write into the prefix.
# warn_if_prefix_busy()
warn_if_prefix_busy__252_v0() {
    get_prefix_holders__246_v0 
    local ret_get_prefix_holders246_v0__186_21=("${ret_get_prefix_holders246_v0[@]}")
    local holders_3105=("${ret_get_prefix_holders246_v0__186_21[@]}")
    local __length_74=("${holders_3105[@]}")
    if [ "$(( ${#__length_74[@]} == 0 ))" != 0 ]; then
        ret_warn_if_prefix_busy252_v0=''
        return 0
    fi
    # VRChat holding the prefix is fine for the launcher, which joins that
    # session on purpose -- but not for the installer. apply_wpf_registry_fix()
    # and the .NET install run through protontricks, which starts a second
    # wineserver on the same prefix. Each wineserver holds the registry in memory
    # and writes user.reg/system.reg wholesale on shutdown, so ours saves the
    # patch seconds later and VRChat's overwrites it hours later with a snapshot
    # taken before the patch existed. The install looks like it worked and the
    # black-window fix is simply gone.
    vrchat_is_running__250_v0 
    local ret_vrchat_is_running250_v0__199_8="${ret_vrchat_is_running250_v0}"
    if [ "${ret_vrchat_is_running250_v0__199_8}" != 0 ]; then
        log_warn__2_v0 "VRChat is running. Files installed into the prefix are unaffected, but"
        log_warn__2_v0 "registry writes are not: see the note at the registry step below."
        ret_warn_if_prefix_busy252_v0=''
        return 0
    fi
    holder_names__247_v0 holders_3105[@]
    local ret_holder_names247_v0__205_43=("${ret_holder_names247_v0[@]}")
    local command_75
    command_75="$(printf '%s
' ${ret_holder_names247_v0__205_43[@]} | sort -u | tr '
' ' ')"
    __status=$?
    local others_3106="${command_75}"
    log_warn__2_v0 "Wine processes are already running in this prefix: ${others_3106}"
    printf '%s\n' "${__YELLOW_3}Installing should still work. If VRCOSC later fails to start, close it${__NC_6}"
    printf '%s\n' "${__YELLOW_3}and VRChat, wait for wineserver to exit, and run the installer again.${__NC_6}"
}

# Smoke-tests one runtime mode by asking wine for its version. Leaves a short
# human-readable result in LAST_RUNTIME_PROBE and returns true only when the
# environment came back clean.
__LAST_RUNTIME_PROBE_89=""
# test_runtime_mode(candidate: Text)
test_runtime_mode__253_v0() {
    local candidate_2988="${1}"
    run_in_prefix_captured__244_v0 "wine --version" "${candidate_2988}" 180
    local ret_run_in_prefix_captured244_v0__217_16="${ret_run_in_prefix_captured244_v0}"
    local ok_2999="${ret_run_in_prefix_captured244_v0__217_16}"
    local out_3000="${__LAST_PREFIX_OUTPUT_87}"
    prefix_output_is_broken__245_v0 "${out_3000}"
    local ret_prefix_output_is_broken245_v0__220_19="${ret_prefix_output_is_broken245_v0}"
    if [ "$(( ok_2999 && $(( ! ret_prefix_output_is_broken245_v0__220_19 )) ))" != 0 ]; then
        first_match__37_v0 "${out_3000}" "wine-[0-9][^[:space:]]*"
        local ret_first_match37_v0__221_25="${ret_first_match37_v0}"
        local version_3006="${ret_first_match37_v0__221_25}"
        __LAST_RUNTIME_PROBE_89="$(if [ "$([ "_${version_3006}" == "_" ]; echo $?)" != 0 ]; then echo "${version_3006}"; else echo "wine ok"; fi)"
        ret_test_runtime_mode253_v0=1
        return 0
    fi
    local command_76
    command_76="$(grep -E 'Fontconfig error|error while loading|wine: ' <<< "${out_3000}" | head -n 1 | sed 's/^[[:space:]]*//')"
    __status=$?
    local reason_3007="${command_76}"
    local summary_3008="exit=${__LAST_PREFIX_STATUS_88}"
    if [ "$([ "_${reason_3007}" == "_" ]; echo $?)" != 0 ]; then
        summary_3008+=" -- ${reason_3007}"
    fi
    __LAST_RUNTIME_PROBE_89="${summary_3008}"
    ret_test_runtime_mode253_v0=0
    return 0
}

# The Proton build a prefix was last created or updated with. config_info holds
# the version string on line 1 and <proton root>/files/share/fonts/ on line 2.
# get_prefix_proton_version()
get_prefix_proton_version__254_v0() {
    local ci_2936="${__VRC_COMPATDATA_32}/config_info"
    file_exists__23_v0 "${ci_2936}"
    local ret_file_exists23_v0__239_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__239_12 ))" != 0 ]; then
        ret_get_prefix_proton_version254_v0=""
        return 0
    fi
    first_line__30_v0 "${ci_2936}"
    local ret_first_line30_v0__242_12="${ret_first_line30_v0}"
    ret_get_prefix_proton_version254_v0="${ret_first_line30_v0__242_12}"
    return 0
}

# get_prefix_proton_dir()
get_prefix_proton_dir__255_v0() {
    local ci_2939="${__VRC_COMPATDATA_32}/config_info"
    file_exists__23_v0 "${ci_2939}"
    local ret_file_exists23_v0__247_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__247_12 ))" != 0 ]; then
        ret_get_prefix_proton_dir255_v0=""
        return 0
    fi
    local command_77
    command_77="$(sed -n '2p' "${ci_2939}")"
    __status=$?
    local fonts_dir_2940="${command_77}"
    if [ "$([ "_${fonts_dir_2940}" != "_" ]; echo $?)" != 0 ]; then
        ret_get_prefix_proton_dir255_v0=""
        return 0
    fi
    strip_suffix__38_v0 "${fonts_dir_2940}" "/"
    local ret_strip_suffix38_v0__254_17="${ret_strip_suffix38_v0}"
    fonts_dir_2940="${ret_strip_suffix38_v0__254_17}"
    # .../files/share/fonts
    dirname__27_v0 "${fonts_dir_2940}"
    local ret_dirname27_v0__255_28="${ret_dirname27_v0}"
    dirname__27_v0 "${ret_dirname27_v0__255_28}"
    local ret_dirname27_v0__255_20="${ret_dirname27_v0}"
    dirname__27_v0 "${ret_dirname27_v0__255_20}"
    local ret_dirname27_v0__255_12="${ret_dirname27_v0}"
    ret_get_prefix_proton_dir255_v0="${ret_dirname27_v0__255_12}"
    return 0
}

# The Steam Runtime app id a Proton build demands, if it declares one. A build
# that requires a runtime protontricks cannot locate is the usual source of
# "Current Steam Runtime not recognized by Protontricks".
# get_prefix_runtime_appid()
get_prefix_runtime_appid__256_v0() {
    get_prefix_proton_dir__255_v0 
    local ret_get_prefix_proton_dir255_v0__262_24="${ret_get_prefix_proton_dir255_v0}"
    local proton_dir_2945="${ret_get_prefix_proton_dir255_v0__262_24}"
    if [ "$([ "_${proton_dir_2945}" != "_" ]; echo $?)" != 0 ]; then
        ret_get_prefix_runtime_appid256_v0=""
        return 0
    fi
    local manifest_2946="${proton_dir_2945}/toolmanifest.vdf"
    file_exists__23_v0 "${manifest_2946}"
    local ret_file_exists23_v0__267_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__267_12 ))" != 0 ]; then
        ret_get_prefix_runtime_appid256_v0=""
        return 0
    fi
    local command_78
    command_78="$(grep -oE '"require_tool_appid"[[:space:]]*"[0-9]+"' "${manifest_2946}" | grep -oE '[0-9]+' | head -n 1)"
    __status=$?
    ret_get_prefix_runtime_appid256_v0="${command_78}"
    return 0
}

# Picks the runtime mode to use for every subsequent wine call. An explicit
# --runtime is honoured as-is; "auto" probes candidates and takes the first one
# that yields a clean `wine --version`.
# probe_runtime_mode()
probe_runtime_mode__257_v0() {
    if [ "$([ "_${__RUNTIME_MODE_33}" == "_auto" ]; echo $?)" != 0 ]; then
        __RESOLVED_RUNTIME_MODE_34="${__RUNTIME_MODE_33}"
        log_info__0_v0 "Using requested Proton runtime mode: ${__BOLD_5}${__RESOLVED_RUNTIME_MODE_34}${__NC_6}"
        ret_probe_runtime_mode257_v0=''
        return 0
    fi
    list_contaminated_env__239_v0 
    local ret_list_contaminated_env239_v0__283_26=("${ret_list_contaminated_env239_v0[@]}")
    local contaminated_3109=("${ret_list_contaminated_env239_v0__283_26[@]}")
    local __length_79=("${contaminated_3109[@]}")
    if [ "$(( ${#__length_79[@]} > 0 ))" != 0 ]; then
        join_words__40_v0 contaminated_3109[@]
        local ret_join_words40_v0__285_78="${ret_join_words40_v0}"
        log_warn__2_v0 "Scrubbing leaked Steam Runtime variables from wine calls: ${ret_join_words40_v0__285_78} "
    fi
    if [ "${__DRY_RUN_28}" != 0 ]; then
        __RESOLVED_RUNTIME_MODE_34="no-bwrap"
        log_info__0_v0 "Dry run: skipping runtime probe, assuming mode '${__RESOLVED_RUNTIME_MODE_34}'."
        ret_probe_runtime_mode257_v0=''
        return 0
    fi
    for candidate_3110 in "${__RUNTIME_MODE_CANDIDATES_16[@]}"; do
        log_info__0_v0 "Probing Proton runtime mode '${candidate_3110}'..."
        test_runtime_mode__253_v0 "${candidate_3110}"
        local ret_test_runtime_mode253_v0__296_12="${ret_test_runtime_mode253_v0}"
        if [ "${ret_test_runtime_mode253_v0__296_12}" != 0 ]; then
            __RESOLVED_RUNTIME_MODE_34="${candidate_3110}"
            log_success__1_v0 "Runtime mode '${candidate_3110}' is usable (${__LAST_RUNTIME_PROBE_89})."
            ret_probe_runtime_mode257_v0=''
            return 0
        fi
        log_warn__2_v0 "Runtime mode '${candidate_3110}' produced a broken wine environment: ${__LAST_RUNTIME_PROBE_89}"
    done
    log_error__3_v0 "No Steam Runtime mode produced a working wine environment."
    printf '%s\n' "${__YELLOW_3}This usually means protontricks cannot pair your Proton build with a Steam Runtime.${__NC_6}"
    echo "Try launching VRChat once through Steam, then re-run this script."
    echo "You can also force a mode explicitly, e.g. ${__CYAN_4}--runtime host${__NC_6}."
    exit 1
}

# The flatpak permissions protontricks needs when it is the flatpak build.
# True when the protontricks we will actually invoke is the flatpak one. The
# override only means anything then: it used to run whenever any flatpak matched
# "protontricks" in a listing, including when the protontricks on PATH was pipx's.
# protontricks_is_flatpak()
protontricks_is_flatpak__263_v0() {
    flatpak list --app 2>/dev/null | grep -q 'com\.github\.Matoking\.protontricks'>/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        ret_protontricks_is_flatpak263_v0=0
        return 0
    fi
    # A `protontricks` on PATH that is not a flatpak wrapper is the one that runs.
    local command_82
    command_82="$(command -v protontricks 2>/dev/null)"
    __status=$?
    local bin_3079="${command_82}"
    if [ "$([ "_${bin_3079}" != "_" ]; echo $?)" != 0 ]; then
        ret_protontricks_is_flatpak263_v0=1
        return 0
    fi
    grep -qi 'flatpak' "${bin_3079}">/dev/null 2>&1
    __status=$?
    ret_protontricks_is_flatpak263_v0="$(( __status == 0 ))"
    return 0
}

# configure_protontricks_permissions()
configure_protontricks_permissions__264_v0() {
    protontricks_is_flatpak__263_v0 
    local ret_protontricks_is_flatpak263_v0__25_12="${ret_protontricks_is_flatpak263_v0}"
    if [ "$(( ! ret_protontricks_is_flatpak263_v0__25_12 ))" != 0 ]; then
        ret_configure_protontricks_permissions264_v0=''
        return 0
    fi
    log_info__0_v0 "Granting flatpak permissions protontricks needs:"
    for ov_3107 in "${__PROTONTRICKS_OVERRIDES_17[@]}"; do
        echo "  * ${__CYAN_4}${ov_3107}${__NC_6}"
    done
    echo "  ${__YELLOW_3}--talk-name=org.freedesktop.Flatpak lets protontricks run commands outside"
    echo "  its sandbox; it needs that to start Proton's wine. --uninstall takes these"
    echo "  back off again. See the README for why each one is here.${__NC_6}"
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_configure_protontricks_permissions264_v0=''
        return 0
    fi
    for ov_3108 in "${__PROTONTRICKS_OVERRIDES_17[@]}"; do
        flatpak override --user "${ov_3108}" ${__PROTONTRICKS_FLATPAK_ID_18}
        __status=$?
    done
}

# Takes the grants above back off. Only ours: --reset would also drop overrides
# the user set themselves. Returns true when there were grants to revoke.
# revoke_protontricks_permissions()
revoke_protontricks_permissions__265_v0() {
    protontricks_is_flatpak__263_v0 
    local ret_protontricks_is_flatpak263_v0__48_12="${ret_protontricks_is_flatpak263_v0}"
    if [ "$(( ! ret_protontricks_is_flatpak263_v0__48_12 ))" != 0 ]; then
        ret_revoke_protontricks_permissions265_v0=0
        return 0
    fi
    for ov_3080 in "${__PROTONTRICKS_OVERRIDES_17[@]}"; do
        # "--nofilesystem=host" undoes "--filesystem=host"; a --talk-name is
        # undone by --no-talk-name.
        replace_one__62_v0 "${ov_3080}" "--filesystem=" "--nofilesystem="
        local ret_replace_one62_v0__55_20="${ret_replace_one62_v0}"
        local undo_3085="${ret_replace_one62_v0__55_20}"
        replace_one__62_v0 "${undo_3085}" "--talk-name=" "--no-talk-name="
        local ret_replace_one62_v0__56_16="${ret_replace_one62_v0}"
        undo_3085="${ret_replace_one62_v0__56_16}"
        if [ "${__DRY_RUN_28}" != 0 ]; then
            log_info__0_v0 "Would revoke flatpak permission: ${ov_3080}"
        else
            flatpak override --user "${undo_3085}" ${__PROTONTRICKS_FLATPAK_ID_18}>/dev/null 2>&1
            __status=$?
        fi
    done
    if [ "$(( ! __DRY_RUN_28 ))" != 0 ]; then
        log_success__1_v0 "Revoked the flatpak permissions this installer granted."
    fi
    ret_revoke_protontricks_permissions265_v0=1
    return 0
}

# The WPF hardware-acceleration registry patch, which is what stops VRCOSC from
# opening as a black window under wine.
# True when the prefix registry already carries the patch, so a reinstall does
# not need to write it at all.
# wpf_registry_fix_applied()
wpf_registry_fix_applied__273_v0() {
    local user_reg_3111="${__VRC_COMPATDATA_32}/pfx/user.reg"
    file_exists__23_v0 "${user_reg_3111}"
    local ret_file_exists23_v0__12_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__12_12 ))" != 0 ]; then
        ret_wpf_registry_fix_applied273_v0=0
        return 0
    fi
    grep -qi 'Avalon\.Graphics' "${user_reg_3111}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        ret_wpf_registry_fix_applied273_v0=0
        return 0
    fi
    grep -qi '"DisableHWAcceleration"=dword:00000001' "${user_reg_3111}">/dev/null 2>&1
    __status=$?
    ret_wpf_registry_fix_applied273_v0="$(( __status == 0 ))"
    return 0
}

# apply_wpf_registry_fix()
apply_wpf_registry_fix__274_v0() {
    log_info__0_v0 "Applying WPF hardware acceleration registry fix (prevents black window bug)..."
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_apply_wpf_registry_fix274_v0=''
        return 0
    fi
    wpf_registry_fix_applied__273_v0 
    local ret_wpf_registry_fix_applied273_v0__29_8="${ret_wpf_registry_fix_applied273_v0}"
    if [ "${ret_wpf_registry_fix_applied273_v0__29_8}" != 0 ]; then
        log_success__1_v0 "WPF registry patch already present in the prefix; leaving it alone."
        ret_apply_wpf_registry_fix274_v0=''
        return 0
    fi
    # A wineserver holds the registry in memory and writes user.reg/system.reg
    # wholesale when it exits. protontricks starts a second wineserver on the same
    # prefix, so ours saves the patch seconds from now and VRChat's overwrites it
    # hours from now with a snapshot taken before the patch existed. Writing here
    # would report success and leave nothing behind.
    vrchat_is_running__250_v0 
    local ret_vrchat_is_running250_v0__39_8="${ret_vrchat_is_running250_v0}"
    if [ "${ret_vrchat_is_running250_v0__39_8}" != 0 ]; then
        log_warn__2_v0 "VRChat is running, so this patch cannot be written: its wineserver will"
        log_warn__2_v0 "rewrite the registry from memory when it exits and discard ours."
        log_warn__2_v0 "Close VRChat and run the installer again. Until then VRCOSC may open as"
        log_warn__2_v0 "a black window."
        ret_apply_wpf_registry_fix274_v0=''
        return 0
    fi
    local reg_file_3112="${__VRC_COMPATDATA_32}/pfx/drive_c/vrcosc_disable_hw_acc.reg"
    cat << 'EOF_REG' > "${reg_file_3112}"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Avalon.Graphics]
"DisableHWAcceleration"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Microsoft\Avalon.Graphics]
"DisableHWAcceleration"=dword:00000001
EOF_REG
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_apply_wpf_registry_fix274_v0=''
        return "${__status}"
    fi
    # Forward slashes: protontricks passes the command through sh -c unescaped, so
    # "C:\vrcosc..." reaches wine as "C:vrcosc...", a drive-relative path that
    # happens to resolve only because wine starts at the root of drive C.
    run_in_prefix__243_v0 "wine regedit C:/vrcosc_disable_hw_acc.reg"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_apply_wpf_registry_fix274_v0=''
        return "${__status}"
    fi
    rm -f "${reg_file_3112}"
    __status=$?
    log_success__1_v0 "WPF registry patch applied successfully."
}

# Where everything lives: launchers, desktop entries, the install directory
# inside the prefix, VRCOSC's config directories and VRChat's game directory.
# The branch a per-channel path is for: the argument when given, else the one
# being installed.
# branch_or_default(branch: Text)
branch_or_default__289_v0() {
    local branch_2966="${1}"
    if [ "$([ "_${branch_2966}" != "_" ]; echo $?)" != 0 ]; then
        ret_branch_or_default289_v0="${__VRCOSC_BRANCH_23}"
        return 0
    fi
    ret_branch_or_default289_v0="${branch_2966}"
    return 0
}

# get_launcher_script(branch: Text)
get_launcher_script__290_v0() {
    local branch_3029="${1}"
    branch_or_default__289_v0 "${branch_3029}"
    local ret_branch_or_default289_v0__16_8="${ret_branch_or_default289_v0}"
    if [ "$([ "_${ret_branch_or_default289_v0__16_8}" != "_beta" ]; echo $?)" != 0 ]; then
        home__15_v0 
        local ret_home15_v0__17_18="${ret_home15_v0}"
        ret_get_launcher_script290_v0="${ret_home15_v0__17_18}/.local/bin/vrcosc-beta"
        return 0
    fi
    home__15_v0 
    local ret_home15_v0__19_14="${ret_home15_v0}"
    ret_get_launcher_script290_v0="${ret_home15_v0__19_14}/.local/bin/vrcosc"
    return 0
}

# get_desktop_file(branch: Text)
get_desktop_file__291_v0() {
    local branch_3032="${1}"
    branch_or_default__289_v0 "${branch_3032}"
    local ret_branch_or_default289_v0__23_8="${ret_branch_or_default289_v0}"
    if [ "$([ "_${ret_branch_or_default289_v0__23_8}" != "_beta" ]; echo $?)" != 0 ]; then
        home__15_v0 
        local ret_home15_v0__24_18="${ret_home15_v0}"
        ret_get_desktop_file291_v0="${ret_home15_v0__24_18}/.local/share/applications/vrcosc-beta.desktop"
        return 0
    fi
    home__15_v0 
    local ret_home15_v0__26_14="${ret_home15_v0}"
    ret_get_desktop_file291_v0="${ret_home15_v0__26_14}/.local/share/applications/vrcosc.desktop"
    return 0
}

# get_app_icon_path()
get_app_icon_path__292_v0() {
    home__15_v0 
    local ret_home15_v0__30_14="${ret_home15_v0}"
    ret_get_app_icon_path292_v0="${ret_home15_v0__30_14}/.local/share/icons/hicolor/256x256/apps/vrcosc.png"
    return 0
}

# get_vrcosc_install_dir(branch: Text)
get_vrcosc_install_dir__293_v0() {
    local branch_2964="${1}"
    local base_2965="${__VRC_COMPATDATA_32}/pfx/drive_c/users/steamuser/AppData/Local"
    branch_or_default__289_v0 "${branch_2964}"
    local ret_branch_or_default289_v0__35_8="${ret_branch_or_default289_v0}"
    if [ "$([ "_${ret_branch_or_default289_v0__35_8}" != "_beta" ]; echo $?)" != 0 ]; then
        ret_get_vrcosc_install_dir293_v0="${base_2965}/VRCOSC-beta"
        return 0
    fi
    ret_get_vrcosc_install_dir293_v0="${base_2965}/VRCOSC"
    return 0
}

# Every user directory in the prefix that holds config for the selected branch.
# Steam prefixes routinely carry both steamuser and a real user name, and a user
# may have pointed the directory somewhere else with a symlink.
# get_vrcosc_config_dirs()
get_vrcosc_config_dirs__294_v0() {
    # Both channels use the same directory. VRCOSC's APP_NAME is "VRCOSC" for every
    # Release build and only becomes "VRCOSC-Dev" under #if DEBUG, so a beta install
    # reads and writes the live settings; only the install directory differs. Looking
    # for a VRCOSC-Beta directory meant --purge --branch beta reported success having
    # matched nothing.
    local leaf_3087="VRCOSC"
    local array_89=()
    local dirs_3088=("${array_89[@]}")
    glob__19_v0 "${__VRC_COMPATDATA_32}/pfx/drive_c/users/*/AppData/Roaming/${leaf_3087}"
    local ret_glob19_v0__52_14=("${ret_glob19_v0[@]}")
    for d_3089 in "${ret_glob19_v0__52_14[@]}"; do
        path_exists__22_v0 "${d_3089}"
        local ret_path_exists22_v0__53_12="${ret_path_exists22_v0}"
        if [ "${ret_path_exists22_v0__53_12}" != 0 ]; then
            local array_92=("${d_3089}")
            dirs_3088+=("${array_92[@]}")
        fi
    done
    ret_get_vrcosc_config_dirs294_v0=("${dirs_3088[@]}")
    return 0
}

# get_vrchat_game_dir()
get_vrchat_game_dir__295_v0() {
    dirname__27_v0 "${__VRC_COMPATDATA_32}"
    local ret_dirname27_v0__61_35="${ret_dirname27_v0}"
    dirname__27_v0 "${ret_dirname27_v0__61_35}"
    local ret_dirname27_v0__61_27="${ret_dirname27_v0}"
    local steamapps_dir_3033="${ret_dirname27_v0__61_27}"
    ret_get_vrchat_game_dir295_v0="${steamapps_dir_3033}/common/VRChat"
    return 0
}

# Where a downloaded bridge payload is kept between runs.
# get_launch_bridge_cache()
get_launch_bridge_cache__296_v0() {
    home__15_v0 
    local ret_home15_v0__67_14="${ret_home15_v0}"
    ret_get_launch_bridge_cache296_v0="${ret_home15_v0__67_14}/.local/share/vrcosc-linux/vrc-launch-bridge.exe"
    return 0
}

# Directory install.sh itself lives in, or empty when there is no script file --
# the normal case for a piped install.
# get_script_dir()
get_script_dir__297_v0() {
    file_exists__23_v0 "${__SCRIPT_SOURCE_36}"
    local ret_file_exists23_v0__73_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__73_12 ))" != 0 ]; then
        ret_get_script_dir297_v0=""
        return 0
    fi
    local command_93
    command_93="$(cd "$(dirname "${__SCRIPT_SOURCE_36}")" && pwd)"
    __status=$?
    ret_get_script_dir297_v0="${command_93}"
    return 0
}

# One path per element, so a $HOME containing a space survives.
# get_all_installed_files()
get_all_installed_files__298_v0() {
    get_launcher_script__290_v0 "live"
    local ret_get_launcher_script290_v0__82_9="${ret_get_launcher_script290_v0}"
    get_launcher_script__290_v0 "beta"
    local ret_get_launcher_script290_v0__83_9="${ret_get_launcher_script290_v0}"
    get_desktop_file__291_v0 "live"
    local ret_get_desktop_file291_v0__84_9="${ret_get_desktop_file291_v0}"
    get_desktop_file__291_v0 "beta"
    local ret_get_desktop_file291_v0__85_9="${ret_get_desktop_file291_v0}"
    get_app_icon_path__292_v0 
    local ret_get_app_icon_path292_v0__86_9="${ret_get_app_icon_path292_v0}"
    local array_94=("${ret_get_launcher_script290_v0__82_9}" "${ret_get_launcher_script290_v0__83_9}" "${ret_get_desktop_file291_v0__84_9}" "${ret_get_desktop_file291_v0__85_9}" "${ret_get_app_icon_path292_v0__86_9}")
    ret_get_all_installed_files298_v0=("${array_94[@]}")
    return 0
}

# True when two files have identical contents. cmp(1) comes from diffutils, which
# minimal Fedora and Arch installs do not ship -- and a missing cmp reads as
# "differs", which made the bridge look unpatched forever and re-patch on every
# run. Falls back to a checksum, then to size.
# files_identical(a: Text, b: Text)
files_identical__299_v0() {
    local a_3047="${1}"
    local b_3048="${2}"
    file_exists__23_v0 "${a_3047}"
    local ret_file_exists23_v0__95_12="${ret_file_exists23_v0}"
    file_exists__23_v0 "${b_3048}"
    local ret_file_exists23_v0__95_34="${ret_file_exists23_v0}"
    if [ "$(( $(( ! ret_file_exists23_v0__95_12 )) || $(( ! ret_file_exists23_v0__95_34 )) ))" != 0 ]; then
        ret_files_identical299_v0=0
        return 0
    fi
    # cmp answers 0 for identical and 1 for differing; any other status means it
    # could not do the job (127 when it is not installed at all), so fall through
    # rather than reporting a difference that was never measured.
    cmp -s "${a_3047}" "${b_3048}">/dev/null 2>&1
    __status=$?
    local rc_3049="${__status}"
    if [ "$(( rc_3049 <= 1 ))" != 0 ]; then
        ret_files_identical299_v0="$(( rc_3049 == 0 ))"
        return 0
    fi
    have_cmd__18_v0 "sha256sum"
    local ret_have_cmd18_v0__106_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__106_8}" != 0 ]; then
        local command_95
        command_95="$(sha256sum < "${a_3047}")"
        __status=$?
        local command_96
        command_96="$(sha256sum < "${b_3048}")"
        __status=$?
        ret_files_identical299_v0="$([ "_${command_95}" != "_${command_96}" ]; echo $?)"
        return 0
    fi
    local command_97
    command_97="$(wc -c < "${a_3047}")"
    __status=$?
    local command_98
    command_98="$(wc -c < "${b_3048}")"
    __status=$?
    ret_files_identical299_v0="$([ "_${command_97}" != "_${command_98}" ]; echo $?)"
    return 0
}

# get_vrcosc_version_from_dir(dir: Text)
get_vrcosc_version_from_dir__300_v0() {
    local dir_3019="${1}"
    local deps_3020="${dir_3019}/VRCOSC.deps.json"
    local dll_3021="${dir_3019}/VRCOSC.dll"
    file_exists__23_v0 "${deps_3020}"
    local ret_file_exists23_v0__115_8="${ret_file_exists23_v0}"
    if [ "${ret_file_exists23_v0__115_8}" != 0 ]; then
        local command_99
        command_99="$(grep -o '"VRCOSC.App": "[^"]*"' "${deps_3020}" 2>/dev/null | head -n 1 | cut -d'"' -f4)"
        __status=$?
        local v_3022="${command_99}"
        if [ "$([ "_${v_3022}" == "_" ]; echo $?)" != 0 ]; then
            ret_get_vrcosc_version_from_dir300_v0="${v_3022}"
            return 0
        fi
    fi
    file_exists__23_v0 "${dll_3021}"
    local ret_file_exists23_v0__121_8="${ret_file_exists23_v0}"
    if [ "${ret_file_exists23_v0__121_8}" != 0 ]; then
        ret_get_vrcosc_version_from_dir300_v0="Installed"
        return 0
    fi
    ret_get_vrcosc_version_from_dir300_v0="Not installed"
    return 0
}

# Talking to GitHub about VRCOSC releases, comparing versions, and installing
# the package into the prefix.
# GET a GitHub API URL. Uses GITHUB_TOKEN/GH_TOKEN when the caller has one,
# because the unauthenticated limit is 60 requests/hour per IP and shared or
# NAT'd addresses hit it routinely -- which otherwise looks like "GitHub is down".
# The token is only ever sent to api.github.com, and never echoed.
# github_api(url: Text)
github_api__305_v0() {
    local url_3025="${1}"
    env_or__16_v0 "GITHUB_TOKEN" ""
    local ret_env_or16_v0__15_17="${ret_env_or16_v0}"
    local token_3026="${ret_env_or16_v0__15_17}"
    if [ "$([ "_${token_3026}" != "_" ]; echo $?)" != 0 ]; then
        env_or__16_v0 "GH_TOKEN" ""
        local ret_env_or16_v0__17_17="${ret_env_or16_v0}"
        token_3026="${ret_env_or16_v0__17_17}"
    fi
    starts_with__83_v0 "${url_3025}" "https://api.github.com/"
    local ret_starts_with83_v0__19_24="${ret_starts_with83_v0}"
    if [ "$(( $([ "_${token_3026}" == "_" ]; echo $?) && ret_starts_with83_v0__19_24 ))" != 0 ]; then
        local command_100
        command_100="$(curl -fsS --connect-timeout 10             -H "User-Agent: vrcosc-installer"             -H "X-GitHub-Api-Version: 2022-11-28"             -H "Authorization: Bearer ${token_3026}" "${url_3025}" 2>&1 || true)"
        __status=$?
        ret_github_api305_v0="${command_100}"
        return 0
    fi
    local command_101
    command_101="$(curl -fsS --connect-timeout 10         -H "User-Agent: vrcosc-installer"         -H "X-GitHub-Api-Version: 2022-11-28"         "${url_3025}" 2>&1 || true)"
    __status=$?
    ret_github_api305_v0="${command_101}"
    return 0
}

# True when a GitHub response says the address is rate-limited.
# looks_rate_limited(response: Text)
looks_rate_limited__306_v0() {
    local response_3028="${1}"
    matches__36_v0 "${response_3028}" "error: 403|rate limit"
    local ret_matches36_v0__33_12="${ret_matches36_v0}"
    ret_looks_rate_limited306_v0="${ret_matches36_v0__33_12}"
    return 0
}

# Drops trailing ".0" components so the four-part version recorded in
# VRCOSC.deps.json ("2026.812.0.0") compares equal to the three-part release tag
# it came from ("2026.812.0").
# normalise_version(version: Text)
normalise_version__307_v0() {
    local version_3125="${1}"
    local v_3126="${version_3125}"
    while :
    do
        ends_with__84_v0 "${v_3126}" ".0"
        local ret_ends_with84_v0__42_16="${ret_ends_with84_v0}"
        if [ "$(( ! ret_ends_with84_v0__42_16 ))" != 0 ]; then
            break
        fi
        local command_102
        command_102="$(printf '%s' "${v_3126%.0}")"
        __status=$?
        v_3126="${command_102}"
    done
    ret_normalise_version307_v0="${v_3126}"
    return 0
}

# "newer", "older" or "same" for version a relative to b.
# compare_versions(a_raw: Text, b_raw: Text)
compare_versions__308_v0() {
    local a_raw_3123="${1}"
    local b_raw_3124="${2}"
    normalise_version__307_v0 "${a_raw_3123}"
    local ret_normalise_version307_v0__52_15="${ret_normalise_version307_v0}"
    local a_3129="${ret_normalise_version307_v0__52_15}"
    normalise_version__307_v0 "${b_raw_3124}"
    local ret_normalise_version307_v0__53_15="${ret_normalise_version307_v0}"
    local b_3130="${ret_normalise_version307_v0__53_15}"
    if [ "$([ "_${a_3129}" != "_${b_3130}" ]; echo $?)" != 0 ]; then
        ret_compare_versions308_v0="same"
        return 0
    fi
    local command_103
    command_103="$(printf '%s
%s
' "${a_3129}" "${b_3130}" | sort -V | tail -n 1)"
    __status=$?
    local highest_3131="${command_103}"
    if [ "$([ "_${highest_3131}" != "_${a_3129}" ]; echo $?)" != 0 ]; then
        ret_compare_versions308_v0="newer"
        return 0
    fi
    ret_compare_versions308_v0="older"
    return 0
}

# The version a release asset URL delivers, taken from the tag in its path:
# .../releases/download/2026.807.0/VRCOSC-2026.807.0-live-full.nupkg
# get_version_from_asset_url(url: Text)
get_version_from_asset_url__309_v0() {
    local url_3120="${1}"
    local command_104
    command_104="$(sed -n 's|.*/releases/download/\([^/]*\)/.*|\1|p' <<< "${url_3120}")"
    __status=$?
    ret_get_version_from_asset_url309_v0="${command_104}"
    return 0
}

# install_vrcosc()
install_vrcosc__310_v0() {
    log_info__0_v0 "Fetching latest VRCOSC release version (channel: ${__VRCOSC_BRANCH_23})..."
    local pkg_pattern_3117="live-full.nupkg"
    if [ "$([ "_${__VRCOSC_BRANCH_23}" != "_beta" ]; echo $?)" != 0 ]; then
        pkg_pattern_3117="beta-full.nupkg"
    fi
    # /releases/latest never returns a prerelease, and beta builds are published
    # as prereleases -- asking it for the beta channel quietly handed back the
    # live package instead. Read the release list and pick per channel.
    github_api__305_v0 "https://api.github.com/repos/VolcanicArts/VRCOSC/releases"
    local ret_github_api305_v0__83_33="${ret_github_api305_v0}"
    local latest_release_json_3118="${ret_github_api305_v0__83_33}"
    local command_105
    command_105="$(grep -o "https://github.com/VolcanicArts/VRCOSC/releases/download/[^\"]*${pkg_pattern_3117}" <<< "${latest_release_json_3118}" | head -n 1)"
    __status=$?
    local nupkg_url_3119="${command_105}"
    if [ "$([ "_${nupkg_url_3119}" != "_" ]; echo $?)" != 0 ]; then
        if [ "${__DRY_RUN_28}" != 0 ]; then
            log_warn__2_v0 "Dry run: could not reach the GitHub releases API; skipping VRCOSC download."
            ret_install_vrcosc310_v0=''
            return 0
        fi
        log_error__3_v0 "Error: Failed to fetch the VRCOSC ${__VRCOSC_BRANCH_23} package URL."
        looks_rate_limited__306_v0 "${latest_release_json_3118}"
        local ret_looks_rate_limited306_v0__93_12="${ret_looks_rate_limited306_v0}"
        if [ "${ret_looks_rate_limited306_v0__93_12}" != 0 ]; then
            printf '%s\n' "${__YELLOW_3}GitHub is rate-limiting this address (60 requests/hour when unauthenticated).${__NC_6}"
            echo "Wait an hour, or export a token first: ${__CYAN_4}export GITHUB_TOKEN=\\\$(gh auth token)${__NC_6}"
        else
            printf '%s\n' "${__YELLOW_3}GitHub may be unreachable. Response was:${__NC_6}"
            printf '%s
' "${latest_release_json_3118}" | head -n 5 | sed 's/^/  /'
            __status=$?
        fi
        exit 1
    fi
    # Do not clobber a newer local build. The maintainer routinely runs a build
    # ahead of the published release, and this function deletes the install
    # directory before unpacking, so an unconditional install is a downgrade.
    get_version_from_asset_url__309_v0 "${nupkg_url_3119}"
    local ret_get_version_from_asset_url309_v0__106_28="${ret_get_version_from_asset_url309_v0}"
    local remote_version_3121="${ret_get_version_from_asset_url309_v0__106_28}"
    get_vrcosc_install_dir__293_v0 ""
    local ret_get_vrcosc_install_dir293_v0__107_55="${ret_get_vrcosc_install_dir293_v0}"
    get_vrcosc_version_from_dir__300_v0 "${ret_get_vrcosc_install_dir293_v0__107_55}"
    local ret_get_vrcosc_version_from_dir300_v0__107_27="${ret_get_vrcosc_version_from_dir300_v0}"
    local local_version_3122="${ret_get_vrcosc_version_from_dir300_v0__107_27}"
    if [ "$(( $(( ! __FORCE_INSTALL_24 )) && $([ "_${remote_version_3121}" == "_" ]; echo $?) ))" != 0 ]; then
        if [ "$([ "_${local_version_3122}" != "_Not installed" ]; echo $?)" != 0 ]; then
            # nothing there yet
            :
        elif [ "$([ "_${local_version_3122}" != "_Installed" ]; echo $?)" != 0 ]; then
            log_warn__2_v0 "Installed VRCOSC has no readable version (no VRCOSC.deps.json); reinstalling ${remote_version_3121}."
        else
            compare_versions__308_v0 "${local_version_3122}" "${remote_version_3121}"
            local ret_compare_versions308_v0__118_34="${ret_compare_versions308_v0}"
            local relation_3132="${ret_compare_versions308_v0__118_34}"
            if [ "$([ "_${relation_3132}" != "_same" ]; echo $?)" != 0 ]; then
                log_success__1_v0 "VRCOSC ${local_version_3122} is already the latest ${__VRCOSC_BRANCH_23} release. Skipping download (use -f/--force to reinstall)."
                ret_install_vrcosc310_v0=''
                return 0
            elif [ "$([ "_${relation_3132}" != "_newer" ]; echo $?)" != 0 ]; then
                log_warn__2_v0 "Installed VRCOSC ${local_version_3122} is newer than the latest ${__VRCOSC_BRANCH_23} release (${remote_version_3121}); not downgrading."
                echo "Use ${__CYAN_4}-f/--force${__NC_6} to install ${remote_version_3121} over it anyway."
                ret_install_vrcosc310_v0=''
                return 0
            fi
        fi
    fi
    log_info__0_v0 "Downloading VRCOSC package from: ${nupkg_url_3119}"
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_install_vrcosc310_v0=''
        return 0
    fi
    # mktemp, not a fixed name: a predictable path in a shared /tmp lets another
    # local user pre-plant a symlink and have the download land on a file of ours.
    local command_106
    command_106="$(mktemp -d "${TMPDIR:-/tmp}/vrcosc-install.XXXXXX")"
    __status=$?
    local work_dir_3133="${command_106}"
    if [ "$(( $(( __status != 0 )) || $([ "_${work_dir_3133}" != "_" ]; echo $?) ))" != 0 ]; then
        log_error__3_v0 "Could not create a temporary directory."
        exit 1
    fi
    local nupkg_file_3134="${work_dir_3133}/vrcosc-latest.nupkg"
    # -f, or a 404 body lands in the .nupkg and unzip reports a corrupt archive
    # through the error banner, naming nothing useful.
    curl -fL -o "${nupkg_file_3134}" "${nupkg_url_3119}"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_vrcosc310_v0=''
        return "${__status}"
    fi
    get_vrcosc_install_dir__293_v0 ""
    local ret_get_vrcosc_install_dir293_v0__152_24="${ret_get_vrcosc_install_dir293_v0}"
    local vrcosc_dir_3135="${ret_get_vrcosc_install_dir293_v0__152_24}"
    log_info__0_v0 "Installing VRCOSC to ${vrcosc_dir_3135}..."
    mkdir_p__32_v0 "${vrcosc_dir_3135}"
    local ret_mkdir_p32_v0__154_5="${ret_mkdir_p32_v0}"
    # Clean previous installation binaries
    rm -rf "${vrcosc_dir_3135:?}"/*
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_vrcosc310_v0=''
        return "${__status}"
    fi
    local temp_extract_3136="${work_dir_3133}/extract"
    mkdir -p "${temp_extract_3136}"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_vrcosc310_v0=''
        return "${__status}"
    fi
    unzip -q "${nupkg_file_3134}" -d "${temp_extract_3136}"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_vrcosc310_v0=''
        return "${__status}"
    fi
    cp -r "${temp_extract_3136}/lib/app/"* "${vrcosc_dir_3135}/"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_vrcosc310_v0=''
        return "${__status}"
    fi
    rm -rf "${work_dir_3133}"
    __status=$?
    log_success__1_v0 "VRCOSC files extracted successfully."
}

# The .NET Desktop Runtime VRCOSC needs, and getting it into the prefix.
# Reads the .NET runtime band VRCOSC actually asks for out of its
# runtimeconfig.json, as a "<major>.<minor>" channel. .NET's default rollForward
# policy does not cross major versions, so installing the wrong major (10.0 for
# a net9.0 build, say) leaves VRCOSC reporting that no runtime is installed even
# though dotnet.exe sits right there in the same prefix. Empty when unreadable.
# get_required_dotnet_channel(dir: Text)
get_required_dotnet_channel__325_v0() {
    local dir_2967="${1}"
    local d_2968="${dir_2967}"
    if [ "$([ "_${d_2968}" != "_" ]; echo $?)" != 0 ]; then
        get_vrcosc_install_dir__293_v0 ""
        local ret_get_vrcosc_install_dir293_v0__18_13="${ret_get_vrcosc_install_dir293_v0}"
        d_2968="${ret_get_vrcosc_install_dir293_v0__18_13}"
    fi
    local cfg_2969="${d_2968}/VRCOSC.runtimeconfig.json"
    file_exists__23_v0 "${cfg_2969}"
    local ret_file_exists23_v0__21_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__21_12 ))" != 0 ]; then
        ret_get_required_dotnet_channel325_v0=""
        return 0
    fi
    local channel_2970=""
    have_cmd__18_v0 "python3"
    local ret_have_cmd18_v0__26_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__26_8}" != 0 ]; then
        local command_107
        command_107="$({ python3 - "${cfg_2969}" <<'PY' 2>/dev/null || true
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
        })"
        __status=$?
        channel_2970="${command_107}"
    fi
    # Fallback for hosts without python3: first version-looking field wins.
    if [ "$([ "_${channel_2970}" != "_" ]; echo $?)" != 0 ]; then
        local command_108
        command_108="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+' "${cfg_2969}" | head -n 1 | grep -oE '[0-9]+\.[0-9]+$')"
        __status=$?
        channel_2970="${command_108}"
    fi
    if [ "$([ "_${channel_2970}" != "_" ]; echo $?)" != 0 ]; then
        local command_109
        command_109="$(grep -oE '"tfm"[[:space:]]*:[[:space:]]*"net[0-9]+\.[0-9]+' "${cfg_2969}" | head -n 1 | grep -oE '[0-9]+\.[0-9]+$')"
        __status=$?
        channel_2970="${command_109}"
    fi
    ret_get_required_dotnet_channel325_v0="${channel_2970}"
    return 0
}

# desktop_runtime_dir()
desktop_runtime_dir__326_v0() {
    ret_desktop_runtime_dir326_v0="${__VRC_COMPATDATA_32}/pfx/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App"
    return 0
}

# Lists the Microsoft.WindowsDesktop.App versions present in the prefix.
# get_installed_desktop_runtimes()
get_installed_desktop_runtimes__327_v0() {
    local array_110=()
    local versions_2956=("${array_110[@]}")
    desktop_runtime_dir__326_v0 
    local ret_desktop_runtime_dir326_v0__67_24="${ret_desktop_runtime_dir326_v0}"
    local shared_dir_2957="${ret_desktop_runtime_dir326_v0__67_24}"
    dir_exists__24_v0 "${shared_dir_2957}"
    local ret_dir_exists24_v0__68_12="${ret_dir_exists24_v0}"
    if [ "$(( ! ret_dir_exists24_v0__68_12 ))" != 0 ]; then
        ret_get_installed_desktop_runtimes327_v0=("${versions_2956[@]}")
        return 0
    fi
    glob__19_v0 "${shared_dir_2957}/*"
    local ret_glob19_v0__71_14=("${ret_glob19_v0[@]}")
    for d_2960 in "${ret_glob19_v0__71_14[@]}"; do
        dir_exists__24_v0 "${d_2960}"
        local ret_dir_exists24_v0__72_12="${ret_dir_exists24_v0}"
        if [ "${ret_dir_exists24_v0__72_12}" != 0 ]; then
            basename__28_v0 "${d_2960}"
            local ret_basename28_v0__73_26="${ret_basename28_v0}"
            local array_113=("${ret_basename28_v0__73_26}")
            versions_2956+=("${array_113[@]}")
        fi
    done
    ret_get_installed_desktop_runtimes327_v0=("${versions_2956[@]}")
    return 0
}

# True when a runtime matching the requested "<major>.<minor>" channel is present.
# has_desktop_runtime_channel(channel: Text)
has_desktop_runtime_channel__328_v0() {
    local channel_2972="${1}"
    get_installed_desktop_runtimes__327_v0 
    local ret_get_installed_desktop_runtimes327_v0__81_22=("${ret_get_installed_desktop_runtimes327_v0[@]}")
    for installed_2973 in "${ret_get_installed_desktop_runtimes327_v0__81_22[@]}"; do
        starts_with__83_v0 "${installed_2973}" "${channel_2972}."
        local ret_starts_with83_v0__82_12="${ret_starts_with83_v0}"
        if [ "${ret_starts_with83_v0__82_12}" != 0 ]; then
            ret_has_desktop_runtime_channel328_v0=1
            return 0
        fi
    done
    ret_has_desktop_runtime_channel328_v0=0
    return 0
}

# Fails loudly when the runtime VRCOSC needs is not actually in the prefix after
# installing. Silently proceeding here is what produced "installed fine but
# VRCOSC says there is no runtime" reports.
# verify_dotnet_runtime(channel: Text)
verify_dotnet_runtime__329_v0() {
    local channel_3144="${1}"
    get_installed_desktop_runtimes__327_v0 
    local ret_get_installed_desktop_runtimes327_v0__93_32=("${ret_get_installed_desktop_runtimes327_v0[@]}")
    join_words__40_v0 ret_get_installed_desktop_runtimes327_v0__93_32[@]
    local ret_join_words40_v0__93_21="${ret_join_words40_v0}"
    local installed_3145="${ret_join_words40_v0__93_21}"
    has_desktop_runtime_channel__328_v0 "${channel_3144}"
    local ret_has_desktop_runtime_channel328_v0__95_12="${ret_has_desktop_runtime_channel328_v0}"
    if [ "$(( ! ret_has_desktop_runtime_channel328_v0__95_12 ))" != 0 ]; then
        if [ "$([ "_${installed_3145}" != "_" ]; echo $?)" != 0 ]; then
            installed_3145="none"
        fi
        log_error__3_v0 "Error: .NET ${channel_3144} Desktop Runtime is missing from the prefix after installation."
        echo "  * Expected: ${__CYAN_4}Microsoft.WindowsDesktop.App ${channel_3144}.x${__NC_6}"
        echo "  * Present:  ${__YELLOW_3}${installed_3145}${__NC_6}"
        printf '%s\n' "${__YELLOW_3}The installer ran but wrote nothing usable. This is normally a broken wine${__NC_6}"
        printf '%s\n' "${__YELLOW_3}environment -- try re-running with ${__CYAN_4}--runtime host${__YELLOW_3} or ${__CYAN_4}--runtime container${__YELLOW_3}.${__NC_6}"
        exit 1
    fi
    log_success__1_v0 ".NET Desktop Runtime verified in prefix: ${installed_3145}"
}

# install_dotnet_runtime()
install_dotnet_runtime__330_v0() {
    get_required_dotnet_channel__325_v0 ""
    local ret_get_required_dotnet_channel325_v0__111_19="${ret_get_required_dotnet_channel325_v0}"
    local channel_3137="${ret_get_required_dotnet_channel325_v0__111_19}"
    if [ "$([ "_${channel_3137}" == "_" ]; echo $?)" != 0 ]; then
        log_info__0_v0 "VRCOSC requires the .NET ${channel_3137} Desktop Runtime (from VRCOSC.runtimeconfig.json)."
    else
        channel_3137="${__DEFAULT_DOTNET_CHANNEL_9}"
        log_warn__2_v0 "Could not read the required runtime from VRCOSC.runtimeconfig.json; assuming .NET ${channel_3137}."
    fi
    local installed_dotnet_3138="${__VRC_COMPATDATA_32}/pfx/drive_c/Program Files/dotnet/dotnet.exe"
    file_exists__23_v0 "${installed_dotnet_3138}"
    local ret_file_exists23_v0__120_8="${ret_file_exists23_v0}"
    has_desktop_runtime_channel__328_v0 "${channel_3137}"
    local ret_has_desktop_runtime_channel328_v0__120_42="${ret_has_desktop_runtime_channel328_v0}"
    if [ "$(( $(( ret_file_exists23_v0__120_8 && ret_has_desktop_runtime_channel328_v0__120_42 )) && $(( ! __FORCE_INSTALL_24 )) ))" != 0 ]; then
        log_success__1_v0 ".NET ${channel_3137} Desktop Runtime already present in prefix. Skipping download (use -f/--force to reinstall)."
        ret_install_dotnet_runtime330_v0=''
        return 0
    fi
    file_exists__23_v0 "${installed_dotnet_3138}"
    local ret_file_exists23_v0__125_8="${ret_file_exists23_v0}"
    has_desktop_runtime_channel__328_v0 "${channel_3137}"
    local ret_has_desktop_runtime_channel328_v0__125_46="${ret_has_desktop_runtime_channel328_v0}"
    if [ "$(( ret_file_exists23_v0__125_8 && $(( ! ret_has_desktop_runtime_channel328_v0__125_46 )) ))" != 0 ]; then
        get_installed_desktop_runtimes__327_v0 
        local ret_get_installed_desktop_runtimes327_v0__126_34=("${ret_get_installed_desktop_runtimes327_v0[@]}")
        join_words__40_v0 ret_get_installed_desktop_runtimes327_v0__126_34[@]
        local ret_join_words40_v0__126_23="${ret_join_words40_v0}"
        local present_3139="${ret_join_words40_v0__126_23}"
        if [ "$([ "_${present_3139}" != "_" ]; echo $?)" != 0 ]; then
            present_3139="none"
        fi
        log_warn__2_v0 "Prefix has .NET Desktop Runtime(s) [${present_3139}] but VRCOSC needs ${channel_3137}.x -- installing it alongside."
    fi
    log_info__0_v0 "Fetching latest .NET ${channel_3137} Desktop Runtime download URL..."
    # builds.dotnet.microsoft.com is the host Microsoft's January 2025 notice moved
    # this metadata to; the blob host still answers, so it stays as a fallback
    # rather than being the only way in.
    local releases_json_3140=""
    local array_118=("builds.dotnet.microsoft.com" "dotnetcli.blob.core.windows.net")
    for meta_host_3141 in "${array_118[@]}"; do
        local command_119
        command_119="$(curl -fsS --connect-timeout 10 "https://${meta_host_3141}/dotnet/release-metadata/${channel_3137}/releases.json" 2>/dev/null)"
        __status=$?
        releases_json_3140="${command_119}"
        if [ "$([ "_${releases_json_3140}" == "_" ]; echo $?)" != 0 ]; then
            break
        fi
    done
    local command_120
    command_120="$(grep -o 'https://[^"]*windowsdesktop-runtime-[0-9.]*-win-x64.exe' <<< "${releases_json_3140}" | head -n 1)"
    __status=$?
    local dotnet_url_3142="${command_120}"
    if [ "$([ "_${dotnet_url_3142}" != "_" ]; echo $?)" != 0 ]; then
        if [ "${__DRY_RUN_28}" != 0 ]; then
            log_warn__2_v0 "Dry run: could not reach the .NET release metadata; skipping runtime install."
            ret_install_dotnet_runtime330_v0=''
            return 0
        fi
        log_error__3_v0 "Error: Failed to fetch the .NET ${channel_3137} Desktop Runtime download URL."
        printf '%s\n' "${__YELLOW_3}Check your network, and that channel ${channel_3137} exists at${__NC_6}"
        echo "  ${__CYAN_4}https://builds.dotnet.microsoft.com/dotnet/release-metadata/${__NC_6}"
        exit 1
    fi
    log_info__0_v0 "Downloading .NET ${channel_3137} from: ${dotnet_url_3142}"
    # Name the installer after its channel: self-describing if it is ever left
    # behind, and it lets tests assert which runtime was actually requested.
    local dotnet_installer_3143="${__VRC_COMPATDATA_32}/pfx/drive_c/windowsdesktop-runtime-${channel_3137}.exe"
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_install_dotnet_runtime330_v0=''
        return 0
    fi
    # -f, or curl exits 0 on a 404 and writes the error page. Handing wine an HTML
    # file produces a failure that looks nothing like "the download 404'd".
    curl -fL -o "${dotnet_installer_3143}" "${dotnet_url_3142}"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_dotnet_runtime330_v0=''
        return "${__status}"
    fi
    log_info__0_v0 "Installing .NET ${channel_3137} Desktop Runtime in VRChat prefix..."
    run_in_prefix__243_v0 "wine C:/windowsdesktop-runtime-${channel_3137}.exe /quiet /norestart"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_install_dotnet_runtime330_v0=''
        return "${__status}"
    fi
    rm -f "${dotnet_installer_3143}"
    __status=$?
    verify_dotnet_runtime__329_v0 "${channel_3137}"
}

# Release channel settings.
# 
# Only the install directory is per-channel; settings, profiles and package
# records are shared (AppManager.APP_NAME is "VRCOSC" for every Release build).
# So installing the other channel hands the new app the old one's state, and
# three parts of that state are wrong for it. See docs/channel-switching.md.
# UpdateChannel as VRCOSC's enum stores it (VRCOSC.App/Updater/UpdateChannel.cs).
# channel_value_for_branch(branch: Text)
channel_value_for_branch__342_v0() {
    local branch_3147="${1}"
    local b_3148="${branch_3147}"
    if [ "$([ "_${b_3148}" != "_" ]; echo $?)" != 0 ]; then
        b_3148="${__VRCOSC_BRANCH_23}"
    fi
    if [ "$([ "_${b_3148}" != "_beta" ]; echo $?)" != 0 ]; then
        ret_channel_value_for_branch342_v0=1
        return 0
    fi
    ret_channel_value_for_branch342_v0=0
    return 0
}

# The channel the existing settings claim, or empty when there is no settings
# file yet -- which is a first install, not a switch.
# read_configured_channel(cfg: Text)
read_configured_channel__343_v0() {
    local cfg_3153="${1}"
    file_exists__23_v0 "${cfg_3153}"
    local ret_file_exists23_v0__28_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__28_12 ))" != 0 ]; then
        ret_read_configured_channel343_v0=""
        return 0
    fi
    have_cmd__18_v0 "python3"
    local ret_have_cmd18_v0__32_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__32_8}" != 0 ]; then
        local command_121
        command_121="$({ python3 - "${cfg_3153}" <<'PY' 2>/dev/null
import json, sys
with open(sys.argv[1]) as fh:
    v = json.load(fh).get("settings", {}).get("UpdateChannel")
if isinstance(v, bool) or not isinstance(v, int):
    sys.exit(1)
print(v)
PY
        })"
        __status=$?
        local parsed_3154="${command_121}"
        if [ "$(( __status == 0 ))" != 0 ]; then
            ret_read_configured_channel343_v0="${parsed_3154}"
            return 0
        fi
    fi
    local command_122
    command_122="$(grep -oE '"UpdateChannel"[[:space:]]*:[[:space:]]*[0-9]+' "${cfg_3153}" 2>/dev/null | head -n 1 | grep -oE '[0-9]+$')"
    __status=$?
    ret_read_configured_channel343_v0="${command_122}"
    return 0
}

# Writes UpdateChannel, and AllowPreReleasePackages when a value is given.
# VRCOSC merges the file over its defaults, so a file carrying only these keys
# is enough -- but `version` must match or the app ignores the file entirely.
# write_channel_settings(cfg: Text, channel: Int, prerelease: Text)
write_channel_settings__344_v0() {
    local cfg_3158="${1}"
    local channel_3159="${2}"
    local prerelease_3160="${3}"
    dirname__27_v0 "${cfg_3158}"
    local ret_dirname27_v0__54_13="${ret_dirname27_v0}"
    mkdir_p__32_v0 "${ret_dirname27_v0__54_13}"
    local ret_mkdir_p32_v0__54_5="${ret_mkdir_p32_v0}"
    file_exists__23_v0 "${cfg_3158}"
    local ret_file_exists23_v0__56_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__56_12 ))" != 0 ]; then
        if [ "$([ "_${prerelease_3160}" == "_" ]; echo $?)" != 0 ]; then
            printf '{
  "settings": {
    "UpdateChannel": %s,
    "AllowPreReleasePackages": %s
  },
  "metadata": {},
  "version": 1
}
' "${channel_3159}" "${prerelease_3160}" > "${cfg_3158}"
            __status=$?
        else
            printf '{
  "settings": {
    "UpdateChannel": %s
  },
  "metadata": {},
  "version": 1
}
' "${channel_3159}" > "${cfg_3158}"
            __status=$?
        fi
        ret_write_channel_settings344_v0="$(( __status == 0 ))"
        return 0
    fi
    have_cmd__18_v0 "python3"
    local ret_have_cmd18_v0__65_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__65_8}" != 0 ]; then
        { python3 - "${cfg_3158}" "${channel_3159}" "${prerelease_3160}" <<'PY'
import json, sys
path, channel, prerelease = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(path) as fh:
    doc = json.load(fh)
settings = doc.setdefault("settings", {})
settings["UpdateChannel"] = channel
if prerelease:
    settings["AllowPreReleasePackages"] = prerelease == "true"
with open(path, "w") as fh:
    json.dump(doc, fh, indent=2)
PY
        } >/dev/null 2>&1
        __status=$?
        if [ "$(( __status == 0 ))" != 0 ]; then
            ret_write_channel_settings344_v0=1
            return 0
        fi
    fi
    # Without python3 the keys can only be edited where they already exist.
    local edited_3161=0
    grep -q '"UpdateChannel"' "${cfg_3158}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status == 0 ))" != 0 ]; then
        sed -i "s/\"UpdateChannel\"[[:space:]]*:[[:space:]]*[0-9]*/\"UpdateChannel\": ${channel_3159}/" "${cfg_3158}"
        __status=$?
        edited_3161=1
    fi
    if [ "$([ "_${prerelease_3160}" == "_" ]; echo $?)" != 0 ]; then
        grep -q '"AllowPreReleasePackages"' "${cfg_3158}">/dev/null 2>&1
        __status=$?
        if [ "$(( __status == 0 ))" != 0 ]; then
            sed -i "s/\"AllowPreReleasePackages\"[[:space:]]*:[[:space:]]*\(true\|false\)/\"AllowPreReleasePackages\": ${prerelease_3160}/" "${cfg_3158}"
            __status=$?
            edited_3161=1
        fi
    fi
    ret_write_channel_settings344_v0="${edited_3161}"
    return 0
}

# A package's recorded version belongs to the SDK line of the channel that
# installed it, so after a switch packages.json reports modules as installed
# whose DLLs will not load. Deleting it forces a clean re-resolve; the names are
# printed first because that list is the only record of what to reinstall.
# invalidate_package_cache(dir: Text)
invalidate_package_cache__345_v0() {
    local dir_3162="${1}"
    local packages_3163="${dir_3162}/configuration/packages.json"
    file_exists__23_v0 "${packages_3163}"
    local ret_file_exists23_v0__107_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__107_12 ))" != 0 ]; then
        ret_invalidate_package_cache345_v0=''
        return 0
    fi
    # The file's shape, read off a real one rather than assumed:
    # {"installed": [{"package_id": "...", "version": "..."}], "cache": [...],
    # "cache_expire_time": "...", "version": 1}
    # Only "installed" is what the user actually has; "cache" is the remote
    # catalogue, which is not what anyone needs to reinstall.
    local names_3164=""
    have_cmd__18_v0 "python3"
    local ret_have_cmd18_v0__117_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__117_8}" != 0 ]; then
        local command_123
        command_123="$({ python3 - "${packages_3163}" <<'PYPKG' 2>/dev/null || true
import json, sys
with open(sys.argv[1]) as fh:
    doc = json.load(fh)
if isinstance(doc, dict):
    for entry in doc.get("installed") or []:
        if isinstance(entry, dict) and entry.get("package_id"):
            print(entry["package_id"], entry.get("version", ""))
        elif isinstance(entry, str):
            print(entry)
PYPKG
        })"
        __status=$?
        names_3164="${command_123}"
    fi
    # Fall back to grep whenever that produced nothing -- python3 missing, python3
    # present but broken, or a file shaped differently than expected. This list is
    # the only record of what to reinstall and it is about to be deleted, so it is
    # worth a second attempt rather than a condition on why the first one failed.
    if [ "$([ "_${names_3164}" != "_" ]; echo $?)" != 0 ]; then
        local command_124
        command_124="$(grep -o '"package_id"[[:space:]]*:[[:space:]]*"[^"]*"' "${packages_3163}" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')"
        __status=$?
        names_3164="${command_124}"
    fi
    if [ "${__DRY_RUN_28}" != 0 ]; then
        log_info__0_v0 "Would delete ${packages_3163} (channel changed)"
        ret_invalidate_package_cache345_v0=''
        return 0
    fi
    if [ "$([ "_${names_3164}" == "_" ]; echo $?)" != 0 ]; then
        log_warn__2_v0 "These packages were installed for the other channel and must be"
        log_warn__2_v0 "reinstalled from the Packages tab:"
        nonempty_lines__21_v0 "${names_3164}"
        local ret_nonempty_lines21_v0__148_21=("${ret_nonempty_lines21_v0[@]}")
        for line_3165 in "${ret_nonempty_lines21_v0__148_21[@]}"; do
            echo "  * ${line_3165}"
        done
    fi
    rm -f "${packages_3163}"
    __status=$?
    log_success__1_v0 "Cleared the package cache so it re-resolves for this channel."
}

# Brings the shared settings in line with the branch being installed.
# apply_channel_settings()
apply_channel_settings__346_v0() {
    get_vrcosc_config_dirs__294_v0 
    local ret_get_vrcosc_config_dirs294_v0__159_18=("${ret_get_vrcosc_config_dirs294_v0[@]}")
    local dirs_3146=("${ret_get_vrcosc_config_dirs294_v0__159_18[@]}")
    channel_value_for_branch__342_v0 "${__VRCOSC_BRANCH_23}"
    local ret_channel_value_for_branch342_v0__160_21="${ret_channel_value_for_branch342_v0}"
    local channel_3149="${ret_channel_value_for_branch342_v0__160_21}"
    vrcosc_is_running__248_v0 
    local ret_vrcosc_is_running248_v0__162_8="${ret_vrcosc_is_running248_v0}"
    if [ "${ret_vrcosc_is_running248_v0__162_8}" != 0 ]; then
        log_warn__2_v0 "VRCOSC is running; it rewrites its settings on exit, so anything"
        log_warn__2_v0 "written now would be discarded. Close it and run the installer again"
        log_warn__2_v0 "to have the update channel set for you, or set it yourself in Settings."
        ret_apply_channel_settings346_v0=''
        return 0
    fi
    local __length_127=("${dirs_3146[@]}")
    if [ "$(( ${#__length_127[@]} == 0 ))" != 0 ]; then
        if [ "$([ "_${__VRCOSC_BRANCH_23}" != "_beta" ]; echo $?)" != 0 ]; then
            log_warn__2_v0 "No settings file yet; enable 'Allow Pre-Release Packages' and set the"
            log_warn__2_v0 "update channel to Beta in VRCOSC's settings after its first run."
        fi
        ret_apply_channel_settings346_v0=''
        return 0
    fi
    for d_3151 in "${dirs_3146[@]}"; do
        local cfg_3152="${d_3151}/configuration/settings.json"
        read_configured_channel__343_v0 "${cfg_3152}"
        local ret_read_configured_channel343_v0__179_26="${ret_read_configured_channel343_v0}"
        local previous_3155="${ret_read_configured_channel343_v0__179_26}"
        local switched_3156
        switched_3156="$(( $([ "_${previous_3155}" == "_" ]; echo $?) && $([ "_${previous_3155}" == "_${channel_3149}" ]; echo $?) ))"
        # Beta needs pre-releases visible, since every module built against a beta
        # SDK ships as one. Live only has them forced off when switching back from
        # beta: on a plain live install the setting may have been turned on
        # deliberately, and overriding that on every run is not ours to do.
        local prerelease_3157=""
        if [ "$([ "_${__VRCOSC_BRANCH_23}" != "_beta" ]; echo $?)" != 0 ]; then
            prerelease_3157="true"
        elif [ "${switched_3156}" != 0 ]; then
            prerelease_3157="false"
        fi
        write_channel_settings__344_v0 "${cfg_3152}" "${channel_3149}" "${prerelease_3157}"
        local ret_write_channel_settings344_v0__200_13="${ret_write_channel_settings344_v0}"
        if [ "${__DRY_RUN_28}" != 0 ]; then
            log_info__0_v0 "Would set update channel to ${__VRCOSC_BRANCH_23} in ${cfg_3152}"
            if [ "$([ "_${prerelease_3157}" == "_" ]; echo $?)" != 0 ]; then
                log_info__0_v0 "Would set pre-release packages to ${prerelease_3157} in ${cfg_3152}"
            fi
        elif [ "${ret_write_channel_settings344_v0__200_13}" != 0 ]; then
            log_success__1_v0 "Update channel set to ${__VRCOSC_BRANCH_23} (${cfg_3152})."
            if [ "$([ "_${prerelease_3157}" != "_true" ]; echo $?)" != 0 ]; then
                log_success__1_v0 "Enabled pre-release packages for beta (${cfg_3152})."
            elif [ "$([ "_${prerelease_3157}" != "_false" ]; echo $?)" != 0 ]; then
                log_success__1_v0 "Disabled pre-release packages for live (${cfg_3152})."
            fi
        else
            log_warn__2_v0 "Could not edit ${cfg_3152}; set 'Update Channel' to ${__VRCOSC_BRANCH_23} in VRCOSC's settings."
        fi
        if [ "${switched_3156}" != 0 ]; then
            log_warn__2_v0 "Channel changed; the installed packages belong to the other channel."
            invalidate_package_cache__345_v0 "${d_3151}"
        fi
    done
}

# The OSC and OSCQuery mDNS ports: reporting what the firewall says and, unless
# told not to, opening them.
array_130=("9000" "9001" "5353")
__OSC_PORTS_122=("${array_130[@]}")
# True when passwordless sudo is available right now.
# can_sudo()
can_sudo__353_v0() {
    sudo -n true>/dev/null 2>&1
    __status=$?
    ret_can_sudo353_v0="$(( __status == 0 ))"
    return 0
}

# Uninstall does not close the OSC ports. Removing a firewall rule this installer
# may not have added, on a machine where something else may now depend on it, is
# not a safe thing to do unprompted -- but leaving it unmentioned would make
# "cleanly remove" untrue. So: say what is still open and how to close it.
# report_firewall_rules_on_uninstall()
report_firewall_rules_on_uninstall__354_v0() {
    have_cmd__18_v0 "firewall-cmd"
    local ret_have_cmd18_v0__21_12="${ret_have_cmd18_v0}"
    if [ "$(( ! ret_have_cmd18_v0__21_12 ))" != 0 ]; then
        ret_report_firewall_rules_on_uninstall354_v0=''
        return 0
    fi
    local command_131
    command_131="$(sudo -n firewall-cmd --list-ports 2>/dev/null || firewall-cmd --list-ports 2>/dev/null || true)"
    __status=$?
    local out_3086="${command_131}"
    matches__36_v0 "${out_3086}" "9000|9001|5353"
    local ret_matches36_v0__25_12="${ret_matches36_v0}"
    if [ "$(( ! ret_matches36_v0__25_12 ))" != 0 ]; then
        ret_report_firewall_rules_on_uninstall354_v0=''
        return 0
    fi
    log_warn__2_v0 "The OSC ports are still open in your firewall: ${out_3086}"
    log_warn__2_v0 "They are left alone because something else may now rely on them. To close:"
    echo "  ${__CYAN_4}sudo firewall-cmd --permanent --remove-port=9000-9001/udp --remove-port=5353/udp && sudo firewall-cmd --reload${__NC_6}"
}

# Report whatever the firewall already says about the OSC ports. This is the whole
# of --no-firewall's job: someone who does not want the installer touching their
# firewall still needs to know whether the ports are open, because a blocked 9001
# looks exactly like VRCOSC not working.
# report_firewall_rules()
report_firewall_rules__355_v0() {
    local found_3166=0
    have_cmd__18_v0 "firewall-cmd"
    local ret_have_cmd18_v0__41_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__41_8}" != 0 ]; then
        local command_132
        command_132="$(sudo -n firewall-cmd --list-all 2>/dev/null || firewall-cmd --list-all 2>/dev/null || true)"
        __status=$?
        local out_3167="${command_132}"
        if [ "$([ "_${out_3167}" == "_" ]; echo $?)" != 0 ]; then
            local command_133
            command_133="$(head -n 1 <<< "${out_3167}" | awk '{print $1}')"
            __status=$?
            local zone_3168="${command_133}"
            local command_134
            command_134="$(grep -E '^\s*ports:' <<< "${out_3167}" | sed 's/^\s*ports:\s*//')"
            __status=$?
            local ports_3169="${command_134}"
            local command_135
            command_135="$(grep -E '^\s*services:' <<< "${out_3167}" | sed 's/^\s*services:\s*//')"
            __status=$?
            local services_3170="${command_135}"
            if [ "$([ "_${zone_3168}" != "_" ]; echo $?)" != 0 ]; then
                zone_3168="unknown"
            fi
            echo "  * firewalld zone:      ${__CYAN_4}${zone_3168}${__NC_6}"
            echo "  * open udp ports:      ${__CYAN_4}$(if [ "$([ "_${ports_3169}" == "_" ]; echo $?)" != 0 ]; then echo "${ports_3169}"; else echo "none"; fi)${__NC_6}"
            if [ "$([ "_${services_3170}" == "_" ]; echo $?)" != 0 ]; then
                echo "  * services:            ${__CYAN_4}${services_3170}${__NC_6}"
            fi
            for p_3171 in "${__OSC_PORTS_122[@]}"; do
                matches__36_v0 "${ports_3169}" "(^|[[:space:]])${p_3171}/udp"
                local ret_matches36_v0__57_21="${ret_matches36_v0}"
                matches__36_v0 "${ports_3169}" "[0-9]+-[0-9]+/udp"
                local ret_matches36_v0__60_21="${ret_matches36_v0}"
                if [ "${ret_matches36_v0__57_21}" != 0 ]; then
                    echo "  * ${p_3171}/udp:            ${__GREEN_1}explicitly allowed${__NC_6}"
                elif [ "${ret_matches36_v0__60_21}" != 0 ]; then
                    echo "  * ${p_3171}/udp:            ${__CYAN_4}may be covered by a port range above${__NC_6}"
                else
                    echo "  * ${p_3171}/udp:            ${__YELLOW_3}not listed${__NC_6}"
                fi
            done
            found_3166=1
        fi
    fi
    have_cmd__18_v0 "ufw"
    local ret_have_cmd18_v0__72_22="${ret_have_cmd18_v0}"
    if [ "$(( $(( ! found_3166 )) && ret_have_cmd18_v0__72_22 ))" != 0 ]; then
        local command_138
        command_138="$(sudo -n ufw status 2>/dev/null || true)"
        __status=$?
        local out_3172="${command_138}"
        if [ "$([ "_${out_3172}" == "_" ]; echo $?)" != 0 ]; then
            local command_139
            command_139="$(head -n 1 <<< "${out_3172}")"
            __status=$?
            echo "  * ufw:                 ${__CYAN_4}${command_139}${__NC_6}"
            local command_140
            command_140="$(grep -E '9000|9001|5353' <<< "${out_3172}" | sed 's/^/      /')"
            __status=$?
            local rules_3173="${command_140}"
            if [ "$([ "_${rules_3173}" == "_" ]; echo $?)" != 0 ]; then
                printf '%s\n' "${rules_3173}"
            else
                echo "      ${__YELLOW_3}no rules for 9000, 9001 or 5353${__NC_6}"
            fi
            found_3166=1
        fi
    fi
    have_cmd__18_v0 "iptables"
    local ret_have_cmd18_v0__86_22="${ret_have_cmd18_v0}"
    if [ "$(( $(( ! found_3166 )) && ret_have_cmd18_v0__86_22 ))" != 0 ]; then
        local command_141
        command_141="$(sudo -n iptables -S INPUT 2>/dev/null | grep -E 'dport (9000|9001|5353)' || true)"
        __status=$?
        local out_3174="${command_141}"
        if [ "$([ "_${out_3174}" == "_" ]; echo $?)" != 0 ]; then
            local command_142
            command_142="$(printf '%s
' "${out_3174}" | sed 's/^/      /')"
            __status=$?
            printf '%s\n' "${command_142}"
        else
            echo "      ${__YELLOW_3}no iptables INPUT rules for 9000, 9001 or 5353${__NC_6}"
        fi
        found_3166=1
    fi
    if [ "$(( ! found_3166 ))" != 0 ]; then
        # Naming the ports even here: someone reading this output is trying to work
        # out whether a port is blocked, and "no tool found" alone does not tell
        # them which ports they would have to check by hand.
        echo "  * ${__YELLOW_3}no firewall tool found to inspect (firewall-cmd, ufw, iptables)${__NC_6}"
        echo "      ${__YELLOW_3}9000/udp, 9001/udp and 5353/udp could not be checked${__NC_6}"
    fi
}

# VRChat and VRCOSC on the same machine talk over loopback, which no firewall
# rule affects. These ports are opened for the cases that do cross the network:
# OSC clients on another device, and OSCQuery's mDNS discovery. Refuse the whole
# thing with --no-firewall, which still reports what is already open.
# configure_firewall()
configure_firewall__356_v0() {
    log_info__0_v0 "Checking firewall configuration for OSC and OSCQuery mDNS ports (9000/9001/5353 UDP)..."
    report_firewall_rules__355_v0 
    if [ "${__NO_FIREWALL_29}" != 0 ]; then
        log_info__0_v0 "Not adding any firewall rules (--no-firewall)."
        ret_configure_firewall356_v0=''
        return 0
    fi
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_configure_firewall356_v0=''
        return 0
    fi
    local applied_3175=0
    have_cmd__18_v0 "firewall-cmd"
    local ret_have_cmd18_v0__124_9="${ret_have_cmd18_v0}"
    can_sudo__353_v0 
    local ret_can_sudo353_v0__124_38="${ret_can_sudo353_v0}"
    have_cmd__18_v0 "ufw"
    local ret_have_cmd18_v0__132_9="${ret_have_cmd18_v0}"
    can_sudo__353_v0 
    local ret_can_sudo353_v0__132_29="${ret_can_sudo353_v0}"
    have_cmd__18_v0 "iptables"
    local ret_have_cmd18_v0__140_9="${ret_have_cmd18_v0}"
    can_sudo__353_v0 
    local ret_can_sudo353_v0__140_34="${ret_can_sudo353_v0}"
    if [ "$(( ret_have_cmd18_v0__124_9 && ret_can_sudo353_v0__124_38 ))" != 0 ]; then
        log_info__0_v0 "Applying firewalld rules..."
        for p_3176 in "${__OSC_PORTS_122[@]}"; do
            sudo -n firewall-cmd --add-port=${p_3176}/udp --permanent>/dev/null 2>&1
            __status=$?
        done
        sudo -n firewall-cmd --reload>/dev/null 2>&1
        __status=$?
        applied_3175=1
    elif [ "$(( ret_have_cmd18_v0__132_9 && ret_can_sudo353_v0__132_29 ))" != 0 ]; then
        log_info__0_v0 "Applying UFW rules..."
        for p_3177 in "${__OSC_PORTS_122[@]}"; do
            sudo -n ufw allow ${p_3177}/udp>/dev/null 2>&1
            __status=$?
        done
        sudo -n ufw reload>/dev/null 2>&1
        __status=$?
        applied_3175=1
    elif [ "$(( ret_have_cmd18_v0__140_9 && ret_can_sudo353_v0__140_34 ))" != 0 ]; then
        log_info__0_v0 "Applying iptables rules..."
        for p_3178 in "${__OSC_PORTS_122[@]}"; do
            sudo -n iptables -I INPUT -p udp --dport ${p_3178} -j ACCEPT>/dev/null 2>&1
            __status=$?
        done
        applied_3175=1
        # Unlike the firewalld and ufw branches, these are in-memory only.
        log_warn__2_v0 "iptables rules are not persistent and will be gone after a reboot."
        log_warn__2_v0 "Save them with your distribution's iptables-persistent equivalent, or"
        log_warn__2_v0 "just run this installer again."
    fi
    if [ "$(( ! applied_3175 ))" != 0 ]; then
        log_warn__2_v0 "Note: Automatic firewall rules were skipped (root privileges required)."
        echo "If VRChat fails to auto-discover VRCOSC, manually allow UDP ports 9000, 9001, and 5353 in your firewall."
    else
        log_success__1_v0 "Firewall rules configured successfully."
    fi
}

# The application icon for the desktop entry.
# install_application_icon()
install_application_icon__365_v0() {
    log_info__0_v0 "Installing VRCOSC application icon..."
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_install_application_icon365_v0=''
        return 0
    fi
    get_app_icon_path__292_v0 
    local ret_get_app_icon_path292_v0__14_23="${ret_get_app_icon_path292_v0}"
    local icon_path_3179="${ret_get_app_icon_path292_v0__14_23}"
    dirname__27_v0 "${icon_path_3179}"
    local ret_dirname27_v0__15_13="${ret_dirname27_v0}"
    mkdir_p__32_v0 "${ret_dirname27_v0__15_13}"
    local ret_mkdir_p32_v0__15_5="${ret_mkdir_p32_v0}"
    curl -fsSL --connect-timeout 10 -o "${icon_path_3179}" "${__ICON_URL_10}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        log_warn__2_v0 "Could not download the application icon; the desktop entry will use a fallback."
        rm -f "${icon_path_3179}"
        __status=$?
        ret_install_application_icon365_v0=''
        return 0
    fi
    file_exists__23_v0 "${icon_path_3179}"
    local ret_file_exists23_v0__22_8="${ret_file_exists23_v0}"
    if [ "${ret_file_exists23_v0__22_8}" != 0 ]; then
        log_success__1_v0 "Application icon installed: ${icon_path_3179}"
    fi
}

# The VRChat launch.exe bridge: finding the payload, patching it in and taking
# it back out again.
# True when a payload is the exact bridge this script was published with. Without
# sha256sum there is nothing to compare against, so the check passes rather than
# refusing to install on a host that simply lacks coreutils' hashing tool.
# launch_bridge_is_current(path: Text)
launch_bridge_is_current__380_v0() {
    local path_3038="${1}"
    file_exists__23_v0 "${path_3038}"
    local ret_file_exists23_v0__13_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__13_12 ))" != 0 ]; then
        ret_launch_bridge_is_current380_v0=0
        return 0
    fi
    have_cmd__18_v0 "sha256sum"
    local ret_have_cmd18_v0__16_12="${ret_have_cmd18_v0}"
    if [ "$(( ! ret_have_cmd18_v0__16_12 ))" != 0 ]; then
        ret_launch_bridge_is_current380_v0=1
        return 0
    fi
    local command_149
    command_149="$(sha256sum < "${path_3038}" | awk '{print $1}')"
    __status=$?
    ret_launch_bridge_is_current380_v0="$([ "_${command_149}" != "_${__LAUNCH_BRIDGE_SHA256_35}" ]; echo $?)"
    return 0
}

# True when a file is one of our launch bridges, of any build. The payload embeds
# this marker; VRChat's own launcher does not. Used where comparing against the
# current payload is not enough, because an older bridge differs from it byte for
# byte while behaving exactly the same way.
# is_launch_bridge(path: Text)
is_launch_bridge__381_v0() {
    local path_3077="${1}"
    file_exists__23_v0 "${path_3077}"
    local ret_file_exists23_v0__27_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__27_12 ))" != 0 ]; then
        ret_is_launch_bridge381_v0=0
        return 0
    fi
    grep -aqF 'launch_bridge_ready' "${path_3077}">/dev/null 2>&1
    __status=$?
    ret_is_launch_bridge381_v0="$(( __status == 0 ))"
    return 0
}

# Absolute path to a usable vrc-launch-bridge.exe, or empty if there is none.
# Prefers the copy beside the script, then a previously cached download, then
# fetches it -- so a piped install still gets the bridge instead of skipping it.
# Pass allow_download = false to stay offline (used by --info, which must not mutate).
# resolve_launch_bridge(allow_download: Bool)
resolve_launch_bridge__382_v0() {
    local allow_download_3035="${1}"
    get_script_dir__297_v0 
    local ret_get_script_dir297_v0__39_24="${ret_get_script_dir297_v0}"
    local script_dir_3036="${ret_get_script_dir297_v0__39_24}"
    file_exists__23_v0 "${script_dir_3036}/bin/vrc-launch-bridge.exe"
    local ret_file_exists23_v0__40_29="${ret_file_exists23_v0}"
    if [ "$(( $([ "_${script_dir_3036}" == "_" ]; echo $?) && ret_file_exists23_v0__40_29 ))" != 0 ]; then
        ret_resolve_launch_bridge382_v0="${script_dir_3036}/bin/vrc-launch-bridge.exe"
        return 0
    fi
    get_launch_bridge_cache__296_v0 
    local ret_get_launch_bridge_cache296_v0__44_19="${ret_get_launch_bridge_cache296_v0}"
    local cache_3037="${ret_get_launch_bridge_cache296_v0__44_19}"
    # A cache that matches the pinned digest is current. One that does not is from
    # an older install, and is re-fetched rather than kept forever.
    file_exists__23_v0 "${cache_3037}"
    local ret_file_exists23_v0__47_8="${ret_file_exists23_v0}"
    launch_bridge_is_current__380_v0 "${cache_3037}"
    local ret_launch_bridge_is_current380_v0__47_31="${ret_launch_bridge_is_current380_v0}"
    if [ "$(( ret_file_exists23_v0__47_8 && ret_launch_bridge_is_current380_v0__47_31 ))" != 0 ]; then
        ret_resolve_launch_bridge382_v0="${cache_3037}"
        return 0
    fi
    if [ "$(( ! allow_download_3035 ))" != 0 ]; then
        # Nothing to verify against and nothing to download: a stale cache is still
        # better than no bridge at all for read-only callers.
        file_exists__23_v0 "${cache_3037}"
        local ret_file_exists23_v0__54_12="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__54_12}" != 0 ]; then
            ret_resolve_launch_bridge382_v0="${cache_3037}"
            return 0
        fi
        ret_resolve_launch_bridge382_v0=""
        return 0
    fi
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_resolve_launch_bridge382_v0=""
        return 0
    fi
    local command_150
    command_150="$(mktemp)"
    __status=$?
    local tmp_3039="${command_150}"
    if [ "$(( __status != 0 ))" != 0 ]; then
        ret_resolve_launch_bridge382_v0=""
        return 0
    fi
    local got_3040=0
    for url_3041 in "${__LAUNCH_BRIDGE_URLS_13[@]}"; do
        curl -fsSL --connect-timeout 10 -o "${tmp_3039}" "${url_3041}">/dev/null 2>&1
        __status=$?
        if [ "$(( __status != 0 ))" != 0 ]; then
            continue
        fi
        # A rate-limit page or an HTML error body is not a PE binary; refuse it
        # rather than installing garbage over VRChat's launcher.
        head_bytes__31_v0 "${tmp_3039}" 2
        local ret_head_bytes31_v0__75_12="${ret_head_bytes31_v0}"
        if [ "$([ "_${ret_head_bytes31_v0__75_12}" == "_MZ" ]; echo $?)" != 0 ]; then
            continue
        fi
        # Pages can serve a build behind main, so a payload that is not the one
        # this script was published with means try the next source.
        launch_bridge_is_current__380_v0 "${tmp_3039}"
        local ret_launch_bridge_is_current380_v0__80_16="${ret_launch_bridge_is_current380_v0}"
        if [ "$(( ! ret_launch_bridge_is_current380_v0__80_16 ))" != 0 ]; then
            continue
        fi
        got_3040=1
        break
    done
    # Every source disagreed with the pinned digest. A stale cache still works;
    # preferring it over nothing keeps vrchat:// navigation alive.
    if [ "$(( ! got_3040 ))" != 0 ]; then
        rm -f "${tmp_3039}"
        __status=$?
        file_exists__23_v0 "${cache_3037}"
        local ret_file_exists23_v0__91_12="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__91_12}" != 0 ]; then
            ret_resolve_launch_bridge382_v0="${cache_3037}"
            return 0
        fi
        ret_resolve_launch_bridge382_v0=""
        return 0
    fi
    dirname__27_v0 "${cache_3037}"
    local ret_dirname27_v0__96_20="${ret_dirname27_v0}"
    mkdir_p__32_v0 "${ret_dirname27_v0__96_20}"
    local ret_mkdir_p32_v0__96_12="${ret_mkdir_p32_v0}"
    if [ "$(( ! ret_mkdir_p32_v0__96_12 ))" != 0 ]; then
        rm -f "${tmp_3039}"
        __status=$?
        ret_resolve_launch_bridge382_v0=""
        return 0
    fi
    mv "${tmp_3039}" "${cache_3037}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        rm -f "${tmp_3039}"
        __status=$?
        ret_resolve_launch_bridge382_v0=""
        return 0
    fi
    chmod 644 "${cache_3037}"
    __status=$?
    ret_resolve_launch_bridge382_v0="${cache_3037}"
    return 0
}

# Copy the resolved bridge into its cache location, so the generated launcher
# has one stable path to re-patch from even if the checkout is deleted later.
# Returns the cached path, or empty if there is no payload to stage.
# stage_launch_bridge()
stage_launch_bridge__383_v0() {
    resolve_launch_bridge__382_v0 1
    local ret_resolve_launch_bridge382_v0__113_17="${ret_resolve_launch_bridge382_v0}"
    local src_3183="${ret_resolve_launch_bridge382_v0__113_17}"
    if [ "$([ "_${src_3183}" != "_" ]; echo $?)" != 0 ]; then
        ret_stage_launch_bridge383_v0=""
        return 0
    fi
    get_launch_bridge_cache__296_v0 
    local ret_get_launch_bridge_cache296_v0__117_19="${ret_get_launch_bridge_cache296_v0}"
    local cache_3184="${ret_get_launch_bridge_cache296_v0__117_19}"
    if [ "$([ "_${src_3183}" == "_${cache_3184}" ]; echo $?)" != 0 ]; then
        dirname__27_v0 "${cache_3184}"
        local ret_dirname27_v0__119_24="${ret_dirname27_v0}"
        mkdir_p__32_v0 "${ret_dirname27_v0__119_24}"
        local ret_mkdir_p32_v0__119_16="${ret_mkdir_p32_v0}"
        if [ "$(( ! ret_mkdir_p32_v0__119_16 ))" != 0 ]; then
            ret_stage_launch_bridge383_v0=""
            return 0
        fi
        cp -f "${src_3183}" "${cache_3184}">/dev/null 2>&1
        __status=$?
        if [ "$(( __status != 0 ))" != 0 ]; then
            ret_stage_launch_bridge383_v0=""
            return 0
        fi
        chmod 644 "${cache_3184}">/dev/null 2>&1
        __status=$?
    fi
    ret_stage_launch_bridge383_v0="${cache_3184}"
    return 0
}

# patch_vrchat_launch_bridge()
patch_vrchat_launch_bridge__384_v0() {
    # Refusable: this writes into VRChat's own install directory. The game works
    # without it; only vrchat:// navigation from VRCOSC and companion tools needs
    # the bridge.
    if [ "$(( ! __PATCH_LAUNCH_30 ))" != 0 ]; then
        log_info__0_v0 "Leaving VRChat's launch.exe alone (--no-patch)."
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    log_info__0_v0 "Checking VRChat launch.exe for Linux IPC named-pipe bridge patch..."
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    get_vrchat_game_dir__295_v0 
    local ret_get_vrchat_game_dir295_v0__144_26="${ret_get_vrchat_game_dir295_v0}"
    local vrc_game_dir_3180="${ret_get_vrchat_game_dir295_v0__144_26}"
    local target_launch_3181="${vrc_game_dir_3180}/launch.exe"
    local backup_launch_3182="${vrc_game_dir_3180}/launch.org.exe"
    dir_exists__24_v0 "${vrc_game_dir_3180}"
    local ret_dir_exists24_v0__148_12="${ret_dir_exists24_v0}"
    if [ "$(( ! ret_dir_exists24_v0__148_12 ))" != 0 ]; then
        log_warn__2_v0 "VRChat game directory not found (${vrc_game_dir_3180}). Skipping launch.exe patch."
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    stage_launch_bridge__383_v0 
    local ret_stage_launch_bridge383_v0__153_27="${ret_stage_launch_bridge383_v0}"
    local source_bridge_3185="${ret_stage_launch_bridge383_v0__153_27}"
    if [ "$([ "_${source_bridge_3185}" != "_" ]; echo $?)" != 0 ]; then
        log_warn__2_v0 "Could not obtain vrc-launch-bridge.exe (no local copy and the download failed). Skipping patch."
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    # Already patched? Check before touching the backup. Backing up a launch.exe
    # that is already the bridge would make the bridge its own fallback, and
    # RunOriginal() starting launch.org.exe would then re-enter the bridge with no
    # bound -- every time the pipe is unavailable, i.e. whenever VRChat is closed.
    files_identical__299_v0 "${source_bridge_3185}" "${target_launch_3181}"
    local ret_files_identical299_v0__163_8="${ret_files_identical299_v0}"
    if [ "${ret_files_identical299_v0__163_8}" != 0 ]; then
        log_success__1_v0 "VRChat launch.exe is already patched with the Linux IPC bridge."
        chmod 555 "${target_launch_3181}">/dev/null 2>&1
        __status=$?
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    # Backup original launch.exe if launch.org.exe does not exist
    file_exists__23_v0 "${backup_launch_3182}"
    local ret_file_exists23_v0__171_13="${ret_file_exists23_v0}"
    file_exists__23_v0 "${target_launch_3181}"
    local ret_file_exists23_v0__187_9="${ret_file_exists23_v0}"
    is_launch_bridge__381_v0 "${target_launch_3181}"
    local ret_is_launch_bridge381_v0__187_44="${ret_is_launch_bridge381_v0}"
    files_identical__299_v0 "${target_launch_3181}" "${backup_launch_3182}"
    local ret_files_identical299_v0__187_84="${ret_files_identical299_v0}"
    if [ "$(( ! ret_file_exists23_v0__171_13 ))" != 0 ]; then
        file_exists__23_v0 "${target_launch_3181}"
        local ret_file_exists23_v0__172_16="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__172_16}" != 0 ]; then
            # files_identical above only compared against the bridge we are about to
            # install. An older bridge build differs from it byte for byte and would
            # still recurse, so check for the payload's own marker as well.
            is_launch_bridge__381_v0 "${target_launch_3181}"
            local ret_is_launch_bridge381_v0__176_20="${ret_is_launch_bridge381_v0}"
            if [ "${ret_is_launch_bridge381_v0__176_20}" != 0 ]; then
                log_warn__2_v0 "launch.exe is already a launch bridge but launch.org.exe is missing,"
                log_warn__2_v0 "so there is no stock launcher to fall back on. Use Steam's"
                log_warn__2_v0 "'Verify integrity of game files' on VRChat, then run this again."
                ret_patch_vrchat_launch_bridge384_v0=''
                return 0
            fi
            log_info__0_v0 "Creating read-only backup of original launch.exe -> launch.org.exe..."
            cp -p "${target_launch_3181}" "${backup_launch_3182}"
            __status=$?
            chmod 444 "${backup_launch_3182}"
            __status=$?
        fi
    elif [ "$(( $(( ret_file_exists23_v0__187_9 && $(( ! ret_is_launch_bridge381_v0__187_44 )) )) && $(( ! ret_files_identical299_v0__187_84 )) ))" != 0 ]; then
        # Steam has restored a launch.exe that is neither our bridge nor the one we
        # backed up, i.e. VRChat updated. Refreshing the backup keeps the bridge's
        # fallback on the current stock launcher instead of an older one.
        log_info__0_v0 "VRChat's launch.exe changed; refreshing launch.org.exe from it."
        chmod 644 "${backup_launch_3182}">/dev/null 2>&1
        __status=$?
        cp -p "${target_launch_3181}" "${backup_launch_3182}"
        __status=$?
        chmod 444 "${backup_launch_3182}"
        __status=$?
    fi
    log_info__0_v0 "Installing Linux IPC launch.exe wrapper into VRChat directory..."
    # Stage beside the target and rename over it, so a failed copy cannot leave
    # VRChat with no launch.exe at all. Same filesystem, so the mv is atomic.
    local command_153
    command_153="$(printf '%s' "$$")"
    __status=$?
    local staged_3186="${vrc_game_dir_3180}/.launch.exe.new.${command_153}"
    cp "${source_bridge_3185}" "${staged_3186}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        rm -f "${staged_3186}">/dev/null 2>&1
        __status=$?
        log_warn__2_v0 "Could not write into ${vrc_game_dir_3180}; leaving launch.exe untouched."
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    chmod 555 "${staged_3186}">/dev/null 2>&1
    __status=$?
    # The installed bridge is 555, so make it writable before the rename replaces it.
    chmod 755 "${target_launch_3181}">/dev/null 2>&1
    __status=$?
    mv -f "${staged_3186}" "${target_launch_3181}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        rm -f "${staged_3186}">/dev/null 2>&1
        __status=$?
        log_warn__2_v0 "Could not replace ${target_launch_3181}; it has been left as it was."
        ret_patch_vrchat_launch_bridge384_v0=''
        return 0
    fi
    chmod 555 "${target_launch_3181}"
    __status=$?
    log_success__1_v0 "VRChat launch.exe patched successfully (read-only 555)."
}

# Put VRChat's own launch.exe back. Only the bridge is ours to remove: if Steam
# has already restored a stock launcher, or shipped a newer one, that file stays
# and only our now-redundant backup goes. Returns true when it did something
# (or would have, under --dry-run).
# restore_vrchat_launch_bridge()
restore_vrchat_launch_bridge__385_v0() {
    get_vrchat_game_dir__295_v0 
    local ret_get_vrchat_game_dir295_v0__226_22="${ret_get_vrchat_game_dir295_v0}"
    local game_dir_3073="${ret_get_vrchat_game_dir295_v0__226_22}"
    local target_3074="${game_dir_3073}/launch.exe"
    local backup_3075="${game_dir_3073}/launch.org.exe"
    file_exists__23_v0 "${backup_3075}"
    local ret_file_exists23_v0__230_12="${ret_file_exists23_v0}"
    if [ "$(( ! ret_file_exists23_v0__230_12 ))" != 0 ]; then
        ret_restore_vrchat_launch_bridge385_v0=0
        return 0
    fi
    if [ "${__DRY_RUN_28}" != 0 ]; then
        log_info__0_v0 "Would restore ${target_3074} from launch.org.exe."
        ret_restore_vrchat_launch_bridge385_v0=1
        return 0
    fi
    resolve_launch_bridge__382_v0 0
    local ret_resolve_launch_bridge382_v0__238_21="${ret_resolve_launch_bridge382_v0}"
    local payload_3076="${ret_resolve_launch_bridge382_v0__238_21}"
    file_exists__23_v0 "${target_3074}"
    local ret_file_exists23_v0__239_8="${ret_file_exists23_v0}"
    files_identical__299_v0 "${target_3074}" "${payload_3076}"
    local ret_files_identical299_v0__239_54="${ret_files_identical299_v0}"
    if [ "$(( $(( ret_file_exists23_v0__239_8 && $([ "_${payload_3076}" == "_" ]; echo $?) )) && $(( ! ret_files_identical299_v0__239_54 )) ))" != 0 ]; then
        log_info__0_v0 "launch.exe is not our bridge; leaving it and removing the stale backup."
        rm -f "${backup_3075}"
        __status=$?
        ret_restore_vrchat_launch_bridge385_v0=1
        return 0
    fi
    files_identical__299_v0 "${target_3074}" "${backup_3075}"
    local ret_files_identical299_v0__245_8="${ret_files_identical299_v0}"
    if [ "${ret_files_identical299_v0__245_8}" != 0 ]; then
        log_info__0_v0 "launch.exe is already VRChat's own; removing the redundant backup."
        rm -f "${backup_3075}"
        __status=$?
        ret_restore_vrchat_launch_bridge385_v0=1
        return 0
    fi
    # A backup taken from an already-bridged launch.exe is not a stock launcher.
    # Restoring it would leave the bridge in place under a name that says otherwise.
    is_launch_bridge__381_v0 "${backup_3075}"
    local ret_is_launch_bridge381_v0__253_8="${ret_is_launch_bridge381_v0}"
    if [ "${ret_is_launch_bridge381_v0__253_8}" != 0 ]; then
        log_warn__2_v0 "launch.org.exe is itself a launch bridge, not VRChat's own launcher,"
        log_warn__2_v0 "so there is nothing to restore. Removing it; use Steam's 'Verify"
        log_warn__2_v0 "integrity of game files' on VRChat to get the stock launcher back."
        rm -f "${backup_3075}"
        __status=$?
        ret_restore_vrchat_launch_bridge385_v0=1
        return 0
    fi
    chmod 755 "${target_3074}">/dev/null 2>&1
    __status=$?
    rm -f "${target_3074}">/dev/null 2>&1
    __status=$?
    cp "${backup_3075}" "${target_3074}">/dev/null 2>&1
    __status=$?
    if [ "$(( __status != 0 ))" != 0 ]; then
        log_warn__2_v0 "Could not restore ${target_3074} from launch.org.exe; the backup has been left in place."
        ret_restore_vrchat_launch_bridge385_v0=0
        return 0
    fi
    chmod 755 "${target_3074}">/dev/null 2>&1
    __status=$?
    rm -f "${backup_3075}"
    __status=$?
    log_success__1_v0 "Restored VRChat's original launch.exe."
    ret_restore_vrchat_launch_bridge385_v0=1
    return 0
}

# The `vrcosc` launcher script and desktop entry the installer leaves behind.
# create_launchers()
create_launchers__399_v0() {
    log_info__0_v0 "Creating launch script and desktop entry..."
    if [ "${__DRY_RUN_28}" != 0 ]; then
        ret_create_launchers399_v0=''
        return 0
    fi
    get_launcher_script__290_v0 ""
    local ret_get_launcher_script290_v0__16_27="${ret_get_launcher_script290_v0}"
    local launch_script_3187="${ret_get_launcher_script290_v0__16_27}"
    local win_entry_3188="C:/users/steamuser/AppData/Local/VRCOSC/VRCOSC.dll"
    get_desktop_file__291_v0 ""
    local ret_get_desktop_file291_v0__18_27="${ret_get_desktop_file291_v0}"
    local desktop_entry_3189="${ret_get_desktop_file291_v0__18_27}"
    local app_name_3190="VRCOSC"
    if [ "$([ "_${__VRCOSC_BRANCH_23}" != "_beta" ]; echo $?)" != 0 ]; then
        win_entry_3188="C:/users/steamuser/AppData/Local/VRCOSC-beta/VRCOSC.dll"
        app_name_3190="VRCOSC (Beta)"
    fi
    dirname__27_v0 "${launch_script_3187}"
    local ret_dirname27_v0__26_13="${ret_dirname27_v0}"
    mkdir_p__32_v0 "${ret_dirname27_v0__26_13}"
    local ret_mkdir_p32_v0__26_5="${ret_mkdir_p32_v0}"
    # Empty unless patching is on, which makes the launcher's re-patch a no-op.
    local bridge_payload_3191=""
    if [ "${__PATCH_LAUNCH_30}" != 0 ]; then
        stage_launch_bridge__383_v0 
        local ret_stage_launch_bridge383_v0__30_26="${ret_stage_launch_bridge383_v0}"
        bridge_payload_3191="${ret_stage_launch_bridge383_v0__30_26}"
    fi
    get_vrchat_game_dir__295_v0 
    local ret_get_vrchat_game_dir295_v0__32_26="${ret_get_vrchat_game_dir295_v0}"
    local vrc_game_dir_3192="${ret_get_vrchat_game_dir295_v0__32_26}"
    local mode_3193="${__RESOLVED_RUNTIME_MODE_34}"
    if [ "$([ "_${mode_3193}" != "_" ]; echo $?)" != 0 ]; then
        mode_3193="no-bwrap"
    fi
    runtime_mode_flags__240_v0 "${mode_3193}"
    local ret_runtime_mode_flags240_v0__37_27="${ret_runtime_mode_flags240_v0}"
    local runtime_flags_3194="${ret_runtime_mode_flags240_v0__37_27}"
    scrub_arguments__241_v0 
    local ret_scrub_arguments241_v0__38_19="${ret_scrub_arguments241_v0}"
    local scrub_3195="${ret_scrub_arguments241_v0__38_19}"
    # The launcher is written in two parts. The head carries everything decided at
    # install time and is expanded here; the body is the launcher's own logic and
    # is copied through literally, so its variables are its own.
    cat << EOF_LAUNCHER_HEAD > "${launch_script_3187}"
#!/usr/bin/env bash
# VRCOSC Launcher for Linux/Proton -- generated by install.sh
set -euo pipefail

ENTRY="${win_entry_3188}"
DOTNET="C:/Program Files/dotnet/dotnet.exe"
COMPATDATA="${__VRC_COMPATDATA_32}"
PFX="\$COMPATDATA/pfx"
VRC_GAME_DIR="${vrc_game_dir_3192}"
BRIDGE_PAYLOAD="${bridge_payload_3191}"
# Drop Steam Runtime variables leaked in by the calling shell. With them set,
# wine mixes runtime libraries with host config files and fails with misleading
# errors such as 'Fontconfig error: "/etc/fonts/fonts.conf": out of memory'.
SCRUB=(${scrub_3195})
RUNTIME_FLAGS=(${runtime_flags_3194})
EOF_LAUNCHER_HEAD
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_create_launchers399_v0=''
        return "${__status}"
    fi
    cat << 'EOF_LAUNCHER_BODY' >> "${launch_script_3187}"

# --- Keep VRChat's launch.exe bridged ----------------------------------------
# Steam restores the stock launch.exe on every game update and on file
# validation, which silently breaks vrchat:// navigation until the installer is
# run again. Re-apply the patch here instead, since this runs before every
# session. Nothing is touched if the bridge is already in place.
# cmp(1) is diffutils, which minimal Fedora and Arch installs omit; a missing cmp
# would read as "differs" and re-patch on every launch.
bridge_matches() {
    [ -f "$1" ] && [ -f "$2" ] || return 1
    # Only 0 (identical) and 1 (differ) are answers; anything else means cmp
    # could not run, so fall through instead of assuming a difference.
    local rc=0
    cmp -s "$1" "$2" 2>/dev/null || rc=$?
    if [ "$rc" -le 1 ]; then
        return "$rc"
    elif command -v sha256sum >/dev/null 2>&1; then
        [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]
    else
        [ "$(wc -c < "$1")" = "$(wc -c < "$2")" ]
    fi
}

repatch_launch_bridge() {
    [ -n "$BRIDGE_PAYLOAD" ] && [ -f "$BRIDGE_PAYLOAD" ] || return 0
    local target="$VRC_GAME_DIR/launch.exe"
    local backup="$VRC_GAME_DIR/launch.org.exe"
    [ -d "$VRC_GAME_DIR" ] || return 0
    if bridge_matches "$BRIDGE_PAYLOAD" "$target"; then
        chmod 555 "$target" 2>/dev/null || true
        return 0
    fi
    if [ ! -f "$backup" ] && [ -f "$target" ]; then
        # Never let the bridge become its own fallback: RunOriginal() would start
        # launch.org.exe, which would be the bridge, with no bound. An older bridge
        # build differs from the payload byte for byte, so check the marker too.
        if grep -aqF 'launch_bridge_ready' "$target" 2>/dev/null; then
            echo "VRCOSC: launch.exe is a launch bridge but launch.org.exe is missing; use Steam's 'Verify integrity of game files' on VRChat." >&2
            return 0
        fi
        cp -p "$target" "$backup" 2>/dev/null || return 0
        chmod 444 "$backup" 2>/dev/null || true
    fi
    rm -f "$target" 2>/dev/null || chmod 755 "$target" 2>/dev/null || true
    cp "$BRIDGE_PAYLOAD" "$target" 2>/dev/null || {
        echo "VRCOSC: could not re-apply the launch.exe bridge; vrchat:// navigation may not work." >&2
        return 0
    }
    chmod 555 "$target" 2>/dev/null || true
    echo "VRCOSC: re-applied VRChat's launch.exe bridge (Steam had restored the stock launcher)." >&2
}

repatch_launch_bridge

# --- Preferred path: join VRChat's own wine session ---------------------------
# Steam runs VRChat inside a user+mount namespace with its own wineserver. A
# VRCOSC started outside it lands in a separate wine session (or, if it does
# connect, dies in Velopack with "Access denied"), and can never see VRChat.exe,
# its named pipes or its windows. Entering the game's namespaces first puts
# VRCOSC in the same session. Set VRCOSC_JOIN=0 to skip this.
find_vrchat_pid() {
    local proc
    for proc in /proc/[0-9]*; do
        [ "$(cat "$proc/comm" 2>/dev/null)" = "VRChat.exe" ] || continue
        [ -r "$proc/environ" ] || continue
        tr '\0' '\n' < "$proc/environ" 2>/dev/null \
            | grep -qxF -e "WINEPREFIX=$PFX" -e "WINEPREFIX=$PFX/" || continue
        tr '\0' '\n' < "$proc/environ" 2>/dev/null | grep -q '^PRESSURE_VESSEL_RUNTIME=' || continue
        echo "${proc#/proc/}"
        return 0
    done
    return 1
}

# Proton's wine for this prefix: config_info line 2 is <proton>/files/share/fonts/.
proton_wine() {
    local fonts
    fonts="$(sed -n '2p' "$COMPATDATA/config_info" 2>/dev/null)" || return 1
    fonts="${fonts%/}"
    echo "$(dirname "$(dirname "$fonts")")/bin/wine"
}

if [ "${VRCOSC_JOIN:-1}" != "0" ] && command -v nsenter >/dev/null && vrc_pid="$(find_vrchat_pid)"; then
    wine="$(proton_wine)"
    if [ -n "$wine" ] && [ -x "$wine" ]; then
        envfile="$(mktemp)"
        tr '\0' '\n' < "/proc/$vrc_pid/environ" \
            | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' \
            | grep -vE '^(WINELOADERNOEXEC|WINEPRELOADRESERVE|WINEDEBUG|_|PWD|OLDPWD|SHLVL)=' \
            | while IFS= read -r line; do printf 'export %s=%q\n' "${line%%=*}" "${line#*=}"; done > "$envfile"
        # Probe before exec. exec replaces this shell, so a failing nsenter would
        # leave the user with an nsenter error, no VRCOSC and a leaked env file --
        # no fallback, because there is no shell left to fall back in.
        if nsenter -t "$vrc_pid" -U -m --preserve-credentials true 2>/dev/null; then
            echo "VRCOSC: joining VRChat's wine session (pid $vrc_pid)" >&2
            exec nsenter -t "$vrc_pid" -U -m --preserve-credentials env -i bash -c \
                'source "$1"; rm -f "$1"; export WINEDEBUG=-all; exec "$2" "$3" "$4" "${@:5}"' \
                _ "$envfile" "$wine" "$DOTNET" "$ENTRY" "$@"
        fi
        rm -f "$envfile"
        echo "VRCOSC: could not enter VRChat's namespaces; falling back to protontricks." >&2
        echo "VRCOSC: VRChat will not be detected in this session." >&2
    else
        echo "VRCOSC: VRChat is running but its Proton wine was not found; falling back to protontricks." >&2
    fi
fi

# --- Fallback: own wine session via protontricks ------------------------------
# Used when VRChat is not running. VRCOSC works standalone here, but it will not
# see VRChat if the game is started afterwards -- start VRChat first for full
# integration, then VRCOSC.
if [ -z "${vrc_pid:-}" ]; then
    if [ "${VRCOSC_JOIN:-1}" = "0" ]; then
        echo "VRCOSC: VRCOSC_JOIN=0; starting VRCOSC in its own wine session." >&2
    elif ! command -v nsenter >/dev/null; then
        echo "VRCOSC: nsenter (util-linux) not found; starting VRCOSC in its own wine session." >&2
    else
        echo "VRCOSC: VRChat is not running; starting VRCOSC in its own wine session." >&2
    fi
    echo "VRCOSC: for VRChat detection, start VRChat first, then VRCOSC." >&2
fi

exec env "${SCRUB[@]}" protontricks "${RUNTIME_FLAGS[@]}" \
    -c "wine \"$DOTNET\" \"$ENTRY\" $*" 438100
EOF_LAUNCHER_BODY
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_create_launchers399_v0=''
        return "${__status}"
    fi
    chmod +x "${launch_script_3187}"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_create_launchers399_v0=''
        return "${__status}"
    fi
    dirname__27_v0 "${desktop_entry_3189}"
    local ret_dirname27_v0__191_13="${ret_dirname27_v0}"
    mkdir_p__32_v0 "${ret_dirname27_v0__191_13}"
    local ret_mkdir_p32_v0__191_5="${ret_mkdir_p32_v0}"
    cat << EOF_DESKTOP > "${desktop_entry_3189}"
[Desktop Entry]
Name=${app_name_3190}
Comment=OSC controller for VRChat
Exec=${launch_script_3187}
Icon=vrcosc
Terminal=false
Type=Application
Categories=Game;Utility;
StartupWMClass=VRCOSC
EOF_DESKTOP
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_create_launchers399_v0=''
        return "${__status}"
    fi
    get_vrcosc_install_dir__293_v0 ""
    local ret_get_vrcosc_install_dir293_v0__205_24="${ret_get_vrcosc_install_dir293_v0}"
    local vrcosc_dir_3196="${ret_get_vrcosc_install_dir293_v0__205_24}"
    log_success__1_v0 "=== VRCOSC Setup Complete"'!'" ==="
    if [ "$([ "_${__VRCOSC_BRANCH_23}" != "_beta" ]; echo $?)" != 0 ]; then
        printf '%s\n' "${__YELLOW_3}Beta note:${__NC_6} module packages for a beta SDK ship as pre-releases, which"
        echo "  VRCOSC hides unless ${__CYAN_4}Allow Pre-Release Packages${__NC_6} is on; the installer has"
        echo "  turned it on for you, and set the update channel to Beta so the app does"
        echo "  not replace itself with the stable build. Beta shares its settings with live."
    fi
    basename__28_v0 "${launch_script_3187}"
    local ret_basename28_v0__213_76="${ret_basename28_v0}"
    echo "You can launch VRCOSC from your application menu, or run '${__BLUE_2}${ret_basename28_v0__213_76}${__NC_6}' in the terminal."
    printf '%s\n' ""
    printf '%s\n' "${__BLUE_2}VRCOSC Directory Paths:${__NC_6}"
    echo "  * ${__GREEN_1}Config Folder (Profiles & Settings):${__NC_6}"
    echo "    ${__VRC_COMPATDATA_32}/pfx/drive_c/users/steamuser/AppData/Roaming/VRCOSC"
    echo "  * ${__GREEN_1}Executable Folder (App Files):${__NC_6}"
    echo "    ${vrcosc_dir_3196}"
}

# --info: everything a bug report needs, best-effort. A probe that fails is
# itself a finding, so nothing in here may abort the report.
# or_default(value: Text, fallback: Text)
or_default__434_v0() {
    local value_2916="${1}"
    local fallback_2917="${2}"
    ret_or_default434_v0="$(if [ "$([ "_${value_2916}" == "_" ]; echo $?)" != 0 ]; then echo "${value_2916}"; else echo "${fallback_2917}"; fi)"
    return 0
}

# installed_or_missing(path: Text, present: Text)
installed_or_missing__435_v0() {
    local path_3030="${1}"
    local present_3031="${2}"
    file_exists__23_v0 "${path_3030}"
    local ret_file_exists23_v0__19_8="${ret_file_exists23_v0}"
    if [ "${ret_file_exists23_v0__19_8}" != 0 ]; then
        ret_installed_or_missing435_v0="${__CYAN_4}${present_3031} (${path_3030})${__NC_6}"
        return 0
    fi
    ret_installed_or_missing435_v0="${__YELLOW_3}Missing${__NC_6}"
    return 0
}

# show_diagnostics()
show_diagnostics__436_v0() {
    log_info__0_v0 "Collecting diagnostic and environment information..."
    printf '%s\n' ""
    # System & OS Information
    printf '%s\n' "${__BOLD_5}=== System & OS Environment ===${__NC_6}"
    local os_pretty_2901="Unknown"
    file_exists__23_v0 "/etc/os-release"
    local ret_file_exists23_v0__32_8="${ret_file_exists23_v0}"
    if [ "${ret_file_exists23_v0__32_8}" != 0 ]; then
        local command_154
        command_154="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2- | tr -d '"' || true)"
        __status=$?
        os_pretty_2901="${command_154}"
    fi
    local command_155
    command_155="$(uname -r 2>/dev/null || echo 'Unknown')"
    __status=$?
    local kernel_ver_2903="${command_155}"
    local command_156
    command_156="$(uname -m 2>/dev/null || echo 'Unknown')"
    __status=$?
    local arch_2904="${command_156}"
    env_or__16_v0 "XDG_CURRENT_DESKTOP" "Unknown"
    local ret_env_or16_v0__37_16="${ret_env_or16_v0}"
    local de_2907="${ret_env_or16_v0__37_16}"
    env_or__16_v0 "XDG_SESSION_TYPE" "Unknown"
    local ret_env_or16_v0__38_26="${ret_env_or16_v0}"
    local session_type_2908="${ret_env_or16_v0__38_26}"
    env_or__16_v0 "DESKTOP_SESSION" "Unknown"
    local ret_env_or16_v0__39_29="${ret_env_or16_v0}"
    local desktop_session_2909="${ret_env_or16_v0__39_29}"
    echo "  * Installer:             ${__CYAN_4}v${__SCRIPT_VERSION_11}${__NC_6}"
    echo "  * OS:                    ${__CYAN_4}${os_pretty_2901}${__NC_6}"
    echo "  * Kernel:                ${__CYAN_4}${kernel_ver_2903} (${arch_2904})${__NC_6}"
    echo "  * Desktop Environment:   ${__CYAN_4}${de_2907} (${session_type_2908})${__NC_6}"
    echo "  * Session:               ${__CYAN_4}${desktop_session_2909}${__NC_6}"
    # Tooling
    printf '%s\n' ""
    printf '%s\n' "${__BOLD_5}=== Tooling & Runtime Dependencies ===${__NC_6}"
    local pt_ver_2910="Not installed"
    have_cmd__18_v0 "protontricks"
    local ret_have_cmd18_v0__51_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__51_8}" != 0 ]; then
        local command_157
        command_157="$(protontricks --version 2>&1 | grep -vi 'warning\|deprecat' | head -n 1 || true)"
        __status=$?
        pt_ver_2910="${command_157}"
    fi
    local curl_ver_2912="Not installed"
    have_cmd__18_v0 "curl"
    local ret_have_cmd18_v0__55_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__55_8}" != 0 ]; then
        local command_158
        command_158="$(curl --version 2>&1 | head -n 1 | awk '{print $1, $2}' || true)"
        __status=$?
        curl_ver_2912="${command_158}"
    fi
    local unzip_ver_2913="Not installed"
    have_cmd__18_v0 "unzip"
    local ret_have_cmd18_v0__59_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__59_8}" != 0 ]; then
        local command_159
        command_159="$(command -v unzip || true)"
        __status=$?
        unzip_ver_2913="Installed (${command_159})"
    fi
    local archiver_2914="tar/xz"
    have_cmd__18_v0 "7z"
    local ret_have_cmd18_v0__63_8="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__63_8}" != 0 ]; then
        local command_160
        command_160="$(7z 2>&1 | grep -i '7-Zip' | head -n 1 | awk '{print $2}' || true)"
        __status=$?
        local z7_ver_2915="${command_160}"
        or_default__434_v0 "${z7_ver_2915}" "installed"
        local ret_or_default434_v0__65_26="${ret_or_default434_v0}"
        archiver_2914="7z (${ret_or_default434_v0__65_26})"
    fi
    echo "  * Protontricks:          ${__CYAN_4}${pt_ver_2910}${__NC_6}"
    echo "  * cURL:                  ${__CYAN_4}${curl_ver_2912}${__NC_6}"
    echo "  * Unzip:                 ${__CYAN_4}${unzip_ver_2913}${__NC_6}"
    echo "  * Compression Tool:      ${__CYAN_4}${archiver_2914}${__NC_6}"
    # Prefix & Wine Configuration
    printf '%s\n' ""
    printf '%s\n' "${__BOLD_5}=== VRChat Proton Prefix ===${__NC_6}"
    find_prefix_silently__222_v0 
    local ret_find_prefix_silently222_v0__76_5="${ret_find_prefix_silently222_v0}"
    dir_exists__24_v0 "${__VRC_COMPATDATA_32}/pfx"
    local ret_dir_exists24_v0__78_33="${ret_dir_exists24_v0}"
    if [ "$(( $([ "_${__VRC_COMPATDATA_32}" == "_" ]; echo $?) && ret_dir_exists24_v0__78_33 ))" != 0 ]; then
        echo "  * Prefix Root:           ${__CYAN_4}${__VRC_COMPATDATA_32}${__NC_6}"
        echo "  * Prefix pfx:            ${__CYAN_4}${__VRC_COMPATDATA_32}/pfx${__NC_6}"
        get_prefix_proton_version__254_v0 
        local ret_get_prefix_proton_version254_v0__82_39="${ret_get_prefix_proton_version254_v0}"
        or_default__434_v0 "${ret_get_prefix_proton_version254_v0__82_39}" "Unknown (prefix never launched?)"
        local ret_or_default434_v0__82_28="${ret_or_default434_v0}"
        local proton_ver_2938="${ret_or_default434_v0__82_28}"
        get_prefix_proton_dir__255_v0 
        local ret_get_prefix_proton_dir255_v0__83_39="${ret_get_prefix_proton_dir255_v0}"
        or_default__434_v0 "${ret_get_prefix_proton_dir255_v0__83_39}" "Unknown"
        local ret_or_default434_v0__83_28="${ret_or_default434_v0}"
        local proton_dir_2944="${ret_or_default434_v0__83_28}"
        get_prefix_runtime_appid__256_v0 
        local ret_get_prefix_runtime_appid256_v0__84_31="${ret_get_prefix_runtime_appid256_v0}"
        local runtime_appid_2947="${ret_get_prefix_runtime_appid256_v0__84_31}"
        echo "  * Proton Build:          ${__CYAN_4}${proton_ver_2938}${__NC_6}"
        echo "  * Proton Path:           ${__CYAN_4}${proton_dir_2944}${__NC_6}"
        if [ "$([ "_${runtime_appid_2947}" == "_" ]; echo $?)" != 0 ]; then
            echo "  * Required Steam Runtime: ${__CYAN_4}appid ${runtime_appid_2947}${__NC_6}"
        else
            echo "  * Required Steam Runtime: ${__YELLOW_3}None declared (custom Proton; protontricks may not find a runtime)${__NC_6}"
        fi
        local user_reg_2948="${__VRC_COMPATDATA_32}/pfx/user.reg"
        local sys_reg_2949="${__VRC_COMPATDATA_32}/pfx/system.reg"
        file_exists__23_v0 "${user_reg_2948}"
        local ret_file_exists23_v0__95_33="${ret_file_exists23_v0}"
        local user_reg_status_2950
        user_reg_status_2950="$(if [ "${ret_file_exists23_v0__95_33}" != 0 ]; then echo "Present"; else echo "Missing"; fi)"
        file_exists__23_v0 "${sys_reg_2949}"
        local ret_file_exists23_v0__96_32="${ret_file_exists23_v0}"
        local sys_reg_status_2951
        sys_reg_status_2951="$(if [ "${ret_file_exists23_v0__96_32}" != 0 ]; then echo "Present"; else echo "Missing"; fi)"
        echo "  * Registry (user.reg):   ${__CYAN_4}${user_reg_2948}${__NC_6} (${user_reg_status_2950})"
        echo "  * Registry (system.reg): ${__CYAN_4}${sys_reg_2949}${__NC_6} (${sys_reg_status_2951})"
        local wpf_disabled_2952=0
        local array_163=("${user_reg_2948}" "${sys_reg_2949}")
        for reg_2953 in "${array_163[@]}"; do
            file_exists__23_v0 "${reg_2953}"
            local ret_file_exists23_v0__103_16="${ret_file_exists23_v0}"
            if [ "${ret_file_exists23_v0__103_16}" != 0 ]; then
                grep -q 'DisableHWAcceleration' "${reg_2953}">/dev/null 2>&1
                __status=$?
                if [ "$(( __status == 0 ))" != 0 ]; then
                    wpf_disabled_2952=1
                fi
            fi
        done
        if [ "${wpf_disabled_2952}" != 0 ]; then
            echo "  * WPF HW Accel Patch:    ${__GREEN_1}Applied (DisableHWAcceleration=1)${__NC_6}"
        else
            echo "  * WPF HW Accel Patch:    ${__YELLOW_3}Not detected (Black window issue may occur)${__NC_6}"
        fi
        local dotnet_exe_2954="${__VRC_COMPATDATA_32}/pfx/drive_c/Program Files/dotnet/dotnet.exe"
        local dotnet_status_2955="Not installed"
        file_exists__23_v0 "${dotnet_exe_2954}"
        local ret_file_exists23_v0__118_12="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__118_12}" != 0 ]; then
            dotnet_status_2955="Installed (${dotnet_exe_2954})"
        fi
        echo "  * .NET Binary:           ${__CYAN_4}${dotnet_status_2955}${__NC_6}"
        get_installed_desktop_runtimes__327_v0 
        local ret_get_installed_desktop_runtimes327_v0__123_34=("${ret_get_installed_desktop_runtimes327_v0[@]}")
        local desktop_runtimes_2962=("${ret_get_installed_desktop_runtimes327_v0__123_34[@]}")
        local __length_164=("${desktop_runtimes_2962[@]}")
        if [ "$(( ${#__length_164[@]} > 0 ))" != 0 ]; then
            join_words__40_v0 desktop_runtimes_2962[@]
            local ret_join_words40_v0__125_53="${ret_join_words40_v0}"
            echo "  * .NET WindowsDesktop:   ${__CYAN_4}${ret_join_words40_v0__125_53}${__NC_6}"
        else
            echo "  * .NET WindowsDesktop:   ${__YELLOW_3}None detected${__NC_6}"
        fi
        get_vrcosc_install_dir__293_v0 ""
        local ret_get_vrcosc_install_dir293_v0__130_62="${ret_get_vrcosc_install_dir293_v0}"
        get_required_dotnet_channel__325_v0 "${ret_get_vrcosc_install_dir293_v0__130_62}"
        local ret_get_required_dotnet_channel325_v0__130_34="${ret_get_required_dotnet_channel325_v0}"
        local required_channel_2971="${ret_get_required_dotnet_channel325_v0__130_34}"
        has_desktop_runtime_channel__328_v0 "${required_channel_2971}"
        local ret_has_desktop_runtime_channel328_v0__135_13="${ret_has_desktop_runtime_channel328_v0}"
        if [ "$([ "_${required_channel_2971}" != "_" ]; echo $?)" != 0 ]; then
            echo "  * .NET Required by App:  ${__YELLOW_3}Unknown (VRCOSC.runtimeconfig.json not readable)${__NC_6}"
        elif [ "${ret_has_desktop_runtime_channel328_v0__135_13}" != 0 ]; then
            echo "  * .NET Required by App:  ${__GREEN_1}${required_channel_2971}.x (satisfied)${__NC_6}"
        else
            echo "  * .NET Required by App:  ${__RED_0}${required_channel_2971}.x (MISSING -- VRCOSC will not start)${__NC_6}"
            echo "    ${__YELLOW_3}.NET does not roll forward across major versions; run install.sh again to fix.${__NC_6}"
        fi
        printf '%s\n' ""
        printf '%s\n' "${__BOLD_5}=== Wine Environment Health ===${__NC_6}"
        list_contaminated_env__239_v0 
        local ret_list_contaminated_env239_v0__146_30=("${ret_list_contaminated_env239_v0[@]}")
        local contaminated_2977=("${ret_list_contaminated_env239_v0__146_30[@]}")
        local __length_165=("${contaminated_2977[@]}")
        if [ "$(( ${#__length_165[@]} > 0 ))" != 0 ]; then
            join_words__40_v0 contaminated_2977[@]
            local ret_join_words40_v0__148_55="${ret_join_words40_v0}"
            echo "  * Leaked Runtime Vars:   ${__YELLOW_3}${ret_join_words40_v0__148_55} ${__NC_6}"
            echo "    ${__YELLOW_3}These are scrubbed from wine calls; unscrubbed they cause bogus errors${__NC_6}"
            echo "    ${__YELLOW_3}such as 'Fontconfig error: /etc/fonts/fonts.conf: out of memory'.${__NC_6}"
        else
            echo "  * Leaked Runtime Vars:   ${__GREEN_1}None${__NC_6}"
        fi
        find_vrchat_container_pid__249_v0 
        local ret_find_vrchat_container_pid249_v0__155_25="${ret_find_vrchat_container_pid249_v0}"
        local vrc_pid_2979="${ret_find_vrchat_container_pid249_v0__155_25}"
        have_cmd__18_v0 "nsenter"
        local ret_have_cmd18_v0__157_31="${ret_have_cmd18_v0}"
        if [ "$(( $([ "_${vrc_pid_2979}" == "_" ]; echo $?) && ret_have_cmd18_v0__157_31 ))" != 0 ]; then
            echo "  * VRChat Session:        ${__GREEN_1}Running in Steam's container (pid ${vrc_pid_2979}); launcher will join it${__NC_6}"
        elif [ "$([ "_${vrc_pid_2979}" == "_" ]; echo $?)" != 0 ]; then
            echo "  * VRChat Session:        ${__YELLOW_3}Running (pid ${vrc_pid_2979}) but nsenter is missing; cannot join it${__NC_6}"
        else
            echo "  * VRChat Session:        ${__CYAN_4}Not running (VRCOSC will start a session of its own)${__NC_6}"
        fi
        get_prefix_holders__246_v0 
        local ret_get_prefix_holders246_v0__168_25=("${ret_get_prefix_holders246_v0[@]}")
        local holders_2982=("${ret_get_prefix_holders246_v0__168_25[@]}")
        local __length_166=("${holders_2982[@]}")
        if [ "$(( ${#__length_166[@]} > 0 ))" != 0 ]; then
            holder_names__247_v0 holders_2982[@]
            local ret_holder_names247_v0__170_50=("${ret_holder_names247_v0[@]}")
            local command_167
            command_167="$(printf '%s
' ${ret_holder_names247_v0__170_50[@]} | sort -u | head -n 4 | tr '
' ' ')"
            __status=$?
            local names_2986="${command_167}"
            local __length_168=("${holders_2982[@]}")
            echo "  * Wine Processes In Prefix: ${__CYAN_4}${#__length_168[@]}${__NC_6} (${names_2986}...)"
        else
            echo "  * Wine Processes In Prefix: ${__GREEN_1}None (prefix idle)${__NC_6}"
        fi
        for candidate_2987 in "${__RUNTIME_MODE_CANDIDATES_16[@]}"; do
            test_runtime_mode__253_v0 "${candidate_2987}"
            local ret_test_runtime_mode253_v0__177_24="${ret_test_runtime_mode253_v0}"
            local ok_3009="${ret_test_runtime_mode253_v0__177_24}"
            printf '  * Runtime [%-9s]:  ' "${candidate_2987}"
            __status=$?
            if [ "${ok_3009}" != 0 ]; then
                printf '%s\n' "${__GREEN_1}OK (${__LAST_RUNTIME_PROBE_89})${__NC_6}"
            else
                printf '%s\n' "${__RED_0}Broken${__NC_6} ${__YELLOW_3}${__LAST_RUNTIME_PROBE_89}${__NC_6}"
            fi
        done
        printf '%s\n' ""
        printf '%s\n' "${__BOLD_5}=== VRCOSC User Config Directories ===${__NC_6}"
        local cfgs_found_3010=0
        glob__19_v0 "${__VRC_COMPATDATA_32}/pfx/drive_c/users/*"
        local ret_glob19_v0__189_18=("${ret_glob19_v0[@]}")
        for u_3011 in "${ret_glob19_v0__189_18[@]}"; do
            basename__28_v0 "${u_3011}"
            local ret_basename28_v0__190_27="${ret_basename28_v0}"
            local uname_3012="${ret_basename28_v0__190_27}"
            # VRCOSC-Beta is not created by any release build; it is listed because a
            # hand-made setup may still have one.
            local array_175=("VRCOSC:Live and Beta" "VRCOSC-Beta:Beta (custom)")
            for ch_3013 in "${array_175[@]}"; do
                local command_176
                command_176="$(printf '%s' "${ch_3013%%:*}")"
                __status=$?
                local folder_3014="${command_176}"
                local command_177
                command_177="$(printf '%s' "${ch_3013##*:}")"
                __status=$?
                local label_3015="${command_177}"
                local cfg_dir_3016="${u_3011}/AppData/Roaming/${folder_3014}"
                dir_exists__24_v0 "${cfg_dir_3016}"
                local ret_dir_exists24_v0__197_20="${ret_dir_exists24_v0}"
                if [ "${ret_dir_exists24_v0__197_20}" != 0 ]; then
                    local real_tgt_3017=""
                    is_symlink__25_v0 "${cfg_dir_3016}"
                    local ret_is_symlink25_v0__199_24="${ret_is_symlink25_v0}"
                    if [ "${ret_is_symlink25_v0__199_24}" != 0 ]; then
                        local command_178
                        command_178="$(readlink "${cfg_dir_3016}")"
                        __status=$?
                        real_tgt_3017=" -> ${command_178}"
                    fi
                    echo "  * User [${uname_3012}] (${label_3015}):     ${__CYAN_4}${cfg_dir_3016}${__NC_6}${real_tgt_3017}"
                    cfgs_found_3010=1
                fi
            done
        done
        if [ "$(( ! cfgs_found_3010 ))" != 0 ]; then
            echo "  * ${__YELLOW_3}No active VRCOSC AppData config directories found.${__NC_6}"
        fi
        printf '%s\n' ""
        printf '%s\n' "${__BOLD_5}=== VRCOSC Installation & Versions ===${__NC_6}"
        get_vrcosc_install_dir__293_v0 "live"
        local ret_get_vrcosc_install_dir293_v0__213_78="${ret_get_vrcosc_install_dir293_v0}"
        get_vrcosc_version_from_dir__300_v0 "${ret_get_vrcosc_install_dir293_v0__213_78}"
        local ret_get_vrcosc_version_from_dir300_v0__213_50="${ret_get_vrcosc_version_from_dir300_v0}"
        echo "  * Local Version (Live):   ${__CYAN_4}${ret_get_vrcosc_version_from_dir300_v0__213_50}${__NC_6}"
        get_vrcosc_install_dir__293_v0 "beta"
        local ret_get_vrcosc_install_dir293_v0__214_78="${ret_get_vrcosc_install_dir293_v0}"
        get_vrcosc_version_from_dir__300_v0 "${ret_get_vrcosc_install_dir293_v0__214_78}"
        local ret_get_vrcosc_version_from_dir300_v0__214_50="${ret_get_vrcosc_version_from_dir300_v0}"
        echo "  * Local Version (Beta):   ${__CYAN_4}${ret_get_vrcosc_version_from_dir300_v0__214_50}${__NC_6}"
    else
        echo "  * Prefix Root:           ${__YELLOW_3}Not detected (use --prefix <PATH> if located on an external drive)${__NC_6}"
    fi
    # Remote GitHub Releases
    local remote_live_3023="Unavailable (Network/Rate-limited)"
    local remote_beta_3024="Unavailable (Network/Rate-limited)"
    github_api__305_v0 "https://api.github.com/repos/VolcanicArts/VRCOSC/releases"
    local ret_github_api305_v0__222_27="${ret_github_api305_v0}"
    local releases_json_3027="${ret_github_api305_v0__222_27}"
    if [ "$([ "_${releases_json_3027}" == "_" ]; echo $?)" != 0 ]; then
        have_cmd__18_v0 "python3"
        local ret_have_cmd18_v0__224_12="${ret_have_cmd18_v0}"
        if [ "${ret_have_cmd18_v0__224_12}" != 0 ]; then
            local command_179
            command_179="$(python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(next((r['tag_name'] for r in data if not r.get('prerelease')), 'Unavailable'))" <<< "${releases_json_3027}" 2>/dev/null || echo 'Unavailable')"
            __status=$?
            remote_live_3023="${command_179}"
            local command_180
            command_180="$(python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(next((r['tag_name'] for r in data if r.get('prerelease')), 'Unavailable'))" <<< "${releases_json_3027}" 2>/dev/null || echo 'Unavailable')"
            __status=$?
            remote_beta_3024="${command_180}"
        else
            local command_181
            command_181="$(echo "${releases_json_3027}" | grep -B 10 -A 2 '"prerelease": false' | grep '"tag_name":' | head -n 1 | cut -d'"' -f4 || echo 'Unavailable')"
            __status=$?
            remote_live_3023="${command_181}"
            local command_182
            command_182="$(echo "${releases_json_3027}" | grep -B 10 -A 2 '"prerelease": true' | grep '"tag_name":' | head -n 1 | cut -d'"' -f4 || echo 'Unavailable')"
            __status=$?
            remote_beta_3024="${command_182}"
        fi
    fi
    looks_rate_limited__306_v0 "${releases_json_3027}"
    local ret_looks_rate_limited306_v0__232_8="${ret_looks_rate_limited306_v0}"
    if [ "${ret_looks_rate_limited306_v0__232_8}" != 0 ]; then
        remote_live_3023="Rate-limited (export GITHUB_TOKEN to check)"
        remote_beta_3024="${remote_live_3023}"
    fi
    echo "  * Remote Latest (Live):   ${__CYAN_4}${remote_live_3023}${__NC_6}"
    echo "  * Remote Latest (Beta):   ${__CYAN_4}${remote_beta_3024}${__NC_6}"
    printf '%s\n' ""
    printf '%s\n' "${__BOLD_5}=== Integration & Launchers ===${__NC_6}"
    get_launcher_script__290_v0 "live"
    local ret_get_launcher_script290_v0__241_62="${ret_get_launcher_script290_v0}"
    installed_or_missing__435_v0 "${ret_get_launcher_script290_v0__241_62}" "Installed"
    local ret_installed_or_missing435_v0__241_41="${ret_installed_or_missing435_v0}"
    echo "  * Command (vrcosc):        ${ret_installed_or_missing435_v0__241_41}"
    get_launcher_script__290_v0 "beta"
    local ret_get_launcher_script290_v0__242_62="${ret_get_launcher_script290_v0}"
    installed_or_missing__435_v0 "${ret_get_launcher_script290_v0__242_62}" "Installed"
    local ret_installed_or_missing435_v0__242_41="${ret_installed_or_missing435_v0}"
    echo "  * Command (vrcosc-beta):   ${ret_installed_or_missing435_v0__242_41}"
    get_desktop_file__291_v0 "live"
    local ret_get_desktop_file291_v0__243_62="${ret_get_desktop_file291_v0}"
    installed_or_missing__435_v0 "${ret_get_desktop_file291_v0__243_62}" "Present"
    local ret_installed_or_missing435_v0__243_41="${ret_installed_or_missing435_v0}"
    echo "  * Desktop (Live):          ${ret_installed_or_missing435_v0__243_41}"
    get_desktop_file__291_v0 "beta"
    local ret_get_desktop_file291_v0__244_62="${ret_get_desktop_file291_v0}"
    installed_or_missing__435_v0 "${ret_get_desktop_file291_v0__244_62}" "Present"
    local ret_installed_or_missing435_v0__244_41="${ret_installed_or_missing435_v0}"
    echo "  * Desktop (Beta):          ${ret_installed_or_missing435_v0__244_41}"
    get_app_icon_path__292_v0 
    local ret_get_app_icon_path292_v0__245_62="${ret_get_app_icon_path292_v0}"
    installed_or_missing__435_v0 "${ret_get_app_icon_path292_v0__245_62}" "Present"
    local ret_installed_or_missing435_v0__245_41="${ret_installed_or_missing435_v0}"
    echo "  * Icon:                    ${ret_installed_or_missing435_v0__245_41}"
    get_vrchat_game_dir__295_v0 
    local ret_get_vrchat_game_dir295_v0__247_29="${ret_get_vrchat_game_dir295_v0}"
    local target_launch_3034="${ret_get_vrchat_game_dir295_v0__247_29}/launch.exe"
    resolve_launch_bridge__382_v0 0
    local ret_resolve_launch_bridge382_v0__248_27="${ret_resolve_launch_bridge382_v0}"
    local source_bridge_3045="${ret_resolve_launch_bridge382_v0__248_27}"
    local bridge_status_3046="${__YELLOW_3}Unpatched / Missing${__NC_6}"
    files_identical__299_v0 "${source_bridge_3045}" "${target_launch_3034}"
    local ret_files_identical299_v0__251_33="${ret_files_identical299_v0}"
    file_exists__23_v0 "${target_launch_3034}"
    local ret_file_exists23_v0__254_9="${ret_file_exists23_v0}"
    if [ "$(( $([ "_${source_bridge_3045}" == "_" ]; echo $?) && ret_files_identical299_v0__251_33 ))" != 0 ]; then
        bridge_status_3046="${__GREEN_1}Patched (Linux IPC Named-Pipe Bridge)${__NC_6}"
    elif [ "${ret_file_exists23_v0__254_9}" != 0 ]; then
        bridge_status_3046="${__YELLOW_3}Stock launch.exe (Unpatched)${__NC_6}"
    fi
    echo "  * VRChat Launch Bridge:    ${bridge_status_3046}"
    printf '%s\n' ""
    printf '%s\n' "${__BOLD_5}=== Community & Support ===${__NC_6}"
    echo "  * Server Invite:           ${__CYAN_4}${__DISCORD_INVITE_7}${__NC_6}"
    echo "  * Linux Discussion:        ${__CYAN_4}${__DISCORD_THREAD_8}${__NC_6}"
    printf '%s\n' ""
}

# --backup: everything a user would want back before something destructive.
# create_backup()
create_backup__450_v0() {
    log_info__0_v0 "Initiating VRCOSC and prefix backup..."
    locate_vrchat_prefix__223_v0 
    local command_183
    command_183="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
    __status=$?
    local desktop_dir_3055="${command_183}"
    mkdir -p "${desktop_dir_3055}"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_create_backup450_v0=''
        return "${__status}"
    fi
    local command_184
    command_184="$(date +%s)"
    __status=$?
    local timestamp_3056="${command_184}"
    # mkdir -p on a fixed name succeeds on a directory someone else created and
    # can read, and the staged copy includes module settings with API tokens in it.
    local command_185
    command_185="$(mktemp -d "${TMPDIR:-/tmp}/vrcosc_backup_${timestamp_3056}.XXXXXX")"
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_create_backup450_v0=''
        return "${__status}"
    fi
    local stage_dir_3057="${command_185}"
    local items_found_3058=0
    # 1. Config directories (Roaming/VRCOSC, Roaming/VRCOSC-Beta)
    # 
    # -L, not -a: a config directory is very often a symlink to cloud storage, and
    # copying the link instead of what it points at produced a backup containing a
    # 62-byte path string in place of every setting and profile. This is the one
    # feature whose whole job is to be correct before something destructive.
    # 
    # runtime/ and logs/ are left out. They are caches VRCOSC rebuilds, they are
    # the bulk of the size (540 MB and growing here), and a backup nobody can
    # afford to keep is a backup nobody makes.
    glob__19_v0 "${__VRC_COMPATDATA_32}/pfx/drive_c/users/*"
    local ret_glob19_v0__33_14=("${ret_glob19_v0[@]}")
    for u_3059 in "${ret_glob19_v0__33_14[@]}"; do
        basename__28_v0 "${u_3059}"
        local ret_basename28_v0__34_26="${ret_basename28_v0}"
        local username_3060="${ret_basename28_v0__34_26}"
        local array_190=("VRCOSC" "VRCOSC-Beta")
        for folder_3061 in "${array_190[@]}"; do
            local src_3062="${u_3059}/AppData/Roaming/${folder_3061}"
            dir_exists__24_v0 "${src_3062}"
            local ret_dir_exists24_v0__37_20="${ret_dir_exists24_v0}"
            if [ "$(( ! ret_dir_exists24_v0__37_20 ))" != 0 ]; then
                continue
            fi
            local dest_3063="${stage_dir_3057}/users/${username_3060}/AppData/Roaming/${folder_3061}"
            mkdir_p__32_v0 "${dest_3063}"
            local ret_mkdir_p32_v0__41_13="${ret_mkdir_p32_v0}"
            glob__19_v0 "${src_3062}/*"
            local ret_glob19_v0__42_26=("${ret_glob19_v0[@]}")
            for entry_3064 in "${ret_glob19_v0__42_26[@]}"; do
                path_exists__22_v0 "${entry_3064}"
                local ret_path_exists22_v0__43_24="${ret_path_exists22_v0}"
                if [ "$(( ! ret_path_exists22_v0__43_24 ))" != 0 ]; then
                    continue
                fi
                basename__28_v0 "${entry_3064}"
                local ret_basename28_v0__46_30="${ret_basename28_v0}"
                local name_3066="${ret_basename28_v0__46_30}"
                if [ "$(( $([ "_${name_3066}" != "_runtime" ]; echo $?) || $([ "_${name_3066}" != "_logs" ]; echo $?) ))" != 0 ]; then
                    log_info__0_v0 "  skipping ${folder_3061}/${name_3066} (regenerated cache)"
                    continue
                fi
                cp -RL "${entry_3064}" "${dest_3063}/">/dev/null 2>&1
                __status=$?
                if [ "$(( __status != 0 ))" != 0 ]; then
                    cp -R "${entry_3064}" "${dest_3063}/"
                    __status=$?
                    if [ "${__status}" != 0 ]; then
                        ret_create_backup450_v0=''
                        return "${__status}"
                    fi
                fi
            done
            items_found_3058=1
        done
    done
    # Prune any broken or circular symbolic links to avoid compression errors
    find "${stage_dir_3057}" -xtype l -delete>/dev/null 2>&1
    __status=$?
    # 2. Wine prefix registry files
    local array_195=("user.reg" "system.reg")
    for reg_3067 in "${array_195[@]}"; do
        file_exists__23_v0 "${__VRC_COMPATDATA_32}/pfx/${reg_3067}"
        local ret_file_exists23_v0__65_12="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__65_12}" != 0 ]; then
            cp "${__VRC_COMPATDATA_32}/pfx/${reg_3067}" "${stage_dir_3057}/"
            __status=$?
            if [ "${__status}" != 0 ]; then
                ret_create_backup450_v0=''
                return "${__status}"
            fi
            items_found_3058=1
        fi
    done
    # 3. Launchers & desktop shortcuts
    get_all_installed_files__298_v0 
    local ret_get_all_installed_files298_v0__72_14=("${ret_get_all_installed_files298_v0[@]}")
    for f_3068 in "${ret_get_all_installed_files298_v0__72_14[@]}"; do
        file_exists__23_v0 "${f_3068}"
        local ret_file_exists23_v0__73_12="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__73_12}" != 0 ]; then
            mkdir_p__32_v0 "${stage_dir_3057}/launchers"
            local ret_mkdir_p32_v0__74_13="${ret_mkdir_p32_v0}"
            cp "${f_3068}" "${stage_dir_3057}/launchers/"
            __status=$?
            if [ "${__status}" != 0 ]; then
                ret_create_backup450_v0=''
                return "${__status}"
            fi
            items_found_3058=1
        fi
    done
    if [ "$(( ! items_found_3058 ))" != 0 ]; then
        log_warn__2_v0 "No VRCOSC configurations or registries found to backup."
        rm -rf "${stage_dir_3057}"
        __status=$?
        ret_create_backup450_v0=''
        return 0
    fi
    local archive_path_3069=""
    have_cmd__18_v0 "7z"
    local ret_have_cmd18_v0__88_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "tar"
    local ret_have_cmd18_v0__93_9="${ret_have_cmd18_v0}"
    have_cmd__18_v0 "xz"
    local ret_have_cmd18_v0__93_29="${ret_have_cmd18_v0}"
    if [ "${ret_have_cmd18_v0__88_9}" != 0 ]; then
        archive_path_3069="${desktop_dir_3055}/VRCOSC_backup_${timestamp_3056}.7z"
        log_info__0_v0 "Compressing backup using 7z (LZMA2 ultra compression)..."
        7z a -t7z -m0=lzma2 -mx=9 -snl -bso0 -bsp0 "${archive_path_3069}" "${stage_dir_3057}"/*
        __status=$?
        if [ "${__status}" != 0 ]; then
            ret_create_backup450_v0=''
            return "${__status}"
        fi
    elif [ "$(( ret_have_cmd18_v0__93_9 && ret_have_cmd18_v0__93_29 ))" != 0 ]; then
        archive_path_3069="${desktop_dir_3055}/VRCOSC_backup_${timestamp_3056}.tar.xz"
        log_info__0_v0 "Compressing backup using tar.xz (max compression)..."
        XZ_OPT="-9e" tar -cJf "${archive_path_3069}" -C "${stage_dir_3057}" .
        __status=$?
        if [ "${__status}" != 0 ]; then
            ret_create_backup450_v0=''
            return "${__status}"
        fi
    else
        archive_path_3069="${desktop_dir_3055}/VRCOSC_backup_${timestamp_3056}.tar.gz"
        log_info__0_v0 "Compressing backup using tar.gz..."
        tar -czf "${archive_path_3069}" -C "${stage_dir_3057}" .
        __status=$?
        if [ "${__status}" != 0 ]; then
            ret_create_backup450_v0=''
            return "${__status}"
        fi
    fi
    rm -rf "${stage_dir_3057}"
    __status=$?
    log_success__1_v0 "Backup created successfully:"
    echo "  * ${__CYAN_4}${archive_path_3069}${__NC_6}"
}

# Taking VRCOSC off a machine again: --purge and --uninstall.
# Delete settings, profiles and logs for the selected branch. Only the branch's
# own directory is touched: a prefix may also hold VRCOSC-Dev or other
# directories this installer never created, and those are not ours to remove.
# purge_vrcosc_config()
purge_vrcosc_config__467_v0() {
    get_vrcosc_config_dirs__294_v0 
    local ret_get_vrcosc_config_dirs294_v0__16_18=("${ret_get_vrcosc_config_dirs294_v0[@]}")
    local dirs_3090=("${ret_get_vrcosc_config_dirs294_v0__16_18[@]}")
    local purged_3091=0
    if [ "$([ "_${__VRCOSC_BRANCH_23}" != "_beta" ]; echo $?)" != 0 ]; then
        log_warn__2_v0 "Note: beta shares its settings with the live install, so this purges both."
    fi
    local __length_198=("${dirs_3090[@]}")
    if [ "$(( ${#__length_198[@]} == 0 ))" != 0 ]; then
        log_info__0_v0 "No ${__VRCOSC_BRANCH_23} configuration directory found; nothing to purge."
        ret_purge_vrcosc_config467_v0=''
        return 0
    fi
    for d_3092 in "${dirs_3090[@]}"; do
        local command_201
        command_201="$(readlink -f "${d_3092}" 2>/dev/null || echo "${d_3092}")"
        __status=$?
        local resolved_3093="${command_201}"
        if [ "$([ "_${resolved_3093}" == "_${d_3092}" ]; echo $?)" != 0 ]; then
            log_warn__2_v0 "  ${d_3092}"
            log_warn__2_v0 "    is a symlink to ${resolved_3093}, which will be deleted too."
        else
            log_warn__2_v0 "  ${d_3092}"
        fi
        if [ "${__DRY_RUN_28}" != 0 ]; then
            continue
        fi
        rm -rf "${resolved_3093:?}"
        __status=$?
        is_symlink__25_v0 "${d_3092}"
        local ret_is_symlink25_v0__40_12="${ret_is_symlink25_v0}"
        if [ "${ret_is_symlink25_v0__40_12}" != 0 ]; then
            rm -f "${d_3092}"
            __status=$?
        fi
        purged_3091=1
    done
    if [ "${__DRY_RUN_28}" != 0 ]; then
        log_info__0_v0 "Dry run: the directories above would be deleted; nothing was touched."
        ret_purge_vrcosc_config467_v0=''
        return 0
    fi
    if [ "${purged_3091}" != 0 ]; then
        log_success__1_v0 "VRCOSC ${__VRCOSC_BRANCH_23} configuration purged."
    fi
}

# uninstall_vrcosc()
uninstall_vrcosc__468_v0() {
    if [ "${__DRY_RUN_28}" != 0 ]; then
        log_warn__2_v0 "Simulating VRCOSC uninstallation (--dry-run; nothing will be removed)..."
    else
        log_warn__2_v0 "Starting VRCOSC uninstallation..."
    fi
    locate_vrchat_prefix__223_v0 
    local removed_3070=0
    # Remove installation directories
    get_vrcosc_install_dir__293_v0 "live"
    local ret_get_vrcosc_install_dir293_v0__65_17="${ret_get_vrcosc_install_dir293_v0}"
    get_vrcosc_install_dir__293_v0 "beta"
    local ret_get_vrcosc_install_dir293_v0__65_49="${ret_get_vrcosc_install_dir293_v0}"
    local array_204=("${ret_get_vrcosc_install_dir293_v0__65_17}" "${ret_get_vrcosc_install_dir293_v0__65_49}")
    for dir_3071 in "${array_204[@]}"; do
        dir_exists__24_v0 "${dir_3071}"
        local ret_dir_exists24_v0__66_12="${ret_dir_exists24_v0}"
        if [ "${ret_dir_exists24_v0__66_12}" != 0 ]; then
            if [ "${__DRY_RUN_28}" != 0 ]; then
                log_info__0_v0 "Would remove binaries: ${dir_3071}"
            else
                log_info__0_v0 "Removing binaries: ${dir_3071}"
                rm -rf "${dir_3071}"
                __status=$?
            fi
            removed_3070=1
        fi
    done
    # Remove launchers, shortcuts, and icon
    get_all_installed_files__298_v0 
    local ret_get_all_installed_files298_v0__78_14=("${ret_get_all_installed_files298_v0[@]}")
    for f_3072 in "${ret_get_all_installed_files298_v0__78_14[@]}"; do
        file_exists__23_v0 "${f_3072}"
        local ret_file_exists23_v0__79_12="${ret_file_exists23_v0}"
        if [ "${ret_file_exists23_v0__79_12}" != 0 ]; then
            if [ "${__DRY_RUN_28}" != 0 ]; then
                log_info__0_v0 "Would remove file: ${f_3072}"
            else
                log_info__0_v0 "Removing file: ${f_3072}"
                rm -f "${f_3072}"
                __status=$?
            fi
            removed_3070=1
        fi
    done
    # Undo the launch.exe patch, and drop the bridge payload we cached for it.
    restore_vrchat_launch_bridge__385_v0 
    local ret_restore_vrchat_launch_bridge385_v0__91_8="${ret_restore_vrchat_launch_bridge385_v0}"
    if [ "${ret_restore_vrchat_launch_bridge385_v0__91_8}" != 0 ]; then
        removed_3070=1
    fi
    get_launch_bridge_cache__296_v0 
    local ret_get_launch_bridge_cache296_v0__94_19="${ret_get_launch_bridge_cache296_v0}"
    local cache_3078="${ret_get_launch_bridge_cache296_v0__94_19}"
    file_exists__23_v0 "${cache_3078}"
    local ret_file_exists23_v0__95_8="${ret_file_exists23_v0}"
    if [ "${ret_file_exists23_v0__95_8}" != 0 ]; then
        if [ "${__DRY_RUN_28}" != 0 ]; then
            log_info__0_v0 "Would remove cached bridge payload: ${cache_3078}"
        else
            log_info__0_v0 "Removing cached bridge payload: ${cache_3078}"
            rm -f "${cache_3078}"
            __status=$?
            dirname__27_v0 "${cache_3078}">/dev/null 2>&1
            local ret_dirname27_v0__101_36="${ret_dirname27_v0}"
            rmdir "${ret_dirname27_v0__101_36}">/dev/null 2>&1
            __status=$?
        fi
        removed_3070=1
    fi
    # The flatpak grants are part of what installing did to this machine, so
    # "cleanly remove" has to include them.
    revoke_protontricks_permissions__265_v0 
    local ret_revoke_protontricks_permissions265_v0__108_8="${ret_revoke_protontricks_permissions265_v0}"
    if [ "${ret_revoke_protontricks_permissions265_v0__108_8}" != 0 ]; then
        removed_3070=1
    fi
    report_firewall_rules_on_uninstall__354_v0 
    if [ "${__DRY_RUN_28}" != 0 ]; then
        log_info__0_v0 "Dry run complete; nothing was removed."
        ret_uninstall_vrcosc468_v0=''
        return 0
    fi
    if [ "${removed_3070}" != 0 ]; then
        log_success__1_v0 "VRCOSC successfully uninstalled."
        printf '%s\n' "${__YELLOW_3}Note: Your configurations in AppData/Roaming/VRCOSC have been preserved.${__NC_6}"
    else
        log_info__0_v0 "Nothing found to uninstall."
    fi
}

# VRCOSC automated installer, updater, and runner setup for Bazzite / Linux.
# 
# This is the entry point of the Amber sources that compile to install.sh. Each
# step lives in its own module; this file only decides which of them run.
# Runs the mode the flags asked for. Expected problems are reported and exit on
# the spot; anything that fails unexpectedly propagates out to main, which shows
# the error banner with the exit code.
# run(args: [Text])
run__471_v0() {
    local args_2889=("${!1}")
    parse_arguments__10_v0 args_2889[@]
    if [ "${__INFO_MODE_27}" != 0 ]; then
        show_diagnostics__436_v0 
        exit 0
    fi
    if [ "${__BACKUP_MODE_26}" != 0 ]; then
        create_backup__450_v0 
        __status=$?
        if [ "${__status}" != 0 ]; then
            ret_run471_v0=''
            return "${__status}"
        fi
        exit 0
    fi
    if [ "${__UNINSTALL_MODE_25}" != 0 ]; then
        uninstall_vrcosc__468_v0 
        if [ "${__PURGE_MODE_31}" != 0 ]; then
            purge_vrcosc_config__467_v0 
        fi
        exit 0
    fi
    # --purge on its own deletes settings and stops; it never installs anything,
    # so there is no path where a purge is followed by a surprise install.
    if [ "${__PURGE_MODE_31}" != 0 ]; then
        locate_vrchat_prefix__223_v0 
        purge_vrcosc_config__467_v0 
        exit 0
    fi
    printf '%s\n' "${__BLUE_2}=== VRCOSC Bazzite/Linux Installer ===${__NC_6}"
    check_dependencies__48_v0 
    locate_vrchat_prefix__223_v0 
    warn_if_prefix_busy__252_v0 
    configure_protontricks_permissions__264_v0 
    probe_runtime_mode__257_v0 
    apply_wpf_registry_fix__274_v0 
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_run471_v0=''
        return "${__status}"
    fi
    install_vrcosc__310_v0 
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_run471_v0=''
        return "${__status}"
    fi
    install_dotnet_runtime__330_v0 
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_run471_v0=''
        return "${__status}"
    fi
    apply_channel_settings__346_v0 
    configure_firewall__356_v0 
    install_application_icon__365_v0 
    patch_vrchat_launch_bridge__384_v0 
    create_launchers__399_v0 
    __status=$?
    if [ "${__status}" != 0 ]; then
        ret_run471_v0=''
        return "${__status}"
    fi
}

typeset -r args_158=("$0" "$@")
# args[0] is the script itself.
__length_209=("${args_158[@]}")
slice_upper_208="${#__length_209[@]}"
slice_offset_210=1
slice_offset_210=$((${slice_offset_210} > 0 ? ${slice_offset_210} : 0))
slice_length_211="$(( slice_upper_208 - slice_offset_210 ))"
slice_length_211=$((${slice_length_211} > 0 ? ${slice_length_211} : 0))
range_212=("${args_158[@]:${slice_offset_210}:${slice_length_211}}")
run__471_v0 range_212[@]
__status=$?
if [ "${__status}" != 0 ]; then
    on_error__4_v0 "${__status}"
fi
