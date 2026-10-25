# Pulse

A set of black-glass desktop widgets for [Rainmeter](https://www.rainmeter.net/) on Windows 10/11:
square cards on a shared grid, Apple-style continuous corners, frosted blur, SF Pro type and smooth
animations. Everything idles at near-zero CPU.

## Widgets

| Widget | Size | What it shows | Interactions |
| :--- | :--- | :--- | :--- |
| **CPU** · **Memory** | 1×1 | Usage ring that shifts colour with load, temperature¹, sparkline | Hover: busiest process |
| **dGPU** · **iGPU** | 1×1 | Per-GPU usage (Task Manager's method), temperature¹ | Hover: per-engine breakdown |
| **Battery** | 2×1 | Laptop plus Bluetooth devices and your phone (via Phone Link)², with charging state. Tiles slide in and out as devices connect | Scroll for a second row when more than 4 devices are connected · double-click: Bluetooth settings |
| **Network** | 1×1 | Download and upload speed with a graph | Hover: local IP · double-click: network settings |
| **Weather** | 1×1 | Current conditions, feels-like, high/low ([Open-Meteo](https://open-meteo.com/), no key) | |
| **Calendar** | 2×1 | Today plus the month grid | Scroll: change month · click the left side: back to today |
| **AI limits** | 2×2 | 5-hour and weekly usage per Claude account (needs [cswap](#ai-limits)) and Codex² | Hover: reset time |
| **GitHub** | 2×2 | Last 3 months of contributions, totals, public repos, best day (public data, no token) | Double-click: your profile |
| **Screen time** | 2×1 | Today's total, hourly bars, top apps² | Click: a full breakdown in the centre of the screen |
| **Control bar** | 2×½ | Power plan, Legion mode¹, temp-file cleaner, Galaxy Buds battery², Quick Share | Click an icon to open its options in place |
| **Clock** | | macOS lock-screen style date and time | Double-click: Clock app |

¹ Lenovo Legion / LOQ laptops only (read from Lenovo's GameZone WMI interface).
² Needs the [helper](#the-helper-optional).

## Install

1. Install [Rainmeter 4.5+](https://www.rainmeter.net/).
2. Download `Pulse_x.y.z.rmskin` from [Releases](../../releases) and double-click it. Keep **Apply included layout** ticked.
3. **Blur:** install the [FrostedGlass](https://github.com/TheAzack9/FrostedGlass) plugin. It isn't bundled because it has no license that allows redistribution. Without it the cards still work, as plain tinted black.
4. **Font:** the widgets use **SF Pro Display** (Regular, Medium, Bold). Install it, or use another font by changing `Font`, `FontSemi` and `FontNumber` in `@Resources\Theme.inc` (and the two faces in `Clock\Clock.ini`), e.g. `Segoe UI Variable Display`.
5. Optional: install [the helper](#the-helper-optional) for temperatures, devices, screen time and more.

The layout is made for **1920×1080 at 125% scaling** with the taskbar at the top. On other screens, drag the widgets where you want them. To resize everything, change `S` (the scale) in `@Resources\Theme.inc`.

## The helper (optional)

`PulseTemps.exe` is a small background program (C#, source included) that feeds the widgets data Rainmeter can't read itself. It writes everything to `HKCU\Software\Pulse`.

| Feature | Details |
| :--- | :--- |
| CPU/GPU temperatures, Legion mode | Lenovo GameZone WMI (Legion/LOQ only; needs admin) |
| Device batteries | Bluetooth device properties plus Phone Link's phone card, every 2 s |
| Location | Windows Location, every 15 min, so the weather follows you |
| Screen time | Foreground app every ~2 s, not counting idle time. Stored only on this PC in `%LOCALAPPDATA%\Pulse\ScreenTime` |
| Codex limits | Reads the newest `~/.codex/sessions` log |
| Card corners | Clips each card's window to its rounded shape, so the blur doesn't show past the corners |
| Desktop icons | Moves any desktop icon that lands under a widget to the nearest free spot (skipped with auto-arrange) |
| Edge bumps | Cursor on the left screen edge opens Widgets; the right edge opens the notification centre |

**Install:** from an **admin** PowerShell:

```powershell
cd "$env:USERPROFILE\Documents\Rainmeter\Skins\Pulse\@Resources\PulseTemps"
powershell -ExecutionPolicy Bypass -File install-helper.ps1
```

It copies the helper to `C:\Program Files\PulseTemps` and adds a scheduled task that starts it at every sign-in with admin rights (Lenovo's WMI needs them). Remove it with `install-helper.ps1 -Uninstall`.

`PulseAct.exe` runs at user level and handles the control bar's actions (switch power plan, ask the helper for a Legion mode, measure and clean `%TEMP%`).

## Configure

| What | Where |
| :--- | :--- |
| GitHub username | `User=` in `GitHub\GitHub.ini` |
| Weather location without the helper | `Lat` / `Lon` in `@Resources\Location.inc` |
| Scale, corner radius, colours, glass tint, fonts | `@Resources\Theme.inc` |
| Power plans in the control bar | `PLANS` in `@Resources\ControlBar.lua` and the plan buttons in `Control\Control.ini` (the third is Lenovo's *Legion Performance Mode*) |

### AI limits

Claude rows come from `cswap list --json` (`claude-swap`, a multi-account switcher for Claude Code; it must be on your `PATH`), run every minute. Without it, only the Codex row shows.

## Privacy

Nothing leaves your PC except requests to Open-Meteo (your rounded coordinates, for the weather) and GitHub (the public profile you set). Screen time and everything else the helper collects stays in your user registry and `%LOCALAPPDATA%\Pulse`.

## Build

```powershell
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

This compiles both helpers with the C# compiler built into Windows (.NET Framework 4.x) and writes `dist\Pulse_<version>.rmskin`. The version comes from `RMSKIN.ini`.

## Credits

- Blur: [FrostedGlass](https://github.com/TheAzack9/FrostedGlass) by theAzack9 and contributors
- Weather: [Open-Meteo](https://open-meteo.com/)
- Icons: Segoe Fluent Icons; brand logos belong to their owners

## License

[MIT](LICENSE)
