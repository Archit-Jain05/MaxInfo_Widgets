// PulseAct: actions for the Pulse control-centre widget. Runs as the user, no window.
//   plan <guid>      switch the active power plan (what the Power Mode extension does)
//   legion <1|2|3>   ask PulseTemps (admin) for Legion mode Quiet / Balanced / Performance
//   temp-size        measure %TEMP%                                -> HKCU\Software\Pulse TempBytes
//   clean-temp       delete everything in %TEMP% that isn't in use -> TempFreed, TempBytes
// Cleaning never follows junctions or symlinks out of %TEMP%; a link is removed, not its target.
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32;

class PulseAct
{
    [DllImport("powrprof.dll")]
    static extern uint PowerSetActiveScheme(IntPtr root, ref Guid scheme);

    static int Main(string[] args)
    {
        if (args.Length == 0) return 1;
        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\Pulse"))
        {
            string temp = Path.GetTempPath();
            switch (args[0])
            {
                case "plan":
                    Guid plan = new Guid(args[1]);
                    return (int)PowerSetActiveScheme(IntPtr.Zero, ref plan);
                case "legion":
                    int mode;
                    if (!int.TryParse(args[1], out mode) || mode < 1 || mode > 3) return 1;
                    key.SetValue("LegionRequest", mode, RegistryValueKind.DWord);
                    return 0;
                case "temp-size":
                    key.SetValue("TempBytes", Size(new DirectoryInfo(temp)).ToString());
                    return 0;
                case "clean-temp":
                    key.SetValue("TempBusy", 1, RegistryValueKind.DWord);
                    long before = Size(new DirectoryInfo(temp));
                    Clean(new DirectoryInfo(temp));
                    long after = Size(new DirectoryInfo(temp));
                    key.SetValue("TempFreed", Math.Max(0, before - after).ToString());
                    key.SetValue("TempBytes", after.ToString());
                    key.SetValue("TempBusy", 0, RegistryValueKind.DWord);
                    return 0;
            }
        }
        return 1;
    }

    static bool IsLink(FileSystemInfo f) { return (f.Attributes & FileAttributes.ReparsePoint) != 0; }

    static long Size(DirectoryInfo dir)
    {
        long total = 0;
        try
        {
            foreach (FileInfo f in dir.EnumerateFiles()) { try { total += f.Length; } catch { } }
            foreach (DirectoryInfo d in dir.EnumerateDirectories()) if (!IsLink(d)) total += Size(d);
        }
        catch { }
        return total;
    }

    // Deletes the contents of dir (not dir itself); anything locked or in use is skipped.
    static void Clean(DirectoryInfo dir)
    {
        try
        {
            foreach (FileInfo f in dir.EnumerateFiles())
            {
                try { f.Attributes = FileAttributes.Normal; f.Delete(); } catch { }
            }
            foreach (DirectoryInfo d in dir.EnumerateDirectories())
            {
                try
                {
                    if (!IsLink(d)) Clean(d);
                    d.Delete(false);   // only succeeds once empty; for a link, removes just the link
                }
                catch { }
            }
        }
        catch { }
    }
}
