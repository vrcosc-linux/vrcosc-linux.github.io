#!/usr/bin/env bash
# Tier 2: run the installer's own test suite, plus --info and a full install
# against a synthetic prefix, inside throwaway containers for several distros.
#
# What this tier is for: userland differences. bash, grep, sed, awk, coreutils,
# python3 presence and fontconfig versions all vary between distros, and that is
# where the installer has actually broken in the field (a Linux Mint 22 tester
# hit a fontconfig/library mismatch that never reproduced on Bazzite).
#
# What it cannot cover: real Proton, Steam Runtime pairing, bwrap nesting,
# flatpak protontricks, GPU/WPF rendering. Those need Tier 3 -- see tests/README.md.
#
# Usage:
#   tests/run-container-matrix.sh [--engine podman|distrobox] [--images "a b"]
#                                 [--online] [--keep] [--real-wine]
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
REPO_ROOT="$PWD"

ENGINE="podman"
IMAGES="docker.io/library/ubuntu:24.04 docker.io/library/debian:13 registry.fedoraproject.org/fedora:42 docker.io/library/archlinux:latest"
ONLINE=0
KEEP=0
REAL_WINE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --engine)     ENGINE="$2"; shift 2 ;;
        --images)     IMAGES="$2"; shift 2 ;;
        --online)     ONLINE=1; shift ;;
        --keep)       KEEP=1; shift ;;
        --real-wine)  REAL_WINE=1; shift ;;
        -h|--help)    sed -n '2,25p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

command -v "$ENGINE" >/dev/null || { echo "$ENGINE is not installed." >&2; exit 1; }

# Dependency install per package manager, discovered at run time rather than
# keyed off the image name.
read -r -d '' GUEST_SETUP <<'GUEST' || true
set -eu
if command -v apt-get >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends curl unzip ca-certificates python3 >/dev/null
elif command -v dnf >/dev/null; then
    dnf install -y -q curl unzip python3 >/dev/null
elif command -v pacman >/dev/null; then
    pacman -Sy --noconfirm --quiet curl unzip python >/dev/null
else
    echo "no known package manager in this image" >&2
    exit 1
fi
GUEST

read -r -d '' GUEST_WINE <<'GUEST' || true
set -eu
if command -v apt-get >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -qq --no-install-recommends wine fontconfig >/dev/null
elif command -v dnf >/dev/null; then
    dnf install -y -q wine-core fontconfig >/dev/null
elif command -v pacman >/dev/null; then
    pacman -S --noconfirm --quiet wine fontconfig >/dev/null
fi
GUEST

# The body run inside each container. $ONLINE/$REAL_WINE are interpolated by the
# host; everything else is guest-side.
build_guest_script() {
    cat <<GUEST
set -eu
cd /work
export HOME=/guest-home
mkdir -p "\$HOME"

echo "--- distro: \$(. /etc/os-release && echo "\$PRETTY_NAME")"
echo "--- bash:   \$BASH_VERSION"
echo "--- python: \$(command -v python3 || echo none)"
echo "--- fontconfig: \$(command -v fc-match >/dev/null && fc-match --version 2>&1 | head -n 1 || echo 'not installed')"

# Tier 1 suite, on this distro's shell and userland.
bash tests/run-unit.sh

# Again with python3 hidden, so the grep fallbacks in get_required_dotnet_channel
# and the --info release lookup are exercised on a host that genuinely lacks it.
echo ""
echo "--- tests/run-unit.sh without python3"
mkdir -p "\$HOME/nopython"
printf '#!/bin/sh\nexit 127\n' > "\$HOME/nopython/python3"
chmod +x "\$HOME/nopython/python3"
PATH="\$HOME/nopython:\$PATH" bash tests/run-unit.sh

PREFIX="\$(tests/fixtures/make-prefix.sh --root "\$HOME/steam" --dotnet 9.0.14 --tfm net9.0-windows)"
mkdir -p "\$HOME/bin"
ln -sf /work/tests/fixtures/fake-protontricks "\$HOME/bin/protontricks"
export PATH="\$HOME/bin:\$PATH"
export FAKE_PT_LOG="\$HOME/pt.log"
export FAKE_PT_PREFIX="\$PREFIX"

echo ""
echo "--- install.sh --info"
bash install.sh --info --prefix "\$PREFIX" | tail -n 30

echo ""
echo "--- install.sh --dry-run"
bash install.sh --dry-run --skip-firewall --prefix "\$PREFIX" >/dev/null
test ! -e "\$HOME/.local/bin/vrcosc" || { echo "FAIL: --dry-run created a launcher"; exit 1; }
echo "OK: --dry-run wrote nothing"

if [ "$ONLINE" = "1" ]; then
    echo ""
    echo "--- install.sh (full, real downloads, fake wine)"
    export FAKE_PT_INSTALLS_RUNTIME=auto
    install_rc=0
    bash install.sh --skip-firewall --prefix "\$PREFIX" --runtime host \
        > "\$HOME/install.log" 2>&1 || install_rc=\$?
    cat "\$HOME/install.log"

    if [ "\$install_rc" -ne 0 ]; then
        # An unauthenticated runner sharing an IP with others gets 403ed by the
        # GitHub API. That is the host's situation, not a regression.
        if grep -qE 'error: 403|rate limit' "\$HOME/install.log"; then
            echo "SKIP: GitHub API rate-limited this host; full install not exercised"
        else
            echo "FAIL: install.sh exited \$install_rc"
            exit 1
        fi
    else
        test -x "\$HOME/.local/bin/vrcosc" || { echo "FAIL: no launcher created"; exit 1; }
        bash -n "\$HOME/.local/bin/vrcosc" || { echo "FAIL: launcher is not valid shell"; exit 1; }
        grep -q -- '--no-runtime' "\$HOME/.local/bin/vrcosc" || { echo "FAIL: launcher lost its runtime flags"; exit 1; }
        test -f "\$PREFIX/pfx/drive_c/users/steamuser/AppData/Local/VRCOSC/VRCOSC.dll" \
            || { echo "FAIL: VRCOSC was not unpacked into the prefix"; exit 1; }
        echo "OK: full install produced a valid launcher"
    fi
fi

if [ "$REAL_WINE" = "1" ] && command -v wine >/dev/null; then
    echo ""
    echo "--- real wine against a poisoned environment"
    # Reproduces the field failure shape: a library path that does not match this
    # host's fontconfig config. The installer must scrub it; an unscrubbed call
    # is what produced 'Fontconfig error: ... out of memory' for a tester.
    LD_LIBRARY_PATH=/nonexistent/runtime/lib wine --version || true
fi

echo ""
echo "=== PASS \$(. /etc/os-release && echo "\$PRETTY_NAME")"
GUEST
}

run_podman() {
    local image="$1" name
    name="vrcosc-test-$(echo "$image" | tr '/:.' '---')"
    podman rm -f "$name" >/dev/null 2>&1 || true

    local -a net=()
    [ "$ONLINE" -eq 1 ] || net=(--network=none)

    # Dependencies need the network even for an offline test run.
    podman run --name "$name" --detach --replace \
        --volume "$REPO_ROOT:/work:ro,z" \
        "$image" sleep infinity >/dev/null

    podman exec "$name" sh -c "$GUEST_SETUP"
    [ "$REAL_WINE" -eq 1 ] && podman exec "$name" sh -c "$GUEST_WINE"

    # Re-create with the requested network policy now that packages are in.
    if [ ${#net[@]} -gt 0 ]; then
        podman commit "$name" "localhost/${name}-prepared" >/dev/null
        podman rm -f "$name" >/dev/null
        podman run --name "$name" --detach --replace "${net[@]}" \
            --volume "$REPO_ROOT:/work:ro,z" \
            "localhost/${name}-prepared" sleep infinity >/dev/null
    fi

    local rc=0
    podman exec ${GITHUB_TOKEN:+--env GITHUB_TOKEN="$GITHUB_TOKEN"} \
        "$name" bash -c "$(build_guest_script)" || rc=$?

    if [ "$KEEP" -eq 0 ]; then
        podman rm -f "$name" >/dev/null 2>&1 || true
        podman rmi -f "localhost/${name}-prepared" >/dev/null 2>&1 || true
    else
        echo "    (kept container: podman exec -it $name bash)"
    fi
    return $rc
}

run_distrobox() {
    local image="$1" name guest_home
    name="vrcosc-test-$(echo "$image" | tr '/:.' '---')"
    guest_home="$(mktemp -d "/tmp/${name}-home.XXXXXX")"

    distrobox rm -f "$name" >/dev/null 2>&1 || true
    # --home is not optional: without it distrobox shares the real $HOME and the
    # installer would write a launcher and desktop entry into it.
    distrobox create --yes --name "$name" --image "$image" \
        --home "$guest_home" >/dev/null
    distrobox enter "$name" -- sh -c "sudo sh -c '$GUEST_SETUP'"
    [ "$REAL_WINE" -eq 1 ] && distrobox enter "$name" -- sh -c "sudo sh -c '$GUEST_WINE'"

    local rc=0
    distrobox enter "$name" -- bash -c \
        "cd '$REPO_ROOT' && $(build_guest_script | sed 's|/work|'"$REPO_ROOT"'|g; s|/guest-home|'"$guest_home"'|g')" || rc=$?

    if [ "$KEEP" -eq 0 ]; then
        distrobox rm -f "$name" >/dev/null 2>&1 || true
        rm -rf "$guest_home"
    else
        echo "    (kept container: distrobox enter $name ; home: $guest_home)"
    fi
    return $rc
}

failed=()
for image in $IMAGES; do
    echo ""
    echo "############################################################"
    echo "# $image ($ENGINE)"
    echo "############################################################"
    if [ "$ENGINE" = "distrobox" ]; then
        run_distrobox "$image" || failed+=("$image")
    else
        run_podman "$image" || failed+=("$image")
    fi
done

echo ""
if [ ${#failed[@]} -eq 0 ]; then
    printf '\033[0;32mAll images passed\033[0m\n'
    exit 0
fi
printf '\033[0;31mFailed images: %s\033[0m\n' "${failed[*]}"
exit 1
