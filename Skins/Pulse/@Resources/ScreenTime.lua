-- Screen time card (wide): today's total, a 24-hour bar chart, and one stacked bar split by the
-- top 3 apps plus everything else, with those apps listed underneath.
-- Data comes from PulseTemps (HKCU\Software\Pulse ScreenTotal / ScreenHours / ScreenApps).

local TOP = 3                                               -- legend entries in ScreenTime.ini
local CHART_X, CHART_W, BASE, CHART_H = 120, 118, 58, 30    -- logical px, as in ScreenTime.ini
local STACK_X, STACK_W = 14, 224
local SHADES = { '122,184,255,255', '122,184,255,150', '122,184,255,85' }   -- top apps; rest is the track

local sent = {}
local function set(name, value)
  if sent[name] ~= value then sent[name] = value; SKIN:Bang('!SetVariable', name, value) end
end

local function str(m) return SKIN:GetMeasure(m):GetStringValue() end

local function duration(s)
  if s > 0 and s < 60 then return '<1m' end
  s = math.floor(s / 60)
  local h, m = math.floor(s / 60), s % 60
  if h == 0 then return m .. 'm' end
  return h .. 'h ' .. m .. 'm'
end

local function shapes(meter, list)
  local sig = table.concat(list, ';')
  if sent[meter] == sig then return end
  sent[meter] = sig
  for i, s in ipairs(list) do SKIN:Bang('!SetOption', meter, i == 1 and 'Shape' or ('Shape' .. i), s) end
  SKIN:Bang('!UpdateMeter', meter)
end

function Update()
  local S = tonumber(SKIN:GetVariable('S'))
  local total = tonumber(str('Total')) or 0
  set('TotalText', duration(total))

  -- hourly bars, scaled to the busiest hour (at least 15 minutes so a quiet day stays low)
  local hours, peak = {}, 900
  for v in str('Hours'):gmatch('[^,]+') do hours[#hours + 1] = tonumber(v) or 0 end
  for _, v in ipairs(hours) do peak = math.max(peak, v) end
  local pitch, bars = CHART_W / 24, {}
  for h = 1, 24 do
    local v = hours[h] or 0
    local hgt = math.max(v / peak * CHART_H, 1.5)
    bars[h] = string.format('Rectangle %.1f,%.1f,%.1f,%.1f,%.1f | Fill Color %s | StrokeWidth 0',
      (CHART_X + (h - 1) * pitch) * S, (BASE - hgt) * S, (pitch - 1.5) * S, hgt * S, 1 * S,
      v > 0 and '122,184,255' or '255,255,255,18')
  end
  shapes('Bars', bars)

  -- stacked share bar for the top apps, then their names and times
  local stack = { string.format('Rectangle %.1f,%.1f,%.1f,%.1f,%.1f | Fill Color 255,255,255,18 | StrokeWidth 0',
    STACK_X * S, 68 * S, STACK_W * S, 6 * S, 3 * S) }
  local x, i = STACK_X, 0
  for name, secs in str('Apps'):gmatch('([^;|]+)|(%d+)') do
    i = i + 1
    if i > TOP then break end
    secs = tonumber(secs)
    local w = total > 0 and STACK_W * secs / total or 0
    if w > 0.5 then
      stack[#stack + 1] = string.format('Rectangle %.1f,%.1f,%.1f,%.1f,%.1f | Fill Color %s | StrokeWidth 0',
        x * S, 68 * S, w * S, 6 * S, 3 * S, SHADES[i])
    end
    x = x + w
    set('App' .. i, name)
    set('Time' .. i, duration(secs))
    set('Dot' .. i, SHADES[i])
  end
  for j = i + 1, TOP do set('App' .. j, ''); set('Time' .. j, ''); set('Dot' .. j, '0,0,0,0') end
  shapes('Stack', stack)
  SKIN:Bang('!Redraw')
  return total
end
