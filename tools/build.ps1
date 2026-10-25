# Builds dist\Pulse_<version>.rmskin: compiles the helpers (PulseTemps.exe, PulseAct.exe) with the
# C# compiler that ships with Windows (.NET Framework 4.x), then packs RMSKIN.ini, Skins and
# Layouts into a zip with Rainmeter's 16-byte .rmskin footer.
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = ([regex]::Match((Get-Content "$root\RMSKIN.ini" -Raw), '(?m)^Version=(.+)$').Groups[1].Value).Trim()
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item "$root\RMSKIN.ini" $stage
Copy-Item "$root\Skins" $stage -Recurse
Copy-Item "$root\Layouts" $stage -Recurse

# helpers
$fw = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319"
$wpf = "$fw\WPF"
$out = "$stage\Skins\Pulse\@Resources\PulseTemps"
& "$fw\csc.exe" /nologo /optimize /target:winexe "/out:$out\PulseTemps.exe" /r:System.Management.dll /r:System.Device.dll `
    "/r:$wpf\UIAutomationClient.dll" "/r:$wpf\UIAutomationTypes.dll" "/r:$wpf\WindowsBase.dll" "$out\PulseTemps.cs"
if ($LASTEXITCODE) { throw 'PulseTemps.exe failed to compile' }
& "$fw\csc.exe" /nologo /optimize /target:winexe "/out:$out\PulseAct.exe" "$out\PulseAct.cs"
if ($LASTEXITCODE) { throw 'PulseAct.exe failed to compile' }

# zip with forward-slash entry names, then the footer: zip size (int64), flags (0), "RMSKIN\0"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$file = Join-Path $dist "Pulse_$version.rmskin"
Remove-Item $file -ErrorAction SilentlyContinue
$zip = [IO.Compression.ZipFile]::Open($file, 'Create')
try {
    Get-ChildItem $stage -Recurse -File | ForEach-Object {
        $name = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $name, 'Optimal')
    }
} finally { $zip.Dispose() }

$size = (Get-Item $file).Length
$footer = [BitConverter]::GetBytes([int64]$size) + [byte[]](0) + [Text.Encoding]::ASCII.GetBytes("RMSKIN") + [byte[]](0)
$fs = [IO.File]::Open($file, 'Append')
try { $fs.Write($footer, 0, $footer.Length) } finally { $fs.Dispose() }

Remove-Item $stage -Recurse -Force
"Built $file ({0:N0} KB)" -f ((Get-Item $file).Length / 1KB)
