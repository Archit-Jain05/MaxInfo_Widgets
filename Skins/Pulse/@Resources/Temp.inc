; Temperature under the ring, published by PulseTemps to HKCU\Software\Pulse.
; The skin sets #TempKey# (CpuTemp or GpuTemp). Shows nothing while the helper isn't running.

[TempValue]
Measure=Registry
RegHKey=HKEY_CURRENT_USER
RegKey=Software\Pulse
RegValue=#TempKey#
UpdateDivider=#Tick#
RegExpSubstitute=1
Substitute="^0$":"","^(\d+)$":"\1°"
IfCondition=TempValue >= 90
IfTrueAction=[!SetOption Temp FontColor "245,165,36"]
IfFalseAction=[!SetOption Temp FontColor "#Muted#"]

[Temp]
Meter=String
MeasureName=TempValue
FontFace=#FontSemi#
FontSize=(10*#S#)
FontColor=#Muted#
StringAlign=Center
X=(93*#S#)
Y=(43*#S#)
AntiAlias=1
