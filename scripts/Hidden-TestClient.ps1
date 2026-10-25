# Run graphics tests on a private Windows desktop. Never switch the input desktop.
if (-not ('ETBudget.HiddenClient' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace ETBudget
{
    public sealed class HiddenClient : IDisposable
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct StartupInfo
        {
            public int cb;
            public string reserved;
            public string desktop;
            public string title;
            public int x, y, width, height, xChars, yChars, fill, flags;
            public short showWindow, reservedSize;
            public IntPtr reservedPointer, stdin, stdout, stderr;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct ProcessInfo
        {
            public IntPtr process, thread;
            public int processId, threadId;
        }
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr mode, int flags, uint access, IntPtr security);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool CloseDesktop(IntPtr desktop);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr OpenInputDesktop(int flags, bool inherit, uint access);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool GetUserObjectInformation(IntPtr handle, int index, StringBuilder info, int length, out int needed);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcess(string app, StringBuilder command, IntPtr processSecurity, IntPtr threadSecurity, bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInfo info);
        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);

        private IntPtr desktop;
        public Process Process { get; private set; }
        public string DesktopName { get; private set; }

        private HiddenClient() { }

        public static string InputDesktopName()
        {
            IntPtr handle = OpenInputDesktop(0, false, 1);
            if (handle == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            try
            {
                int needed;
                StringBuilder name = new StringBuilder(256);
                if (!GetUserObjectInformation(handle, 2, name, name.Capacity * 2, out needed)) throw new Win32Exception(Marshal.GetLastWin32Error());
                return name.ToString();
            }
            finally { CloseDesktop(handle); }
        }

        public static HiddenClient Start(string executable, string arguments, string directory)
        {
            HiddenClient result = new HiddenClient();
            result.DesktopName = "ETBudgetTest_" + Guid.NewGuid().ToString("N");
            result.desktop = CreateDesktop(result.DesktopName, IntPtr.Zero, IntPtr.Zero, 0, 0x01FF, IntPtr.Zero);
            if (result.desktop == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            StartupInfo startup = new StartupInfo();
            startup.cb = Marshal.SizeOf(typeof(StartupInfo));
            startup.desktop = "WinSta0\\" + result.DesktopName;
            startup.flags = 1;
            startup.showWindow = 0;
            ProcessInfo info;
            if (!CreateProcess(executable, new StringBuilder("\"" + executable + "\" " + arguments), IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, directory, ref startup, out info))
            {
                int error = Marshal.GetLastWin32Error();
                result.Dispose();
                throw new Win32Exception(error);
            }
            try
            {
                result.Process = Process.GetProcessById(info.processId);
                IntPtr retained = result.Process.Handle;
            }
            finally
            {
                CloseHandle(info.thread);
                CloseHandle(info.process);
            }
            return result;
        }

        public void Dispose()
        {
            if (desktop != IntPtr.Zero)
            {
                CloseDesktop(desktop);
                desktop = IntPtr.Zero;
            }
        }
    }
}
'@
}

function Start-HiddenTestClient {
    param([string]$Executable, [string[]]$Arguments, [string]$Directory)
    # Disable audio initialization, not just playback volume. Preserve rendering.
    $Arguments += @('+set', 's_initsound', '0', '+set', 's_volume', '0', '+set', 's_musicvolume', '0',
        '+set', 'com_maxfpsUnfocused', '60', '+set', 'com_maxfpsMinimized', '60')
    return [ETBudget.HiddenClient]::Start($Executable, ($Arguments -join ' '), $Directory)
}
