# Testing `install.sh`

The installer's failures are almost never logic errors — they are *environment*
errors on machines we do not have. The two bugs that prompted this suite were
both invisible on the developer's Bazzite host:

1. A Linux Mint 22 tester on a custom Proton build hit
   `Fontconfig error: "/etc/fonts/fonts.conf", line 86: out of memory`. There was
   no memory problem; fontconfig reports config *parse* failures with that
   string, and the parse failed because wine was loading Steam Runtime libraries
   while reading host config files. Every wine call in that session was broken,
   so the install "succeeded" and VRCOSC never started.
2. A hardcoded .NET 10.0 channel was installed for a `net9.0` build of VRCOSC.
   .NET does not roll forward across major versions, so the app reported no
   runtime installed while `dotnet.exe` sat in the same prefix.

So the strategy is tiered by *what environment a test needs*, cheapest first.

---

## Tier 1 — offline unit & CLI tests (seconds, run constantly)

```bash
tests/run-unit.sh            # everything
tests/run-unit.sh launcher   # one suite, by filename fragment
```

No network, no Steam, no wine, no root, nothing written outside a `mktemp -d`.
`protontricks` is replaced by `tests/fixtures/fake-protontricks`, whose
`FAKE_PT_PROFILE` selects a host breakage to simulate:

| Profile | Simulates |
| :--- | :--- |
| `clean` | every runtime mode works |
| `fontconfig-mismatch` | only `--no-runtime` works — the Mint 22 tester's host |
| `bwrap-broken` | bwrap nesting fails, as under flatpak protontricks |
| `all-broken` | nothing works; the installer must fail loudly |
| `version-fails` | `protontricks --version` exits non-zero (pipx build) |

`tests/fixtures/make-prefix.sh` builds a synthetic `compatdata/438100` — Proton
`config_info`, a `toolmanifest.vdf`, registries, a chosen set of installed .NET
runtimes and a `VRCOSC.runtimeconfig.json` for a chosen TFM. That combination is
what makes the interesting cases cheap: "app wants 9.0, prefix has 10.0.7" is one
flag, not a VM.

The fake logs every invocation's argv **and** which environment variables
survived into it, which is how the tests assert that the Steam Runtime scrubbing
actually happens rather than just that the code looks right.

Covered here: argument parsing, `--info` completing under failing probes, runtime
mode selection and flag mapping, environment scrubbing, .NET channel detection
and verification, launcher generation and the launcher's own runtime behaviour,
offline `--dry-run`.

**Add a Tier 1 test for every bug fixed.** Each one in `tests/unit/` names the
field failure it pins down.

## Tier 2 — distro matrix in throwaway containers (minutes, before a release)

```bash
tests/run-container-matrix.sh                        # offline, all images
tests/run-container-matrix.sh --online               # also a full real install
GITHUB_TOKEN=$(gh auth token) tests/run-container-matrix.sh --online
tests/run-container-matrix.sh --engine distrobox     # interactive-friendly
tests/run-container-matrix.sh --images "docker.io/library/ubuntu:24.04" --keep
```

Runs the Tier 1 suite plus `--info`, `--dry-run` and (with `--online`) a complete
install inside Ubuntu 24.04 (Mint 22's base), Debian 13, Fedora 42 and Arch.

This tier exists because *userland* differs: bash 5.1 vs 5.3, BusyBox-ish vs GNU
`grep`/`sed`/`awk`, whether `python3` exists at all, and fontconfig versions. The
installer's `--info` JSON parsing already has a python3 path and a grep fallback
specifically because of this, and only this tier exercises the fallback on a
machine that genuinely lacks python3.

Isolation matters here. Under `--engine podman` the repo is mounted read-only and
`$HOME` is inside the container. Under `--engine distrobox`, the script passes
`--home` a throwaway directory — **without that, distrobox shares your real
`$HOME`** and the installer would write a launcher and desktop entry into it.
Prefer podman for automated runs and distrobox when you want to poke around
afterwards; `--keep` leaves the container up and prints how to enter it.

`--online` exercises the real GitHub and .NET download paths. Export
`GITHUB_TOKEN` (or `GH_TOKEN`) for it: the unauthenticated GitHub API limit is 60
requests per hour per address, and without a token the step reports
`SKIP: GitHub API rate-limited this host` rather than failing the image.

`--real-wine` additionally installs that distro's wine and fontconfig, which is
the closest a container gets to reproducing the library/config mismatch class of
bug without Steam.

**Cannot cover:** real Proton, Steam Runtime pairing, bwrap nesting under flatpak
protontricks, the flatpak sandbox permission overrides, GPU/WPF rendering, the
`launch.exe` bridge against a real VRChat install. Do not claim those are tested
because the matrix is green.

## Tier 3 — VM (hours, rarely, by hand)

Only a VM with Steam actually installed validates the parts above. Keep two, both
with libvirt (`virsh` and `virt-install` are already on this host):

* **Linux Mint 22 / Ubuntu 24.04**, KDE or Cinnamon, X11 — the reference
  "reporter's machine". pipx protontricks, and a custom Proton such as
  proton-rtsp in `compatibilitytools.d`.
* **Bazzite** — the immutable, flatpak-protontricks, Wayland case, where bwrap
  nesting and the flatpak overrides behave differently from anything above.

Workflow:

```bash
# once, per VM
virt-install --name vrcosc-mint --memory 8192 --vcpus 4 --disk size=60 \
    --cdrom /path/to/linuxmint-22-cinnamon-64bit.iso --os-variant ubuntu24.04

# after Steam + a Proton build + one VRChat prefix exist, snapshot the clean state
virsh snapshot-create-as vrcosc-mint clean-steam "Steam + Proton + 438100 prefix"

# per test run
virsh start vrcosc-mint
#   ... run install.sh, check VRCOSC actually opens a window ...
virsh snapshot-revert vrcosc-mint clean-steam
```

Snapshot-revert is the whole point: an installer test is destructive and the
expensive part (Steam, a Proton build, a real prefix) must not be rebuilt each
time. VRChat itself is not required — any app id with a prefix works if you point
`--prefix` at it; only the `launch.exe` bridge check needs the real game.

What to verify manually in Tier 3, because nothing else can:

- `--info` reports the right Proton build and a working runtime mode
- a fresh install produces a VRCOSC window that renders (the WPF
  `DisableHWAcceleration` patch is about exactly this)
- the desktop entry launches from the application menu, not just the terminal
- `--runtime container` under flatpak protontricks — pass or fail, but known
- `--uninstall` then `--backup` on a populated config directory

Record the outcome in the pull request rather than relying on memory; Tier 3 runs
are infrequent enough that "it worked last time" is not evidence.

---

## CI

Tier 1 is CI-ready as-is: `shellcheck` plus `tests/run-unit.sh`, no privileges.
Tier 2 runs in CI too — `run-container-matrix.sh` shells out to `podman`, which
GitHub Actions runners provide; use `--online` there, since a runner has network
and the real download paths are worth exercising on every release.
