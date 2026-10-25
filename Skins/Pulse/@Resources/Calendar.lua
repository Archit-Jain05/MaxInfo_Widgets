-- Calendar card: today on the left; on the right a month grid (week start from Windows regional
-- settings) with today circled and weekends grey. Scrolling over the card moves between months
-- with a short fade/slide; clicking the left side, or 30 s without scrolling, returns to today.

local INK, MUTED, ON_ACCENT = '237,238,240', '150,155,164', '10,12,16'
local LETTERS = { 'S', 'M', 'T', 'W', 'T', 'F', 'S' }   -- Sunday first, as os.date('%w')
local FRAMES, HALF, IDLE = 12, 5, 30   -- animation frames (ActionTimer, 16 ms each), fade-out part, idle seconds

local view, pending = 0, nil   -- months away from the current one; month to show after the fade-out
local shown, idle, frame, dir = nil, 0, FRAMES, 1

local function render()
  local now = os.date('*t')
  local first = os.time { year = now.year, month = now.month + view, day = 1, hour = 12 }
  local m = os.date('*t', first)
  -- iFirstDayOfWeek: 0 = Monday ... 6 = Sunday; convert to os.date('%w') numbering (0 = Sunday)
  local firstDow = (SKIN:GetMeasure('FirstDay'):GetValue() + 1) % 7
  local offset = (tonumber(os.date('%w', first)) - firstDow) % 7
  local days = os.date('*t', os.time { year = m.year, month = m.month + 1, day = 0, hour = 12 }).day

  for c = 1, 7 do
    SKIN:Bang('!SetVariable', 'H' .. c, LETTERS[(firstDow + c - 1) % 7 + 1])
  end
  for i = 1, 42 do
    local d, dow = i - offset, (firstDow + (i - 1) % 7) % 7
    local text = (d >= 1 and d <= days) and tostring(d) or ''
    local color = (view == 0 and d == now.day) and ON_ACCENT or ((dow == 0 or dow == 6) and MUTED or INK)
    SKIN:Bang('!SetVariable', 'D' .. i, text)
    SKIN:Bang('!SetVariable', 'C' .. i, color)
  end
  SKIN:Bang('!SetVariable', 'ViewMonth', os.date('%B %Y', first))
  SKIN:Bang('!SetVariable', 'TodayA', view == 0 and 255 or 0)
  if view == 0 then
    local t = now.day + offset - 1
    SKIN:Bang('!SetVariable', 'TodayCol', t % 7)
    SKIN:Bang('!SetVariable', 'TodayRow', math.floor(t / 7))
  end
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

-- n = +1 next month, -1 previous, 0 back to today. One month per scroll: while a change is
-- animating (plus a short pause, see Anim in Calendar.ini) further wheel events are ignored,
-- so fast wheels and touchpads step through months instead of stuttering.
local busy = false

function Shift(n)
  idle = 0
  if busy then return end
  local target = n == 0 and 0 or view + n
  if target == view then return end
  dir = target > view and 1 or -1
  pending, busy, frame = target, true, 0
  SKIN:Bang('!CommandMeasure', 'Anim', 'Execute 1')
end

function Unlock() busy = false end

-- Frames 1-HALF fade the grid out moving away, then the month swaps and it fades in from the other side.
function Frame()
  if frame >= FRAMES then return end
  frame = frame + 1
  local a, dy
  if frame <= HALF then
    local t = frame / HALF
    a, dy = 1 - t, -6 * dir * t
  else
    if pending then view, pending = pending, nil; render() end
    local t = (frame - HALF) / (FRAMES - HALF)
    a, dy = t, 6 * dir * (1 - t)
  end
  SKIN:Bang('!SetVariable', 'GridA', math.floor(255 * a + 0.5))
  SKIN:Bang('!SetVariable', 'GridDY', string.format('%.1f', dy))
  SKIN:Bang('!UpdateMeter', 'GridBox')
  SKIN:Bang('!Redraw')
end

function Update()
  if view ~= 0 then
    idle = idle + 1
    if idle >= IDLE then Shift(0) end
  end
  local now = os.date('*t')
  local stamp = string.format('%d-%d-%d', now.year, now.month, now.day)
  if stamp ~= shown and frame >= FRAMES then   -- first run, or the date changed
    shown = stamp
    render()
  end
  return now.day
end
