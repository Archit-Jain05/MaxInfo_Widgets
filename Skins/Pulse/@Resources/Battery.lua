-- Battery card: a wide card with rows of 4 cells, filled in order: the laptop first, then devices in the order they
-- connected. When a device leaves, its tile fades out and the later tiles slide left to fill the gap;
-- cells with no tile show just an outline ring. With more than 4 tiles a second row exists below
-- the first; scrolling over the card slides between rows (dots on the right show which).
-- Devices come from PulseTemps (HKCU\Software\Pulse\Devices = "name|level|kind|charging;...").
-- Data is read once a second; every frame eases tiles in/out and between cells, rings and the
-- charging gap. Variables are only re-sent when they change, so a settled card costs ~nothing.

local CELLS, COLS, ROW = 8, 4, 120   -- must match Battery.ini; ROW = card height (logical px)
local page, pos = 0, 0               -- row being shown, and the eased scroll position (in rows)
local ICON = { laptop = 'E7F8', phone = 'E8EA', headphones = 'E7F6', earbuds = 'E7F6', mouse = 'E962',
  keyboard = 'E765', gamepad = 'E7FC', speaker = 'E7F5', other = 'E702' }
local OUTLINE = 26   -- ring outline alpha, same as an empty track
local BUDS_W, BUDS_H = 22, 12.6   -- Icons\buds.png display size (logical px), as in Battery.ini

local slots, sent, cells, cellA, order = {}, {}, {}, {}, {}
local frame, S, R = 0, nil, nil

function Initialize()
  S = tonumber(SKIN:GetVariable('S'))
  R = 20 * S
  for i = 1, CELLS do
    -- same geometry as Battery.ini: padding 12, cells 52.5 wide, gap 6, ring centres on y = 49
    -- (in content coordinates: row 2 sits one card height below row 1)
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    cells[i] = { (38.25 + col * 58.5) * S, (49 + row * ROW) * S }
    cellA[i] = OUTLINE
    slots[i] = {}   -- meter groups S1..S8; a tile keeps its group while it moves between cells
  end
end

local function rows() return math.max(1, math.ceil(#order / COLS)) end

-- Row slide: runs on the Anim ActionTimer rather than the skin's 30 fps update, eased in-out over
-- DURATION seconds of wall time. The timer waits 10 ms, which Windows rounds to one 15.6 ms tick
-- (~64 fps; asking for 16 ms rounds up to two ticks, ~32 fps). It only runs during a slide.
local DURATION = 0.32
local from, start, sliding = 0, 0, false

local function easeInOut(x) return x < 0.5 and 4 * x ^ 3 or 1 - (-2 * x + 2) ^ 3 / 2 end

local function slideTo(p)
  if p == page then return end
  from, page, start, sliding = pos, p, os.clock(), true
  SKIN:Bang('!CommandMeasure', 'Anim', 'Stop 1')
  SKIN:Bang('!CommandMeasure', 'Anim', 'Execute 1')
end

-- Mouse wheel: one row per scroll, ignored while a slide is running so a touchpad's burst of
-- scroll events doesn't stutter.
function Scroll(n)
  if sliding then return end
  slideTo(math.max(0, math.min(rows() - 1, page + n)))
end

local function ease(v, target) return v + (target - v) * 0.2 end

local function set(name, value)
  if sent[name] ~= value then
    sent[name] = value
    SKIN:Bang('!SetVariable', name, value)
  end
end

local function px(v) return string.format('%.1f', v) end

-- Clockwise arc on a ring centred at (cx, cy), angles in degrees from 12 o'clock. Drawn as two
-- halves: a single arc of ~360 degrees starts and ends on the same point and draws nothing.
local function arc(cx, cy, a0, a1)
  local function pt(a) local t = math.rad(a) return cx + R * math.sin(t), cy - R * math.cos(t) end
  local x0, y0 = pt(a0)
  local xm, ym = pt((a0 + a1) / 2)
  local x1, y1 = pt(a1)
  return string.format('%.1f,%.1f | ArcTo %.1f,%.1f,%.1f,%.1f,0,0,0 | ArcTo %.1f,%.1f,%.1f,%.1f,0,0,0', x0, y0, xm, ym, R, R, x1, y1, R, R)
end

-- Tiles wanted right now: the laptop, then devices.
local function wanted()
  local list = { { key = 'laptop', name = 'This laptop', kind = 'laptop',
    level = SKIN:GetMeasure('LaptopPct'):GetValue(), charging = SKIN:GetMeasure('LaptopAC'):GetValue() == 1 } }
  for entry in SKIN:GetMeasure('Devices'):GetStringValue():gmatch('[^;]+') do
    local name, level, kind, chg = entry:match('^(.-)|(%d+)|(%a+)|(%d)$')
    if name then
      list[#list + 1] = { key = name, name = name, kind = kind, level = tonumber(level), charging = chg == '1' }
    end
  end
  return list
end

local function refresh()
  local byKey = {}
  local want = wanted()
  for _, w in ipairs(want) do byKey[w.key] = w end

  -- departed devices leave the order (their tiles fade out); newcomers join at the end
  for n = #order, 1, -1 do
    if not byKey[order[n]] then table.remove(order, n) end
  end
  local known = {}
  for _, k in ipairs(order) do known[k] = true end
  for _, w in ipairs(want) do
    if not known[w.key] and #order < CELLS then order[#order + 1] = w.key end
  end

  local cellOf = {}
  for n, k in ipairs(order) do cellOf[k] = n end
  for _, s in ipairs(slots) do
    if s.key then
      s.cell = cellOf[s.key]
      s.leaving = s.cell == nil
      if not s.leaving then s.data = byKey[s.key]; cellOf[s.key] = nil end
    end
  end
  -- what's left in cellOf is new: give it a free meter group, appearing in its cell
  for k, n in pairs(cellOf) do
    for i, s in ipairs(slots) do
      if not s.key then
        slots[i] = { key = k, data = byKey[k], cell = n, a = 0, lvl = 0, gap = 0, x = cells[n][1], y = cells[n][2] }
        SKIN:Bang('!ShowMeterGroup', 'S' .. i)
        break
      end
    end
  end
end

-- Sends the current state of every tile, outline and the scroll offset to the meters.
local function render()
  local n, off = rows(), pos * ROW * S
  set('OY1', px(49 * S - off))
  set('OY2', px((49 + ROW) * S - off))
  set('D1A', n > 1 and (page == 0 and 200 or 60) or 0)
  set('D2A', n > 1 and (page == 1 and 200 or 60) or 0)

  for i, s in ipairs(slots) do
    local p = 'S' .. i
    if s.key then
      local d = s.data
      local g = math.max(s.gap, 0.1)
      local span = math.max((360 - 2 * g) * s.lvl / 100, 0.5)
      local a = math.floor(s.a + 0.5)
      local y = s.y - off
      -- earbuds are drawn with an image instead of a glyph: CMF's stem buds, else Galaxy Buds
      local buds = d.kind == 'earbuds'
      if buds then
        set(p .. 'Img', SKIN:GetVariable('@') .. 'Icons\\' .. (d.name:lower():find('cmf') and 'buds-cmf.png' or 'buds.png'))
      end
      set(p .. 'CX', px(s.x))
      set(p .. 'CY', px(y))
      set(p .. 'BY', px(y - R))
      set(p .. 'PY', px(y + 28 * S))
      set(p .. 'IX', px(s.x - BUDS_W / 2 * S))
      set(p .. 'IY', px(y - BUDS_H / 2 * S))
      set(p .. 'A', a)
      set(p .. 'IA', buds and a or 0)
      set(p .. 'TA', math.floor(a * OUTLINE / 255))
      set(p .. 'Track', arc(s.x, y, g, 360 - g))
      set(p .. 'Arc', arc(s.x, y, g, g + span))
      set(p .. 'C', (d.charging or d.level > 20) and '52,199,89' or (d.level > 10 and '255,204,0' or '255,69,58'))
      set(p .. 'BoltA', math.floor(a * math.min(s.gap / 20, 1)))
      set(p .. 'Pct', string.format('%d%%', math.floor(s.lvl + 0.5)))
      set(p .. 'Icon', buds and '' or '[\\x' .. (ICON[d.kind] or ICON.other) .. ']')
      set(p .. 'Name', d.name)
    end
  end

  for j = 1, CELLS do set('C' .. j .. 'PA', math.floor(cellA[j] + 0.5)) end
end

function Frame()
  if not sliding then return end
  local t = math.min(1, (os.clock() - start) / DURATION)
  pos = from + (page - from) * easeInOut(t)
  if t == 1 then
    sliding = false
    SKIN:Bang('!CommandMeasure', 'Anim', 'Stop 1')
  end
  render()
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Update()
  if frame % 30 == 0 then refresh() end
  frame = frame + 1

  -- a row that emptied out sends the view back up
  if page > rows() - 1 then slideTo(rows() - 1) end

  local occupied = {}
  for i, s in ipairs(slots) do
    if s.key then
      local d = s.data
      s.a = s.leaving and s.a * 0.65 or ease(s.a, 255)   -- leave fast so the slide-up isn't crowded
      if s.leaving and s.a < 4 then
        slots[i] = {}
        SKIN:Bang('!HideMeterGroup', 'S' .. i)
      else
        if not s.leaving then
          occupied[s.cell] = true
          s.x, s.y = ease(s.x, cells[s.cell][1]), ease(s.y, cells[s.cell][2])
        end
        s.lvl = ease(s.lvl, d.level)
        s.gap = ease(s.gap, d.charging and 20 or 0)
      end
    end
  end

  -- outline rings fade out under occupied cells and back in when a cell empties
  for j = 1, CELLS do cellA[j] = ease(cellA[j], occupied[j] and 0 or OUTLINE) end

  render()
  return 0
end
