# Installs the Pulse helper: copies PulseTemps.exe to Program Files and starts it at every logon
# with admin rights (Lenovo temperatures and Legion mode need them). Run from an admin PowerShell:
#   powershell -ExecutionPolicy Bypass -File install-helper.ps1
#   powershell -ExecutionPolicy Bypass -File install-helper.ps1 -Uninstall
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Run this from an admin PowerShell (right-click PowerShell > Run as administrator).' }

$dir = Join-Path $env:ProgramFiles 'PulseTemps'
Stop-ScheduledTask PulseTemps -ErrorAction SilentlyContinue
Get-Process PulseTemps -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

if ($Uninstall) {
    Unregister-ScheduledTask PulseTemps -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item HKCU:\Software\Pulse -Recurse -ErrorAction SilentlyContinue
    "Helper removed. Screen time history is kept in $env:LOCALAPPDATA\Pulse (delete it if you like)."
    return
}

New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'PulseTemps.exe') $dir -Force

$user = "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute (Join-Path $dir 'PulseTemps.exe')
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask PulseTemps -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
    -Description 'Data helper for the Pulse Rainmeter widgets' -Force | Out-Null
Start-ScheduledTask PulseTemps
"Helper installed and running. It starts automatically at every sign-in."
