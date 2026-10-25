-- GitHub card: draws the last WEEKS weeks of the public contribution calendar
-- (github.com/users/<user>/contributions, no token) as a grid of green squares, one column per
-- week, Sunday at the top, like GitHub, plus totals for that span: contributions and best day. Built after each hourly fetch.

local WEEKS = 13   -- about 3 months
local X0, Y0, CELL, PITCH = 18.05, 44, 14, 16.9   -- logical px; 13 columns across the 2x2 card in GitHub.ini
-- GitHub's dark-theme greens; empty days are a faint white square
local LEVELS = { [0] = '255,255,255,18', '14,68,41', '0,109,50', '38,166,65', '57,211,83' }
local DAY = 86400

local function noon(y, m, d) return os.time { year = y, month = m, day = d, hour = 12 } end

-- Each day is a <td> with data-date, data-level and an id; its count is in the <tool-tip> for that id.
local function readDays(page)
  local counts = {}
  for id, text in page:gmatch('<tool%-tip[^>]-for="([^"]+)"[^>]*>([^<]*)</tool%-tip>') do
    counts[id] = tonumber(text:match('^(%d+) contribution')) or 0
  end
  local days = {}
  for tag in page:gmatch('<td[^>]-data%-date="[^>]*>') do
    local y, m, d = tag:match('data%-date="(%d+)%-(%d+)%-(%d+)"')
    local level, id = tag:match('data%-level="(%d)"'), tag:match('id="([^"]+)"')
    if y and level then
      days[#days + 1] = { t = noon(tonumber(y), tonumber(m), tonumber(d)), level = tonumber(level), count = counts[id] or 0 }
    end
  end
  table.sort(days, function(a, b) return a.t < b.t end)
  return days
end

function Build()
  local page = SKIN:GetMeasure('Page'):GetStringValue()
  local days = readDays(page)
  if #days == 0 then
    SKIN:Bang('!SetVariable', 'Total', 'Not available')
    return
  end
  local total = page:match('([%d,]+)%s+contributions?%s+in the last year')
  SKIN:Bang('!SetVariable', 'Total', total and (total .. ' in the last year') or '')

  local S = tonumber(SKIN:GetVariable('S'))
  local latest = days[#days].t
  local endSunday = latest - (os.date('*t', latest).wday - 1) * DAY
  local k, sum, best = 0, 0, 0
  for _, day in ipairs(days) do
    local wday = os.date('*t', day.t).wday   -- 1 = Sunday
    local col = WEEKS - 1 - math.floor((endSunday - (day.t - (wday - 1) * DAY)) / (7 * DAY) + 0.5)
    if col >= 0 then
      k = k + 1
      sum, best = sum + day.count, math.max(best, day.count)
      SKIN:Bang('!SetOption', 'Cells', k == 1 and 'Shape' or ('Shape' .. k),
        string.format('Rectangle %.1f,%.1f,%.1f,%.1f,%.1f | Fill Color %s | StrokeWidth 0',
          (X0 + col * PITCH) * S, (Y0 + (wday - 1) * PITCH) * S, CELL * S, CELL * S, 3 * S, LEVELS[day.level] or LEVELS[0]))
    end
  end

  SKIN:Bang('!SetVariable', 'SpanTotal', sum)
  SKIN:Bang('!SetVariable', 'Best', best)
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Update() return 0 end
