# Wine session sharing: what VRCOSC can and cannot reach

Measured on a live system (Bazzite, proton-rtsp 11.0-20260609-2, VRChat 438100 in
desktop mode, flatpak protontricks), 2026-09-25. This exists because the question
"can VRCOSC live in its own prefix and still talk to VRChat?" cannot be answered
from reasoning alone, and because the first answer we assumed was wrong.

## The one thing that decides everything

A wine prefix's wineserver is keyed on the prefix directory's `st_dev` + `st_ino`,
as `/tmp/.wine-$UID/server-<dev>-<ino>/`. Two wine processes share a session only
if they resolve that to the same socket **and** can see it. So "same prefix" does
not imply "same session" — a sandbox that bind-mounts the prefix, or provides its
own `/tmp`, produces a second, fully independent wineserver on the same files.

Everything wine implements *inside* the wineserver is therefore per-session:

| Channel | Implemented by | Crosses sessions? |
| :--- | :--- | :--- |
| `Process.GetProcessesByName("vrchat")` | wineserver process table | **No** |
| Named pipes (`\\.\pipe\...`) | wineserver | **No** |
| `Global\` mutexes | wineserver | **No** |
| `GetForegroundWindow` / window handles | wineserver + winex11 | **No** |
| Process FPS, module lists, `OpenProcess` | wineserver | **No** |
| OSC (UDP 9000/9001), OSCQuery HTTP, mDNS 5353 | host kernel sockets | **Yes** |
| Log files, avatar OSC config JSON | host filesystem | **Yes** (symlink) |

The network half is not a guess: every wine process runs in the host's network
namespace. Verified by comparing `/proc/<pid>/ns/net` of a wine process with the
shell's — identical (`net:[4026531833]`), while only `mnt` differed for the
pressure-vessel side. There is no network isolation to cross.

## What VRCOSC actually uses

From `VRCOSC.App` (source-code/main):

* `AppManager.isVRChatOpen()` and `VRChatClient.HasOpenStateChanged()` both use
  `Process.GetProcessesByName("vrchat")`. This is the master gate: `IsOpen` false
  means `IsLoggedIn`, `IsInInstance`, `IsInAvatar` are false and `User`, `Avatar`
  and `Instance` are forced to null.
* `VRChatClient.FPS` calls `ProcessFPS.GetProcessFPS(clientProcess)` on that
  process handle.
* `ProcessExtensions.GetForegroundProcess()` (used by `ForegroundProcessNode`)
  needs the game's windows in the same session.
* `VRChatLogReader` reads `AppData/LocalLow/VRChat/VRChat/output_log_*`, and
  `AvatarConfigLoader` reads `AppData/LocalLow/VRChat/VRChat/OSC` — plain files.
* `vrchat://` navigation goes out through `Uri.OpenExternally()` →
  `Process.Start(UseShellExecute: true)` → wine's URL handler → `launch.exe` →
  `\\.\pipe\VRChatURLLaunchPipe`. That pipe is the reason this repo patches
  `launch.exe` at all, and it is session-bound.
* `VRCOSC_IPC` and `Global\VRCOSC_SingleInstanceMutex` are VRCOSC talking to
  itself, so they do not care where VRChat lives.

## Measurements

With VRChat running in desktop mode:

| Launch method | VRCOSC starts | Joins VRChat's wineserver | `tasklist` sees `VRChat.exe` |
| :--- | :--- | :--- | :--- |
| `protontricks --no-bwrap -c wine …` (what this repo installs) | yes | no, starts a 2nd server | **no** (reproduced twice) |
| `protontricks-launch --appid 438100 …` | yes | no, starts a 2nd server | no |
| `wine` directly, `WINEPREFIX` = canonical host path | **crashes in Velopack** | **yes** | **yes** |

The direct-wine row is the interesting one: it is the only method that lands in
VRChat's session, and `tasklist` there listed `VRChat.exe` (pid 496, 4.0 GB). It
is also the only method that reproduced the user-reported crash:

```
System.ComponentModel.Win32Exception (5): Access denied.
   at System.Diagnostics.NtProcessManager.EnumProcessModulesUntilSuccess(...)
   at Velopack.Locators.DefaultProcessImpl.GetCurrentProcessPath()
   at Velopack.VelopackApp.Run()
```

That launch used a deliberately minimal environment and bypassed the `proton`
script entirely, so it is not yet established whether the crash comes from
joining a session that already contains VRChat or from the missing Proton
environment. **This is the open question.** The two candidates are distinguishable
by running the same direct-wine launch with Proton's own environment restored,
once with VRChat running and once without.

If the crash does track session sharing, it explains the conflicting field
reports exactly: flatpak protontricks (separate session) coexists but never
detects VRChat, while an unsandboxed pipx protontricks (shared session) detects
VRChat but cannot start while it runs.

## Resolution (measured 2026-09-26)

The crash is a **user-namespace boundary**, not the environment. VRChat's
wineserver runs inside pressure-vessel's user namespace (`uid_map: 1000 1000 1`).
Launching with VRChat's *exact* captured environment from the host still crashed
identically; the wineserver simply cannot read the memory of a process outside
its user namespace, and `EnumProcessModules` is the first call that needs it.

Unprivileged `nsenter -t <VRChat pid> -U -m --preserve-credentials` works (we own
the namespace). From inside:

| Check | Result |
| :--- | :--- |
| `wine tasklist` | `VRChat.exe` (pid 496) **and** `dotnet.exe` (VRCOSC) in one session |
| wineservers on the host | 1 |
| Velopack `Access denied` | 0 |
| VRCOSC window | yes |
| VRCOSC log | `Reading log file: ...output_log_2026-09-25_23-33-18.txt` (the live game log) |

This is what the launcher now does when VRChat is running. When it is not, the
protontricks path remains, and VRCOSC runs standalone in its own session.

The two field reports are both explained: flatpak protontricks always yields a
separate session (coexists, never detects); an unsandboxed protontricks can
connect to the game's wineserver from outside its user namespace and dies in
Velopack. Neither ever had VRChat detection.

## What this means for a separate prefix

A separate prefix keeps OSC, OSCQuery and log/config reading — those cross freely,
and a `LocalLow/VRChat` symlink covers the files. It loses VRChat process
detection, FPS, foreground-window checks and `vrchat://` navigation.

The important caveat: **the current installer already loses all of those**, because
protontricks already runs VRCOSC in its own session. Moving to a separate prefix
would not give up capability that works today; it would make explicit what is
already true, and remove the contention. Recovering process detection is a
separate problem from prefix layout, and needs a launch method that joins
VRChat's session.

## Reproducing

`experiments/oscquery-probe.py` advertises `_oscjson._tcp` and `_osc._udp` over
mDNS and serves an OSCQuery tree from the host, entirely outside any wine prefix.
If VRChat talks to it, the OSC half of the table is confirmed end to end. It has
**not** yet been run against a live VRChat.

The session questions are answered with `tasklist`, which needs no build step:

```bash
PFX=<library>/steamapps/compatdata/438100/pfx
# what a protontricks-launched VRCOSC can see:
protontricks --no-bwrap -c "wine tasklist" 438100
# what a session-joining launch can see:
WINEPREFIX="$PFX" <proton>/files/bin/wine tasklist
```
