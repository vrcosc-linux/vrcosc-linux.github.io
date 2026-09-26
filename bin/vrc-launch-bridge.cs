// Drop-in replacement for VRChat's launch.exe under Proton.
//
// VRChat's own launcher talks to the running game over the named pipe
// \\.\pipe\VRChatURLLaunchPipe. Under Proton that call fails, so vrchat:// links
// and in-game navigation from companion tools do nothing. This writes to the
// pipe directly and falls back to the stock launcher, kept beside it as
// launch.org.exe, whenever the game is not there to answer.
//
// Wine named pipes belong to a single wine session, so this only works from
// inside VRChat's own session.
//
// Build:
//   dotnet build -c Release   (see bin/bridge.csproj; net40, x86, console)

using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

class Program {
    // install.sh and the generated launcher identify a bridge by grepping the
    // binary for this string, so that they never back up a launch.exe that is
    // already a bridge -- which would make the bridge its own fallback and let
    // RunOriginal() re-enter it without bound.
    //
    // In the first build this string was present only because the assembly
    // happened to be named launch_bridge_ready. It is a const here so that the
    // guard does not depend on a build setting nobody would think to check, and
    // bin/bridge.csproj keeps the assembly name as well for older detection.
    const string BridgeMarker = "launch_bridge_ready";

    // How long to wait for the game to acknowledge the URL. The read used to
    // block with no timeout, so a game that accepted the write and never
    // answered left the URL handler stuck forever with nothing on screen.
    const int AckTimeoutMs = 5000;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern SafeFileHandle CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );

    static int Main(string[] args) {
        if (args.Length == 1 && args[0] == "--bridge-marker") {
            // Lets the tests assert on the marker by asking, rather than by
            // grepping and hoping the string came from where they think.
            Console.Out.WriteLine(BridgeMarker);
            return 0;
        }

        if (args.Length == 0) {
            return RunOriginal(args);
        }

        string rawArg = args[0];
        // Clean launch URL if needed
        string url = rawArg;
        if (url.Contains("&attach=1")) {
            url = url.Replace("&attach=1", "");
        }

        try {
            var handle = CreateFile(
                @"\\.\pipe\VRChatURLLaunchPipe",
                0xC0000000, // GENERIC_READ | GENERIC_WRITE
                0,
                IntPtr.Zero,
                3, // OPEN_EXISTING
                0,
                IntPtr.Zero
            );

            if (!handle.IsInvalid) {
                using (var fs = new FileStream(handle, FileAccess.ReadWrite)) {
                    byte[] data = Encoding.UTF8.GetBytes(url);
                    fs.Write(data, 0, data.Length);
                    fs.Flush();
                    if (ReadAck(fs)) {
                        return 0; // successfully delivered to running game
                    }
                }
            }
        } catch {
            // Ignore and fall back to original
        }

        return RunOriginal(args);
    }

    // True when the game answered with the one-byte acknowledgement. A timeout
    // counts as no answer, which puts us on the same path as an explicit refusal:
    // hand the arguments to the stock launcher, which is the thing that knows how
    // to deal with a game that is running but not responding.
    static bool ReadAck(FileStream fs) {
        byte[] resp = new byte[1];
        try {
            // The read runs on a thread pool thread, which is a background thread,
            // so it cannot hold the process open if it never returns.
            IAsyncResult ar = fs.BeginRead(resp, 0, 1, null, null);
            if (!ar.AsyncWaitHandle.WaitOne(AckTimeoutMs)) {
                Console.Error.WriteLine(
                    "vrc-launch-bridge: VRChat did not acknowledge the URL within "
                    + (AckTimeoutMs / 1000) + "s; falling back to the original launcher.");
                return false;
            }
            return fs.EndRead(ar) > 0 && resp[0] == 1;
        } catch {
            return false;
        }
    }

    static int RunOriginal(string[] args) {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string origExe = Path.Combine(dir, "launch.org.exe");
        if (!File.Exists(origExe)) {
            // Exiting 0 here told the caller the launch had succeeded when nothing
            // had happened at all. Say what is wrong and fail, so the failure
            // surfaces where it can be acted on.
            Console.Error.WriteLine(
                "vrc-launch-bridge: launch.org.exe is missing from " + dir + ", so there is "
                + "no original launcher to run. Use Steam's 'Verify integrity of game files' "
                + "on VRChat to restore it.");
            return 1;
        }

        try {
            var psi = new ProcessStartInfo {
                FileName = origExe,
                Arguments = BuildCommandLine(args),
                UseShellExecute = false
            };
            using (var p = Process.Start(psi)) {
                p.WaitForExit();
                return p.ExitCode;
            }
        } catch (Exception ex) {
            Console.Error.WriteLine("vrc-launch-bridge: could not start " + origExe + ": " + ex.Message);
            return 1;
        }
    }

    // Joining on a space lost the argument boundaries: one path with a space in it
    // arrived at the stock launcher as several arguments. This quotes each argument
    // the way CommandLineToArgvW parses it back.
    static string BuildCommandLine(string[] args) {
        var sb = new StringBuilder();
        for (int i = 0; i < args.Length; i++) {
            if (i > 0) sb.Append(' ');
            AppendArgument(sb, args[i]);
        }
        return sb.ToString();
    }

    static void AppendArgument(StringBuilder sb, string arg) {
        if (arg.Length > 0 && arg.IndexOfAny(new[] { ' ', '\t', '"' }) < 0) {
            sb.Append(arg);
            return;
        }

        sb.Append('"');
        for (int i = 0; i < arg.Length; i++) {
            // A run of backslashes is only special before a quote, where each one
            // has to be doubled so the quote is not escaped by accident.
            int slashes = 0;
            while (i < arg.Length && arg[i] == '\\') { slashes++; i++; }

            if (i == arg.Length) {
                sb.Append('\\', slashes * 2);   // before the closing quote
                break;
            }
            if (arg[i] == '"') {
                sb.Append('\\', slashes * 2 + 1);
                sb.Append('"');
            } else {
                sb.Append('\\', slashes);
                sb.Append(arg[i]);
            }
        }
        sb.Append('"');
    }
}
