; Shared square card for every Pulse widget.
; Each skin defines #Label# and three measures: [Pct] (0-100), [DetailText] and [TopText] (strings).
; Data measures run every #Tick# frames (once a second); ring and number ease toward them every frame.

[Rainmeter]
; 33 ms = 30 fps
Update=33
AccurateText=1
MouseOverAction=[!SetVariable Edge "#EdgeHover#"][!HideMeter Detail][!ShowMeter Top][!UpdateMeter *][!Redraw]
MouseLeaveAction=[!SetVariable Edge "#EdgeIdle#"][!ShowMeter Detail][!HideMeter Top][!UpdateMeter *][!Redraw]
LeftMouseDoubleClickAction=["taskmgr.exe"]
ContextTitle=Open Task Manager
ContextAction=["taskmgr.exe"]
OnRefreshAction=[!SetTransparency #Opacity#]

[Variables]
@Include=#@#Theme.inc

; Eased value: closes 18% of the gap each frame, settles in ~0.2 s at 30 fps.
[Shown]
Measure=Calc
Formula=Shown + (Pct - Shown) * 0.18
MinValue=0
MaxValue=100

; Ring sweep in radians, kept off 0/100 so the arc never collapses to a point.
[Sweep]
Measure=Calc
Formula=Clamp(Shown, 0.5, 99.9) * PI / 50

; Usage colour: blue 10,132,255 below 60%, yellow 255,204,0 from 60%, yellow -> red 255,69,58 over 85-100%.
; (A blue -> yellow blend passes through a washed-out beige, so that step is a hard switch.)
[Warm]
Measure=Calc
Formula=(Shown >= 60) ? 1 : 0

[Hot]
Measure=Calc
Formula=Clamp((Shown - 85) / 15, 0, 1)

[ToneR]
Measure=Calc
Formula=Round(10 + 245 * Warm)

[ToneG]
Measure=Calc
Formula=Round(132 + 72 * Warm - 135 * Hot)

[ToneB]
Measure=Calc
Formula=Round(255 - 255 * Warm + 58 * Hot)

; Apple-style corner outline for the card background (sets #CardPath# once).
[Squircle]
Measure=Script
ScriptFile=#@#Squircle.lua
Width=(#Unit#*#S#)
Radius=(#Radius#*#S#)
UpdateDivider=-1

[Bg]
Meter=Shape
Shape=Path CardShape | Fill Color #Ground# | StrokeWidth 1 | Stroke Color #Edge#
CardShape=#CardPath#
DynamicVariables=1

[Label]
Meter=String
Text=#Label#
FontFace=#FontSemi#
FontSize=(8*#S#)
FontColor=#Muted#
X=(14*#S#)
Y=(12*#S#)
AntiAlias=1
DynamicVariables=1

[Ring]
Meter=Shape
Shape=Ellipse (93*#S#),(27*#S#),(12*#S#) | Fill Color 0,0,0,0 | StrokeWidth (3.5*#S#) | Stroke Color 255,255,255,26
Shape2=Path RingPath | Fill Color 0,0,0,0 | StrokeWidth (3.5*#S#) | Stroke Color [ToneR],[ToneG],[ToneB] | StrokeStartCap Round | StrokeEndCap Round
; Clockwise from 12 o'clock, as two halves (a single ~360 degree arc draws nothing).
RingPath=(93*#S#),(15*#S#) | ArcTo ((93+12*Sin([Sweep]/2))*#S#),((27-12*Cos([Sweep]/2))*#S#),(12*#S#),(12*#S#),0,0,0 | ArcTo ((93+12*Sin([Sweep]))*#S#),((27-12*Cos([Sweep]))*#S#),(12*#S#),(12*#S#),0,0,0
DynamicVariables=1

[Num]
Meter=String
MeasureName=Shown
NumOfDecimals=0
Text=%1%
FontFace=#FontNumber#
FontSize=(22*#S#)
FontColor=#Ink#
X=(11*#S#)
Y=(24*#S#)
InlineSetting=CharacterSpacing | 0 | -2
InlineSetting2=Size | 14
InlinePattern2=%
InlineSetting3=Color | #Muted#
InlinePattern3=%
AntiAlias=1

[Detail]
Meter=String
MeasureName=DetailText
FontFace=#Font#
FontSize=(7.5*#S#)
FontColor=#Muted#
X=(14*#S#)
Y=(66*#S#)
W=(92*#S#)
ClipString=1
AntiAlias=1

[Top]
Meter=String
MeasureName=TopText
FontFace=#Font#
FontSize=(7.5*#S#)
FontColor=#Ink#
X=(14*#S#)
Y=(66*#S#)
W=(92*#S#)
ClipString=1
AntiAlias=1
Hidden=1

; History graphs sample once a second, not every frame.
[Fill]
Meter=Histogram
MeasureName=Pct
X=(14*#S#)
Y=(88*#S#)
W=(92*#S#)
H=(18*#S#)
PrimaryColor=[ToneR],[ToneG],[ToneB],34
SolidColor=0,0,0,0
AntiAlias=1
UpdateDivider=#Tick#
DynamicVariables=1

[Line]
Meter=Line
MeasureName=Pct
X=(14*#S#)
Y=(88*#S#)
W=(92*#S#)
H=(18*#S#)
LineCount=1
LineColor=[ToneR],[ToneG],[ToneB]
LineWidth=(1.5*#S#)
AntiAlias=1
UpdateDivider=#Tick#
DynamicVariables=1

[Head]
Meter=Shape
Shape=Ellipse (106*#S#-1),((106-18*[Shown]/100)*#S#),(4.5*#S#) | Fill Color [ToneR],[ToneG],[ToneB],40 | StrokeWidth 0
Shape2=Ellipse (106*#S#-1),((106-18*[Shown]/100)*#S#),(2.5*#S#) | Fill Color [ToneR],[ToneG],[ToneB] | StrokeWidth 0
DynamicVariables=1
