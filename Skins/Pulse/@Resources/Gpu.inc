; Shared GPU measures. The skin sets #Match# (part of the adapter name) and includes Card.inc first.

[Adapters]
Measure=Plugin
Plugin=RunCommand
Program=reg
Parameter=query HKLM\SOFTWARE\Microsoft\DirectX /s
State=Hide
OutputType=ANSI

; Raw per-process engine counters for every GPU, filtered per adapter by GpuEngine.lua.
[Eng1]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=1
UpdateDivider=#Tick#

[Eng2]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=2
UpdateDivider=#Tick#

[Eng3]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=3
UpdateDivider=#Tick#

[Eng4]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=4
UpdateDivider=#Tick#

[Eng5]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=5
UpdateDivider=#Tick#

[Eng6]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=6
UpdateDivider=#Tick#

[Eng7]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=7
UpdateDivider=#Tick#

[Eng8]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=8
UpdateDivider=#Tick#

[Eng9]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=9
UpdateDivider=#Tick#

[Eng10]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=10
UpdateDivider=#Tick#

[Eng11]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=11
UpdateDivider=#Tick#

[Eng12]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=12
UpdateDivider=#Tick#

[Eng13]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=13
UpdateDivider=#Tick#

[Eng14]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=14
UpdateDivider=#Tick#

[Eng15]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=15
UpdateDivider=#Tick#

[Eng16]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=16
UpdateDivider=#Tick#

[Eng17]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=17
UpdateDivider=#Tick#

[Eng18]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=18
UpdateDivider=#Tick#

[Eng19]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=19
UpdateDivider=#Tick#

[Eng20]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=20
UpdateDivider=#Tick#

[Eng21]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=21
UpdateDivider=#Tick#

[Eng22]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=22
UpdateDivider=#Tick#

[Eng23]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=23
UpdateDivider=#Tick#

[Eng24]
Measure=Plugin
Plugin=UsageMonitor
Category=GPU Engine
Counter=Utilization Percentage
PIDToName=0
Rollup=0
Index=24
UpdateDivider=#Tick#

[Pct]
Measure=Script
ScriptFile=#@#GpuEngine.lua
Match=#Match#
MinValue=0
MaxValue=100
UpdateDivider=#Tick#

[DetailText]
Measure=String
String=#Engine#
UpdateDivider=#Tick#
DynamicVariables=1

[TopText]
Measure=String
String=#Breakdown#
UpdateDivider=#Tick#
DynamicVariables=1
