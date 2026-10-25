// PulseTemps: publishes data for the Pulse Rainmeter widgets to HKCU\Software\Pulse. Runs hidden.
//  - CpuTemp/GpuTemp: Lenovo GameZone WMI (needs admin), every 2 s.
//  - Devices: connected devices with a battery, every 2 s, as "name|level|kind|charging;..."
//    from Bluetooth device properties (SetupAPI) and Phone Link's Start menu card.
//  - Lat/Lon: Windows Location (Wi-Fi positioning), every 15 min, for the weather widget.
//  - CodexFive/CodexWeek (+Reset): last rate limits Codex logged in ~/.codex/sessions, every 30 s.
//  - ScreenTotal/ScreenHours/ScreenApps: today's screen time per app and per hour (local only).
//  - Edge bumps: resting the cursor on the left screen edge opens Widgets, the right edge the
//    notification centre (own thread, polls the cursor every 50 ms).
//  - Clips each Pulse card's window to its rounded card shape, so the blur behind it can't show
//    past the border (Rainmeter drops the clip when a skin reloads, so it's re-applied every 2 s).
//  - Moves desktop icons that end up under a widget to the nearest free grid cell, every 2 s.
using System;
using System.Collections.Generic;
using System.Device.Location;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;
using Microsoft.Win32;

class PulseTemps
{
    static void Main()
    {
        bool first;
        using (new Mutex(true, @"Local\PulseTemps", out first))
        {
            if (!first) return;

            ManagementObject gz = null;
            try
            {
                foreach (ManagementObject o in new ManagementObjectSearcher(@"root\WMI", "SELECT * FROM LENOVO_GAMEZONE_DATA").Get())
                    gz = o;
            }
            catch { }

            SetProcessDPIAware();   // real pixels, for the card clips and the screen edges
            new Thread(EdgeLoop) { IsBackground = true }.Start();
            RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\Pulse");
            var location = new Timer(_ => WriteLocation(key), null, 0, 15 * 60 * 1000);
            var codex = new Timer(_ => WriteCodex(key), null, 0, 30 * 1000);
            while (true)
            {
                if (gz != null)
                {
                    key.SetValue("CpuTemp", ReadInt(gz, "GetCPUTemp"), RegistryValueKind.DWord);
                    key.SetValue("GpuTemp", ReadInt(gz, "GetGPUTemp"), RegistryValueKind.DWord);
                    ApplyLegionRequest(gz, key);
                    key.SetValue("LegionMode", ReadInt(gz, "GetSmartFanMode"), RegistryValueKind.DWord);
                }
                try { key.SetValue("Devices", ReadDevices()); } catch { }
                try { ClipCards(); } catch { }
                try { KeepIconsClear(); } catch { }
                try { SampleScreenTime(key); } catch { }
                Thread.Sleep(2000);
            }
        }
    }

    // One short fix per call so the location service isn't kept running between updates.
    static void WriteLocation(RegistryKey key)
    {
        try
        {
            using (var geo = new GeoCoordinateWatcher(GeoPositionAccuracy.High))
            {
                if (!geo.TryStart(false, TimeSpan.FromSeconds(15))) return;
                for (int i = 0; i < 30 && geo.Position.Location.IsUnknown; i++) Thread.Sleep(500);
                GeoCoordinate c = geo.Position.Location;
                if (c.IsUnknown) return;
                key.SetValue("Lat", c.Latitude.ToString("F4", CultureInfo.InvariantCulture));
                key.SetValue("Lon", c.Longitude.ToString("F4", CultureInfo.InvariantCulture));
            }
        }
        catch { }
    }

    // Codex logs a rate_limits object with each token count; use the newest one it wrote.
    static void WriteCodex(RegistryKey key)
    {
        try
        {
            string file = NewestLog(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), @".codex\sessions"), 3);
            if (file == null) return;
            string tail = Tail(file, 512 * 1024);
            int at = tail.LastIndexOf("\"rate_limits\"", StringComparison.Ordinal);
            if (at < 0) return;
            string limits = tail.Substring(at);
            foreach (string[] w in new[] { new[] { "primary", "CodexFive" }, new[] { "secondary", "CodexWeek" } })
            {
                Match window = Regex.Match(limits, "\"" + w[0] + "\"\\s*:\\s*\\{([^}]*)\\}");
                if (!window.Success) continue;
                Match pct = Regex.Match(window.Groups[1].Value, "\"used_percent\"\\s*:\\s*([\\d.]+)");
                Match reset = Regex.Match(window.Groups[1].Value, "\"resets_at\"\\s*:\\s*(\\d+)");
                if (pct.Success)
                    key.SetValue(w[1], ((int)Math.Round(double.Parse(pct.Groups[1].Value, CultureInfo.InvariantCulture))).ToString(CultureInfo.InvariantCulture));
                if (reset.Success) key.SetValue(w[1] + "Reset", reset.Groups[1].Value);
            }
        }
        catch { }
    }

    // Newest *.jsonl in Codex's year/month/day folder tree.
    static string NewestLog(string dir, int depth)
    {
        if (!Directory.Exists(dir)) return null;
        if (depth == 0)
        {
            string best = null;
            DateTime newest = DateTime.MinValue;
            foreach (string f in Directory.GetFiles(dir, "*.jsonl"))
            {
                DateTime t = File.GetLastWriteTimeUtc(f);
                if (t > newest) { newest = t; best = f; }
            }
            return best;
        }
        string[] subs = Directory.GetDirectories(dir);
        Array.Sort(subs, StringComparer.Ordinal);
        for (int i = subs.Length - 1; i >= 0; i--)
        {
            string f = NewestLog(subs[i], depth - 1);
            if (f != null) return f;
        }
        return null;
    }

    static string Tail(string path, int bytes)
    {
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        {
            long start = Math.Max(0, fs.Length - bytes);
            fs.Seek(start, SeekOrigin.Begin);
            var buf = new byte[fs.Length - start];
            int read = 0;
            while (read < buf.Length) { int n = fs.Read(buf, read, buf.Length - read); if (n <= 0) break; read += n; }
            return Encoding.UTF8.GetString(buf, 0, read);
        }
    }

    // The control-centre widget (via PulseAct, as the user) asks for a Legion mode here;
    // setting it needs admin, which this process has. Only 1-3 (Quiet/Balanced/Performance) pass.
    static void ApplyLegionRequest(ManagementObject gz, RegistryKey key)
    {
        object req = key.GetValue("LegionRequest");
        if (req == null) return;
        key.DeleteValue("LegionRequest", false);
        if (req is int && (int)req >= 1 && (int)req <= 3)
        {
            try { gz.InvokeMethod("SetSmartFanMode", new object[] { (uint)(int)req }); } catch { }
        }
    }

    static int ReadInt(ManagementObject gz, string method)
    {
        try { return Convert.ToInt32(gz.InvokeMethod(method, null, null)["Data"]); }
        catch { return 0; }
    }

    // ---- Screen time ---------------------------------------------------------------------

    // The app in front gets the time since the last sample, unless nobody has touched the keyboard
    // or mouse for IDLE_MS (a full-screen app such as a video still counts). The desktop, taskbar
    // and lock screen don't count. Each day is kept in %LOCALAPPDATA%\Pulse\ScreenTime\<date>.tsv
    // so a restart doesn't lose it; nothing leaves the PC.
    const int IDLE_MS = 5 * 60 * 1000;

    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public int cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumWindowsProc proc, IntPtr lParam);

    static string screenDay;
    static readonly Dictionary<string, double> appSeconds = new Dictionary<string, double>();
    static readonly double[] hourSeconds = new double[24];
    static readonly Dictionary<uint, string> appNames = new Dictionary<uint, string>();
    static DateTime lastSample = DateTime.MinValue, lastSave = DateTime.MinValue;

    static string ScreenTimeFile(string day)
    {
        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Pulse\ScreenTime");
        Directory.CreateDirectory(dir);
        return Path.Combine(dir, day + ".tsv");
    }

    static void SampleScreenTime(RegistryKey key)
    {
        DateTime now = DateTime.Now;
        string day = now.ToString("yyyy-MM-dd");
        if (screenDay != day)
        {
            if (screenDay != null) SaveScreenTime();
            LoadScreenTime(day);
        }
        double dt = lastSample == DateTime.MinValue ? 0 : (now - lastSample).TotalSeconds;
        lastSample = now;
        if (dt > 10) dt = 0;   // the PC slept, or the loop stalled

        string app = dt > 0 ? ForegroundApp() : null;
        if (app != null && (!Idle() || FullScreenInFront()))
        {
            double seconds;
            appSeconds.TryGetValue(app, out seconds);
            appSeconds[app] = seconds + dt;
            hourSeconds[now.Hour] += dt;
        }

        double total = 0;
        foreach (double s in appSeconds.Values) total += s;
        var top = new List<KeyValuePair<string, double>>(appSeconds);
        top.Sort((a, b) => b.Value.CompareTo(a.Value));
        var apps = new List<string>();
        for (int i = 0; i < top.Count && i < 12; i++) apps.Add(top[i].Key + "|" + (int)top[i].Value);
        var hours = new string[24];
        for (int h = 0; h < 24; h++) hours[h] = ((int)hourSeconds[h]).ToString(CultureInfo.InvariantCulture);
        key.SetValue("ScreenTotal", ((int)total).ToString(CultureInfo.InvariantCulture));
        key.SetValue("ScreenHours", string.Join(",", hours));
        key.SetValue("ScreenApps", string.Join(";", apps.ToArray()));
        key.SetValue("ScreenWeek", WeekTotals(now, total));

        if ((now - lastSave).TotalSeconds >= 60) { SaveScreenTime(); lastSave = now; }
    }

    // Totals for the last 7 days, oldest first, as "yyyy-MM-dd|seconds;...". Past days come from
    // their saved files and don't change, so they're read once.
    static readonly Dictionary<string, double> pastDays = new Dictionary<string, double>();

    static string WeekTotals(DateTime now, double today)
    {
        var parts = new List<string>();
        for (int back = 6; back >= 0; back--)
        {
            string day = now.AddDays(-back).ToString("yyyy-MM-dd");
            double secs = today;
            if (back > 0 && !pastDays.TryGetValue(day, out secs))
            {
                secs = 0;
                string file = ScreenTimeFile(day);
                if (File.Exists(file))
                    foreach (string line in File.ReadAllLines(file))
                    {
                        string[] f = line.Split('\t');
                        double s;
                        if (f.Length == 3 && f[0] == "A" && double.TryParse(f[2], NumberStyles.Float, CultureInfo.InvariantCulture, out s)) secs += s;
                    }
                pastDays[day] = secs;
            }
            parts.Add(day + "|" + ((int)secs).ToString(CultureInfo.InvariantCulture));
        }
        return string.Join(";", parts.ToArray());
    }

    static bool Idle()
    {
        var info = new LASTINPUTINFO { cbSize = Marshal.SizeOf(typeof(LASTINPUTINFO)) };
        return GetLastInputInfo(ref info) && unchecked((uint)Environment.TickCount - info.dwTime) > IDLE_MS;
    }

    // Friendly name of the app in front, or null for the desktop, taskbar and lock screen.
    static string ForegroundApp()
    {
        IntPtr h = GetForegroundWindow();
        if (h == IntPtr.Zero) return null;
        var cls = new StringBuilder(64);
        GetClassName(h, cls, cls.Capacity);
        string c = cls.ToString();
        if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd") return null;
        uint pid;
        GetWindowThreadProcessId(h, out pid);
        if (c == "ApplicationFrameWindow")   // Store apps: the real app owns a child window
        {
            uint host = pid;
            EnumChildWindows(h, (child, _) =>
            {
                uint p;
                GetWindowThreadProcessId(child, out p);
                if (p != host) { pid = p; return false; }
                return true;
            }, IntPtr.Zero);
        }
        string name;
        if (appNames.TryGetValue(pid, out name)) return name;
        if (appNames.Count > 500) appNames.Clear();
        try
        {
            using (Process p = Process.GetProcessById((int)pid))
            {
                // lock screen, and the desktop widgets themselves (clicking them is using the desktop)
                if (p.ProcessName == "LockApp" || p.ProcessName == "Rainmeter") return null;
                name = p.ProcessName;
                try
                {
                    string desc = p.MainModule.FileVersionInfo.FileDescription;
                    if (!string.IsNullOrWhiteSpace(desc)) name = desc.Trim();
                }
                catch { }
            }
        }
        catch { return null; }
        name = Friendly(Clean(name));
        appNames[pid] = name;
        return name;
    }

    // Shorter names for apps whose file description is awkward.
    static string Friendly(string name)
    {
        if (name == "Windows Explorer") return "File Explorer";
        if (name == "Windows Terminal Host") return "Windows Terminal";
        return name;
    }

    static void SaveScreenTime()
    {
        var lines = new List<string>();
        for (int h = 0; h < 24; h++) lines.Add("H\t" + h + "\t" + ((int)hourSeconds[h]).ToString(CultureInfo.InvariantCulture));
        foreach (var kv in appSeconds) lines.Add("A\t" + kv.Key + "\t" + ((int)kv.Value).ToString(CultureInfo.InvariantCulture));
        File.WriteAllLines(ScreenTimeFile(screenDay), lines.ToArray());
    }

    static void LoadScreenTime(string day)
    {
        screenDay = day;
        appSeconds.Clear();
        Array.Clear(hourSeconds, 0, 24);
        string file = ScreenTimeFile(day);
        if (!File.Exists(file)) return;
        foreach (string line in File.ReadAllLines(file))
        {
            string[] f = line.Split('\t');
            double s;
            if (f.Length != 3 || !double.TryParse(f[2], NumberStyles.Float, CultureInfo.InvariantCulture, out s)) continue;
            int h;
            if (f[0] == "H" && int.TryParse(f[1], out h) && h >= 0 && h < 24) hourSeconds[h] = s;
            else if (f[0] == "A" && f[1] != "Rainmeter desktop customization tool")
            {
                double had;
                appSeconds.TryGetValue(Friendly(f[1]), out had);
                appSeconds[Friendly(f[1])] = had + s;
            }
        }
    }

    // ---- Edge bumps ----------------------------------------------------------------------

    // The cursor touching the left screen edge opens Widgets, the right edge the notification
    // centre, straight away and with Windows' own panel animations. Not while a mouse button is
    // held (dragging a scrollbar or resizing a window at the edge), once per touch until the
    // cursor moves REARM px away, and off while a full-screen app (game, video) is in front.
    const int REARM = 40;

    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern void keybd_event(byte key, byte scan, int flags, IntPtr extra);

    static void EdgeLoop()
    {
        bool fired = false;
        while (true)
        {
            Thread.Sleep(20);
            try
            {
                POINT p;
                if (!GetCursorPos(out p)) continue;
                int width = GetSystemMetrics(0);   // SM_CXSCREEN, primary screen
                if (fired)
                {
                    if (p.X > REARM && p.X < width - 1 - REARM) fired = false;
                    continue;
                }
                int at = p.X <= 0 ? -1 : p.X >= width - 1 ? 1 : 0;
                bool button = (GetAsyncKeyState(0x01) & 0x8000) != 0 || (GetAsyncKeyState(0x02) & 0x8000) != 0;
                if (at == 0 || button || FullScreenInFront()) continue;
                if (at < 0) OpenWidgets(); else WinShortcut((byte)'N');
                fired = true;
            }
            catch { }
        }
    }

    // Win+W isn't wired to Widgets on this build, and the ms-widgets: link opens the new full-screen
    // board, so press the taskbar's Widgets button through UI Automation: exactly what a click opens.
    static AutomationElement widgetsButton;

    static void OpenWidgets()
    {
        for (int attempt = 0; attempt < 2; attempt++)
        {
            try
            {
                if (widgetsButton == null)
                {
                    AutomationElement tray = AutomationElement.RootElement.FindFirst(TreeScope.Children,
                        new PropertyCondition(AutomationElement.ClassNameProperty, "Shell_TrayWnd"));
                    widgetsButton = tray.FindFirst(TreeScope.Descendants,
                        new PropertyCondition(AutomationElement.AutomationIdProperty, "WidgetsButton"));
                }
                var toggle = (TogglePattern)widgetsButton.GetCurrentPattern(TogglePattern.Pattern);
                if (toggle.Current.ToggleState != ToggleState.On) toggle.Toggle();
                return;
            }
            catch { widgetsButton = null; }   // taskbar restarted: look the button up again
        }
    }

    static void WinShortcut(byte key)
    {
        const byte WIN = 0x5B; const int UP = 0x2;
        keybd_event(WIN, 0, 0, IntPtr.Zero);
        keybd_event(key, 0, 0, IntPtr.Zero);
        keybd_event(key, 0, UP, IntPtr.Zero);
        keybd_event(WIN, 0, UP, IntPtr.Zero);
    }

    // A window covering the whole screen, taskbar included (maximized windows stop at the taskbar).
    static bool FullScreenInFront()
    {
        IntPtr h = GetForegroundWindow();
        if (h == IntPtr.Zero) return false;
        var cls = new StringBuilder(64);
        GetClassName(h, cls, cls.Capacity);
        string c = cls.ToString();
        if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd") return false;
        RECT r;
        GetWindowRect(h, out r);
        return r.Left <= 0 && r.Top <= 0 && r.Right >= GetSystemMetrics(0) && r.Bottom >= GetSystemMetrics(1);
    }

    // ---- Card clips ----------------------------------------------------------------------

    delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc proc, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] static extern int GetWindowRgnBox(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] static extern int SetWindowRgn(IntPtr hwnd, IntPtr region, bool redraw);
    [DllImport("gdi32.dll")] static extern IntPtr CreatePolygonRgn(POINT[] points, int count, int fillMode);

    static readonly Dictionary<IntPtr, string> clipped = new Dictionary<IntPtr, string>();

    // One corner of the iOS-style rounded rectangle, as in Squircle.lua: (kind, end, control points)
    // in radii; kind 0 = line, 1 = cubic.
    static readonly double[][] Corner = {
        new[] { 0, 1.52866483, 0 },
        new[] { 1, 0.66993427, 0.06549600, 1.08849296, 0, 0.86840694, 0 },
        new[] { 0, 0.63149399, 0.07491100 },
        new[] { 1, 0.07491100, 0.63149399, 0.37282392, 0.16905899, 0.16905899, 0.37282392 },
        new[] { 0, 0.06549600, 0.66993427 },
        new[] { 1, 0, 1.52866483, 0, 0.86840694, 0, 1.08849296 },
    };

    static void ClipCards()
    {
        double radius = CardRadius();
        EnumWindows((hwnd, _) =>
        {
            var cls = new StringBuilder(64);
            var title = new StringBuilder(512);
            GetClassName(hwnd, cls, cls.Capacity);
            GetWindowText(hwnd, title, title.Capacity);
            string t = title.ToString();
            // every Pulse card except the clock, which has no card or blur
            if (cls.ToString() != "RainmeterMeterWindow" || t.IndexOf(@"\Skins\Pulse\", StringComparison.OrdinalIgnoreCase) < 0
                || t.IndexOf(@"\Pulse\Clock\", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            RECT r, box;
            GetWindowRect(hwnd, out r);
            string shape = (r.Right - r.Left) + "x" + (r.Bottom - r.Top) + "@" + radius;
            string had;
            bool hasClip = GetWindowRgnBox(hwnd, out box) > 1;   // SIMPLEREGION or COMPLEXREGION
            if (!hasClip || !clipped.TryGetValue(hwnd, out had) || had != shape)
            {
                POINT[] pts = CardOutline(r.Right - r.Left, r.Bottom - r.Top, radius);
                SetWindowRgn(hwnd, CreatePolygonRgn(pts, pts.Length, 2), true);   // the window owns the region
                clipped[hwnd] = shape;
            }
            return true;
        }, IntPtr.Zero);
    }

    // ---- Desktop icons -------------------------------------------------------------------
    // Keeps desktop icons out from under the widgets: an icon overlapping a visible Pulse window
    // (the clock too; not the screen time popup, which comes and goes) moves to the first free
    // grid cell, scanning columns top to bottom from the left like Explorer. Works on the desktop's
    // list view in Explorer, reading positions through memory allocated in Explorer's process.
    // Skipped with auto-arrange on (Explorer would pack them straight back) or mid-drag.

    const int LVM_GETITEMCOUNT = 0x1004, LVM_GETITEMRECT = 0x100E, LVM_SETITEMPOSITION = 0x100F,
        LVM_GETITEMPOSITION = 0x1010, LVM_GETITEMSPACING = 0x1033;
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool ScreenToClient(IntPtr hwnd, ref POINT point);
    [DllImport("user32.dll")] static extern bool SystemParametersInfo(int action, int param, out RECT rect, int winIni);
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr proc, IntPtr addr, IntPtr size, int type, int protect);
    [DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr proc, IntPtr addr, IntPtr size, int type);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr proc, IntPtr addr, int[] buf, IntPtr size, IntPtr read);
    [DllImport("kernel32.dll")] static extern bool WriteProcessMemory(IntPtr proc, IntPtr addr, int[] buf, IntPtr size, IntPtr written);

    static IntPtr DesktopListView()
    {
        IntPtr view = FindWindowEx(FindWindowEx(IntPtr.Zero, IntPtr.Zero, "Progman", null), IntPtr.Zero, "SHELLDLL_DefView", null);
        for (IntPtr w = IntPtr.Zero; view == IntPtr.Zero && (w = FindWindowEx(IntPtr.Zero, w, "WorkerW", null)) != IntPtr.Zero; )
            view = FindWindowEx(w, IntPtr.Zero, "SHELLDLL_DefView", null);
        return view == IntPtr.Zero ? IntPtr.Zero : FindWindowEx(view, IntPtr.Zero, "SysListView32", null);
    }

    static bool Overlaps(RECT a, RECT b) { return a.Left < b.Right && b.Left < a.Right && a.Top < b.Bottom && b.Top < a.Bottom; }
    static RECT Offset(RECT r, int dx, int dy) { r.Left += dx; r.Right += dx; r.Top += dy; r.Bottom += dy; return r; }

    static RECT ToClient(IntPtr hwnd, RECT r)
    {
        var a = new POINT { X = r.Left, Y = r.Top }; var b = new POINT { X = r.Right, Y = r.Bottom };
        ScreenToClient(hwnd, ref a); ScreenToClient(hwnd, ref b);
        return new RECT { Left = a.X, Top = a.Y, Right = b.X, Bottom = b.Y };
    }

    static void KeepIconsClear()
    {
        if (GetAsyncKeyState(0x01) < 0) return;   // an icon may be mid-drag
        object flags = Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Bags\1\Desktop", "FFlags", 0);
        if (flags is int && ((int)flags & 1) != 0) return;   // auto-arrange
        IntPtr lv = DesktopListView();
        if (lv == IntPtr.Zero || !IsWindowVisible(lv)) return;   // no desktop, or icons hidden
        int count = (int)SendMessage(lv, LVM_GETITEMCOUNT, IntPtr.Zero, IntPtr.Zero);
        if (count == 0) return;

        // the widgets, in list view coordinates, with a little breathing room
        var walls = new List<RECT>();
        EnumWindows((hwnd, _) =>
        {
            var cls = new StringBuilder(64);
            var title = new StringBuilder(512);
            GetClassName(hwnd, cls, cls.Capacity);
            GetWindowText(hwnd, title, title.Capacity);
            string t = title.ToString();
            if (cls.ToString() == "RainmeterMeterWindow" && IsWindowVisible(hwnd)
                && t.IndexOf(@"\Skins\Pulse\", StringComparison.OrdinalIgnoreCase) >= 0
                && t.IndexOf(@"\Pulse\ScreenTimeDetail\", StringComparison.OrdinalIgnoreCase) < 0)
            {
                RECT r;
                GetWindowRect(hwnd, out r);
                if (r.Right > r.Left) walls.Add(ToClient(lv, new RECT { Left = r.Left - 6, Top = r.Top - 6, Right = r.Right + 6, Bottom = r.Bottom + 6 }));
            }
            return true;
        }, IntPtr.Zero);
        if (walls.Count == 0) return;

        uint pid;
        GetWindowThreadProcessId(lv, out pid);
        IntPtr proc = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);   // VM_OPERATION | VM_READ | VM_WRITE
        if (proc == IntPtr.Zero) return;
        IntPtr mem = VirtualAllocEx(proc, IntPtr.Zero, (IntPtr)16, 0x3000, 0x04);   // MEM_COMMIT | MEM_RESERVE, READWRITE
        try
        {
            if (mem == IntPtr.Zero) return;
            var pos = new POINT[count];
            var box = new RECT[count];
            var buf = new int[4];
            for (int i = 0; i < count; i++)
            {
                SendMessage(lv, LVM_GETITEMPOSITION, (IntPtr)i, mem);
                ReadProcessMemory(proc, mem, buf, (IntPtr)8, IntPtr.Zero);
                pos[i] = new POINT { X = buf[0], Y = buf[1] };
                buf[0] = 0;   // LVIR_BOUNDS: icon and label
                WriteProcessMemory(proc, mem, buf, (IntPtr)4, IntPtr.Zero);
                SendMessage(lv, LVM_GETITEMRECT, (IntPtr)i, mem);
                ReadProcessMemory(proc, mem, buf, (IntPtr)16, IntPtr.Zero);
                box[i] = new RECT { Left = buf[0], Top = buf[1], Right = buf[2], Bottom = buf[3] };
            }

            // grid: Explorer's icon spacing, anchored where the icons already sit (snap to grid)
            int spacing = (int)SendMessage(lv, LVM_GETITEMSPACING, IntPtr.Zero, IntPtr.Zero);
            int cx = spacing & 0xFFFF, cy = (spacing >> 16) & 0xFFFF;
            if (cx == 0 || cy == 0) return;
            RECT work;
            SystemParametersInfo(0x0030, 0, out work, 0);   // SPI_GETWORKAREA: the screen minus the taskbar
            work = ToClient(lv, work);
            int ox = ((pos[0].X - work.Left) % cx + cx) % cx + work.Left, oy = ((pos[0].Y - work.Top) % cy + cy) % cy + work.Top;

            for (int i = 0; i < count; i++)
            {
                if (!walls.Exists(w => Overlaps(w, box[i]))) continue;
                for (int x = ox; x + cx <= work.Right; x += cx)
                    for (int y = oy; y + cy <= work.Bottom; y += cy)
                    {
                        RECT moved = Offset(box[i], x - pos[i].X, y - pos[i].Y);
                        if (moved.Left < work.Left || moved.Top < work.Top || moved.Right > work.Right || moved.Bottom > work.Bottom) continue;
                        if (walls.Exists(w => Overlaps(w, moved))) continue;
                        bool taken = false;
                        for (int j = 0; j < count && !taken; j++) taken = j != i && Overlaps(box[j], moved);
                        if (taken) continue;
                        SendMessage(lv, LVM_SETITEMPOSITION, (IntPtr)i, (IntPtr)((y << 16) | (x & 0xFFFF)));
                        pos[i] = new POINT { X = x, Y = y };
                        box[i] = moved;
                        goto next;
                    }
                next: ;
            }
        }
        finally
        {
            if (mem != IntPtr.Zero) VirtualFreeEx(proc, mem, IntPtr.Zero, 0x8000);   // MEM_RELEASE
            CloseHandle(proc);
        }
    }

    // Corner radius in pixels: Radius x S from the shared Theme.inc.
    static double CardRadius()
    {
        double s = 1.25, radius = 17;
        try
        {
            string theme = File.ReadAllText(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                @"Rainmeter\Skins\Pulse\@Resources\Theme.inc"));
            Match ms = Regex.Match(theme, @"(?m)^S=([\d.]+)"), mr = Regex.Match(theme, @"(?m)^Radius=([\d.]+)");
            if (ms.Success) s = double.Parse(ms.Groups[1].Value, CultureInfo.InvariantCulture);
            if (mr.Success) radius = double.Parse(mr.Groups[1].Value, CultureInfo.InvariantCulture);
        }
        catch { }
        return radius * s;
    }

    static POINT[] CardOutline(double w, double h, double r)
    {
        var pts = new List<POINT>();
        double[][] corners = {   // corner point, then directions along the incoming (u) and outgoing (v) edges
            new double[] { w, 0, 1, 0, 0, 1 }, new double[] { w, h, 0, 1, -1, 0 }, new double[] { 0, h, -1, 0, 0, -1 }, new double[] { 0, 0, 0, -1, 1, 0 } };
        double px = 1.52866483 * r, py = 0;
        pts.Add(Pt(px, py));
        foreach (double[] c in corners)
            foreach (double[] seg in Corner)
            {
                Func<double, double, double[]> at = (a, b) => new[] { c[0] - a * r * c[2] + b * r * c[4], c[1] - a * r * c[3] + b * r * c[5] };
                double[] end = at(seg[1], seg[2]);
                if (seg[0] == 0) pts.Add(Pt(end[0], end[1]));
                else
                {
                    double[] c1 = at(seg[3], seg[4]), c2 = at(seg[5], seg[6]);
                    for (int i = 1; i <= 10; i++)
                    {
                        double t = i / 10.0, u = 1 - t;
                        pts.Add(Pt(u * u * u * px + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t * t * t * end[0],
                                   u * u * u * py + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t * t * t * end[1]));
                    }
                }
                px = end[0]; py = end[1];
            }
        return pts.ToArray();
    }

    static POINT Pt(double x, double y) { return new POINT { X = (int)Math.Round(x), Y = (int)Math.Round(y) }; }

    // ---- Devices -------------------------------------------------------------------------

    class Dev { public string Name; public int Level = -1, LeLevel = -1; public bool Connected, LeConnected, Charging; public uint Cod; }

    static string ReadDevices()
    {
        var byName = new Dictionary<string, Dev>(StringComparer.OrdinalIgnoreCase);
        foreach (Dev d in ReadBluetooth())
            if (d.Connected && d.Level >= 0 && d.Name != null)
                Merge(byName, d);
        Dev phone = ReadPhoneLink();
        if (phone != null) byName[phone.Name] = phone;   // 1% steps beat Bluetooth's 10% steps

        var parts = new List<string>();
        foreach (Dev d in byName.Values)
            parts.Add(Clean(d.Name) + "|" + d.Level + "|" + Kind(d) + "|" + (d.Charging ? 1 : 0));
        parts.Sort(StringComparer.OrdinalIgnoreCase);
        return string.Join(";", parts.ToArray());
    }

    static void Merge(Dictionary<string, Dev> byName, Dev d)
    {
        Dev old;
        if (!byName.TryGetValue(d.Name, out old) || d.Level > old.Level) byName[d.Name] = d;
    }

    static string Clean(string s) { return s.Replace("|", " ").Replace(";", " ").Trim(); }

    // Phone Link writes an Adaptive Card for the Start menu with the phone's name and battery.
    static readonly Regex PlBattery = new Regex(@"Battery (\d+)%");
    static readonly Regex PlName = new Regex("\"text\":\"((?:[^\"\\\\]|\\\\.){1,60})\"");

    static Dev ReadPhoneLink()
    {
        if (Process.GetProcessesByName("PhoneExperienceHost").Length == 0) return null;
        string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            @"Packages\Microsoft.YourPhone_8wekyb3d8bbwe\LocalState\StartMenu\StartMenuCompanion.json");
        if (!File.Exists(path)) return null;
        string card = File.ReadAllText(path);
        Match level = PlBattery.Match(card), name = PlName.Match(card);
        if (!card.Contains("Connected to your PC") || !level.Success || !name.Success) return null;
        return new Dev
        {
            Name = Regex.Unescape(name.Groups[1].Value),
            Level = int.Parse(level.Groups[1].Value),
            Charging = card.IndexOf("charging", StringComparison.OrdinalIgnoreCase) >= 0,
            Cod = 0x200,   // phone
        };
    }

    // Bluetooth: one device has several device nodes (classic, LE, profiles); group them by MAC.
    [StructLayout(LayoutKind.Sequential)]
    struct DevInfo { public int cbSize; public Guid ClassGuid; public int DevInst; public IntPtr Reserved; }

    [StructLayout(LayoutKind.Sequential)]
    struct PropKey { public Guid Fmtid; public int Pid; public PropKey(string g, int p) { Fmtid = new Guid(g); Pid = p; } }

    [DllImport("setupapi.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr SetupDiGetClassDevsW(IntPtr cls, string enumerator, IntPtr hwnd, int flags);
    [DllImport("setupapi.dll")]
    static extern bool SetupDiEnumDeviceInfo(IntPtr set, int index, ref DevInfo info);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode)]
    static extern bool SetupDiGetDeviceInstanceIdW(IntPtr set, ref DevInfo info, StringBuilder id, int size, out int required);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode)]
    static extern bool SetupDiGetDevicePropertyW(IntPtr set, ref DevInfo info, ref PropKey key, out int type, byte[] buf, int size, out int required, int flags);
    [DllImport("setupapi.dll")]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);

    static readonly PropKey KeyConnected = new PropKey("83DA6326-97A6-4088-9453-A1923F573B29", 15);
    static readonly PropKey KeyBattery = new PropKey("104EA319-6EE2-4701-BD47-8DDBF425BBE5", 2);
    static readonly PropKey KeyCharging = new PropKey("104EA319-6EE2-4701-BD47-8DDBF425BBE5", 3);   // undocumented
    static readonly PropKey KeyName = new PropKey("A45C254E-DF1C-4EFD-8020-67D146A850E0", 14);   // FriendlyName (DEVPKEY_NAME isn't served by SetupAPI)
    static readonly PropKey KeyClassOfDevice = new PropKey("2BD67D8B-8BEB-48D5-87E0-6CDA3428040A", 4);
    static readonly Regex Mac = new Regex("[0-9A-F]{12}", RegexOptions.RightToLeft | RegexOptions.IgnoreCase);

    static IEnumerable<Dev> ReadBluetooth()
    {
        var byMac = new Dictionary<string, Dev>(StringComparer.OrdinalIgnoreCase);
        foreach (string enumerator in new[] { "BTHENUM", "BTHLE" })
        {
            IntPtr set = SetupDiGetClassDevsW(IntPtr.Zero, enumerator, IntPtr.Zero, 0x2 | 0x4);   // PRESENT | ALLCLASSES
            if (set == new IntPtr(-1)) continue;
            var info = new DevInfo { cbSize = Marshal.SizeOf(typeof(DevInfo)) };
            for (int i = 0; SetupDiEnumDeviceInfo(set, i, ref info); i++)
            {
                var sb = new StringBuilder(512);
                int req;
                if (!SetupDiGetDeviceInstanceIdW(set, ref info, sb, sb.Capacity, out req)) continue;
                string id = sb.ToString();
                Match m = Mac.Match(id);
                if (!m.Success || m.Value.Trim('0').Length == 0) continue;

                Dev d;
                if (!byMac.TryGetValue(m.Value, out d)) byMac[m.Value] = d = new Dev();
                byte[] b;
                bool le = enumerator == "BTHLE";
                bool nodeConnected = (b = Prop(set, ref info, KeyConnected)) != null && b[0] != 0;
                if (nodeConnected) { d.Connected = true; if (le) d.LeConnected = true; }
                // Dual-mode devices (e.g. headphones with LE Audio) keep a stale LE battery reading while
                // only the classic link is up, so LE and classic levels are kept apart (resolved below).
                if ((b = Prop(set, ref info, KeyBattery)) != null)
                {
                    if (le) d.LeLevel = Math.Max(d.LeLevel, b[0]);
                    else d.Level = Math.Max(d.Level, b[0]);
                }
                if ((b = Prop(set, ref info, KeyCharging)) != null && b[0] != 0) d.Charging = true;
                if (id.IndexOf(@"\DEV_", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    if ((b = Prop(set, ref info, KeyName)) != null) d.Name = Encoding.Unicode.GetString(b).TrimEnd('\0');
                    if ((b = Prop(set, ref info, KeyClassOfDevice)) != null && b.Length >= 4) d.Cod = BitConverter.ToUInt32(b, 0);
                }
            }
            SetupDiDestroyDeviceInfoList(set);
        }
        // Trust the LE reading only while LE is connected, or when it's the only one there is.
        foreach (Dev d in byMac.Values)
            if (d.LeLevel >= 0 && (d.LeConnected || d.Level < 0)) d.Level = d.LeLevel;
        return byMac.Values;
    }

    static byte[] Prop(IntPtr set, ref DevInfo info, PropKey key)
    {
        var buf = new byte[512];
        int type, req;
        if (!SetupDiGetDevicePropertyW(set, ref info, ref key, out type, buf, buf.Length, out req, 0)) return null;
        Array.Resize(ref buf, req);
        return buf;
    }

    // Icon kind from the Bluetooth class of device, falling back to the name.
    static string Kind(Dev d)
    {
        string n = d.Name.ToLowerInvariant();
        if (n.Contains("bud") || n.Contains("pods")) return "earbuds";
        uint major = (d.Cod >> 8) & 0x1F, minor = (d.Cod >> 2) & 0x3F;
        if (major == 2) return "phone";
        if (major == 4) return minor == 5 ? "speaker" : "headphones";
        if (major == 5)
        {
            if ((minor & 0x20) != 0) return "mouse";
            if ((minor & 0x10) != 0) return "keyboard";
            return "gamepad";
        }
        if (Regex.IsMatch(n, "mouse|pebble|\\bmx ")) return "mouse";
        if (Regex.IsMatch(n, "keyboard|keys")) return "keyboard";
        if (Regex.IsMatch(n, "controller|dualsense|xbox|gamepad")) return "gamepad";
        if (Regex.IsMatch(n, "speaker|charge|flip|\\bgo \\d|boom|soundlink|mhc")) return "speaker";
        if (Regex.IsMatch(n, "headphone|live|wh-|xm\\d|bose|tune")) return "headphones";
        if (Regex.IsMatch(n, "phone|galaxy|pixel|\\bs\\d\\d")) return "phone";
        return "other";
    }
}
