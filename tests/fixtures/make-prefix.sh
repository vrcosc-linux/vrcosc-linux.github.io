#!/usr/bin/env bash
# Builds a synthetic Steam library containing a compatdata/438100 prefix, shaped
# closely enough for install.sh to treat it as real. Echoes the compatdata path.
#
#   make-prefix.sh --root DIR [--proton NAME] [--dotnet 9.0.14,8.0.27]
#                             [--tfm net9.0-windows] [--vrcosc-version 2026.807.0]
#                             [--no-vrcosc] [--wpf-patched]
set -euo pipefail

root=""
proton="proton-rtsp-11.0-20260609-4"
proton_ver="11.0-100"
dotnet_runtimes=""
tfm="net9.0-windows"
vrcosc_version="2026.807.0"
install_vrcosc=1
wpf_patched=0
no_frameworks=0

while [ $# -gt 0 ]; do
    case "$1" in
        --root)           root="$2"; shift 2 ;;
        --proton)         proton="$2"; shift 2 ;;
        --proton-version) proton_ver="$2"; shift 2 ;;
        --dotnet)         dotnet_runtimes="$2"; shift 2 ;;
        --tfm)            tfm="$2"; shift 2 ;;
        --vrcosc-version) vrcosc_version="$2"; shift 2 ;;
        --no-vrcosc)      install_vrcosc=0; shift ;;
        --no-frameworks)  no_frameworks=1; shift ;;   # only "tfm" identifies the runtime
        --wpf-patched)    wpf_patched=1; shift ;;
        *) echo "make-prefix.sh: unknown argument: $1" >&2; exit 1 ;;
    esac
done

[ -n "$root" ] || { echo "make-prefix.sh: --root is required" >&2; exit 1; }

steamapps="$root/steamapps"
compatdata="$steamapps/compatdata/438100"
drive_c="$compatdata/pfx/drive_c"
proton_root="$root/compatibilitytools.d/$proton"

mkdir -p "$drive_c/users/steamuser/AppData/Local" \
         "$drive_c/users/steamuser/AppData/Roaming" \
         "$drive_c/Program Files" \
         "$steamapps/common/VRChat" \
         "$proton_root/files/share/fonts"

# Proton build metadata, as Steam writes it.
printf '%s\n%s/files/share/fonts/\n%s/files/lib/\n' \
    "$proton_ver" "$proton_root" "$proton_root" > "$compatdata/config_info"

cat > "$proton_root/toolmanifest.vdf" <<VDF
"manifest"
{
  "version" "2"
  "commandline" "/proton %verb%"
  "require_tool_appid" "4183110"
  "compatmanager_layer_name" "proton"
}
VDF

: > "$compatdata/pfx/user.reg"
: > "$compatdata/pfx/system.reg"
if [ "$wpf_patched" -eq 1 ]; then
    printf '[Software\\\\Microsoft\\\\Avalon.Graphics]\n"DisableHWAcceleration"=dword:00000001\n' \
        > "$compatdata/pfx/user.reg"
fi

# Stub the VRChat launcher so the bridge-patch check has something to look at.
printf 'MZ stub launch.exe\n' > "$steamapps/common/VRChat/launch.exe"

if [ -n "$dotnet_runtimes" ]; then
    dotnet_dir="$drive_c/Program Files/dotnet"
    mkdir -p "$dotnet_dir/shared/Microsoft.WindowsDesktop.App"
    touch "$dotnet_dir/dotnet.exe"
    IFS=',' read -r -a versions <<< "$dotnet_runtimes"
    for v in "${versions[@]}"; do
        mkdir -p "$dotnet_dir/shared/Microsoft.WindowsDesktop.App/$v"
    done
fi

if [ "$install_vrcosc" -eq 1 ]; then
    app_dir="$drive_c/users/steamuser/AppData/Local/VRCOSC"
    mkdir -p "$app_dir"
    touch "$app_dir/VRCOSC.dll"
    major_minor="${tfm#net}"
    major_minor="${major_minor%%-*}"
    if [ "$no_frameworks" -eq 1 ]; then
        cat > "$app_dir/VRCOSC.runtimeconfig.json" <<JSON
{
  "runtimeOptions": {
    "tfm": "$tfm",
    "frameworks": []
  }
}
JSON
    else
        cat > "$app_dir/VRCOSC.runtimeconfig.json" <<JSON
{
  "runtimeOptions": {
    "tfm": "$tfm",
    "frameworks": [
      { "name": "Microsoft.NETCore.App", "version": "${major_minor}.0" },
      { "name": "Microsoft.WindowsDesktop.App", "version": "${major_minor}.0" }
    ]
  }
}
JSON
    fi
    cat > "$app_dir/VRCOSC.deps.json" <<JSON
{ "libraries": { "VRCOSC.App": "$vrcosc_version" } }
JSON
fi

echo "$compatdata"
