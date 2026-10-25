; Shared look for every Pulse widget: size, frame rate, colours, fonts and the glass.

[Variables]
; Size knob. 1.25 matches 125% display scaling; change it and refresh to resize.
S=1.25
; Grid: a small card is Unit square; a large one spans 2 units + the gap between them.
Unit=120
Gap=12
; Card corner radius, drawn as Apple-style continuous corners by Squircle.lua.
Radius=17
CardPath=0,0 | LineTo 1,1
; Frames per data sample: 30 x 33 ms = ~1 s.
Tick=30
; Black tint over the glass: lower the last number for clearer glass, raise it for more solid.
Ground=0,0,0,150
; Card border: black, lifting to dark grey on hover.
EdgeIdle=0,0,0,255
EdgeHover=70,72,78,255
Edge=#EdgeIdle#
; Whole-widget opacity, 0-255 (text included).
Opacity=225
Ink=237,238,240
Muted=150,155,164
; SF Pro Display. Name the face, not family + weight: with this install (upright Regular, Medium,
; Bold; italics for the rest) Rainmeter renders FontWeight on the family as italic.
Font=SF Pro Display Regular
FontSemi=SF Pro Display Medium
FontNumber=SF Pro Display Bold

; Real blur behind the card (Acrylic adds a grey layer that reads as flat). Corner=Round is ~8px x scaling, so the shape radius matches it.
[Glass]
Measure=Plugin
Plugin=FrostedGlass
Type=Blur
Border=None
Corner=Round
; No Windows frame line around the blurred window (it showed as a second border).
BorderVisible=0
