-- Screen time detail card (opened by clicking the screen time card): today's total and how it
-- compares, usage by hour, the last 7 days, and the most used apps with their share.
-- Data comes from PulseTemps (HKCU\Software\Pulse ScreenTotal / ScreenHours / ScreenApps / ScreenWeek).

local ROWS = 8                                         -- app rows in ScreenTimeDetail.ini
local HOUR_X, HOUR_W, HOUR_BASE, HOUR_H = 20, 164, 178, 56   -- logical px, as in the .ini
local WEEK_X, WEEK_W, WEEK_BASE, WEEK_H = 20, 164, 300, 66
local SHARE_W = 160
local ACCENT, FAINT = '122,184,255', '255,255,255,18'

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

local function bar(x, base, w, h, color, S)
  h = math.max(h, 1.5)
  return string.format('Rectangle %.1f,%.1f,%.1f,%.1f,%.1f | Fill Color %s | StrokeWidth 0',
    x * S, (base - h) * S, w * S, h * S, 1.5 * S, color)
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
  set('DateText', (os.date('%A, %d %B'):gsub(' 0', ' ')))

  -- last 7 days, oldest first; today is the last
  local week = {}
  for day, secs in str('Week'):gmatch('([%d%-]+)|(%d+)') do week[#week + 1] = { day = day, secs = tonumber(secs) } end
  local yesterday = week[6] and week[6].secs or 0
  local sum, n = 0, 0
  for i = 1, #week - 1 do if week[i].secs > 0 then sum, n = sum + week[i].secs, n + 1 end end
  if yesterday > 0 then
    local pct = math.floor(math.abs(total - yesterday) / yesterday * 100 + 0.5)
    set('CompareText', total >= yesterday and ('[\\x25B2] ' .. pct .. '% more than yesterday')
                                           or ('[\\x25BC] ' .. pct .. '% less than yesterday'))
  elseif n > 0 then
    set('CompareText', 'Daily average ' .. duration(sum / n))
  else
    set('CompareText', 'Tracking started today')
  end

  -- today by hour, scaled to the busiest hour (at least 15 minutes)
  local hours, peak = {}, 900
  for v in str('Hours'):gmatch('[^,]+') do hours[#hours + 1] = tonumber(v) or 0 end
  for _, v in ipairs(hours) do peak = math.max(peak, v) end
  local pitch, list = HOUR_W / 24, {}
  for h = 1, 24 do
    local v = hours[h] or 0
    list[h] = bar(HOUR_X + (h - 1) * pitch, HOUR_BASE, pitch - 2, v / peak * HOUR_H, v > 0 and ACCENT or FAINT, S)
  end
  shapes('HourBars', list)

  -- last 7 days, scaled to the busiest day (at least an hour); today in full accent
  local wpeak = 3600
  for _, d in ipairs(week) do wpeak = math.max(wpeak, d.secs) end
  local wpitch, wlist = WEEK_W / 7, {}
  for i = 1, 7 do
    local d = week[i] or { day = '', secs = 0 }
    local color = d.secs == 0 and FAINT or (i == 7 and ACCENT or (ACCENT .. ',120'))
    wlist[i] = bar(WEEK_X + (i - 1) * wpitch + 3, WEEK_BASE, wpitch - 6, d.secs / wpeak * WEEK_H, color, S)
    local y, m, dd = d.day:match('(%d+)%-(%d+)%-(%d+)')
    set('Day' .. i, y and os.date('%a', os.time { year = y, month = m, day = dd, hour = 12 }):sub(1, 1) or '')
  end
  shapes('WeekBars', wlist)

  -- most used apps, with their share of today's total
  local i = 0
  for name, secs in str('Apps'):gmatch('([^;|]+)|(%d+)') do
    i = i + 1
    if i > ROWS then break end
    secs = tonumber(secs)
    set('App' .. i, name)
    set('Time' .. i, duration(secs))
    set('Share' .. i, string.format('%.1f', total > 0 and SHARE_W * secs / total or 0))
    set('Track' .. i, 14)
  end
  for j = i + 1, ROWS do set('App' .. j, ''); set('Time' .. j, ''); set('Share' .. j, '0'); set('Track' .. j, 0) end
  SKIN:Bang('!Redraw')
  return total
end
