-- AI limits card: one row per Claude account (from `cswap list --json`, re-run every minute)
-- plus a Codex row (PulseTemps copies Codex's last logged limits to the registry). Each row has
-- a 5-hour and a weekly ring with time-to-reset under it (hover: the reset clock time); rows spread
-- evenly below the column headers. A window whose reset time has
-- passed counts as 0%.

local ROWS = 4   -- must match AI.ini
-- Non-ASCII text goes out as Rainmeter character references ([\x25CF]); Lua strings must stay ASCII.
local sent, shown, tick, S = {}, {}, 0, nil

function Initialize() S = tonumber(SKIN:GetVariable('S')) end

local function set(name, value)
  if sent[name] ~= value then sent[name] = value; SKIN:Bang('!SetVariable', name, value) end
end

-- blue 122,184,255 -> amber 245,165,36 over 60-85%, amber -> red 240,82,82 over 85-100% (as the stat cards)
local function tone(p)
  local warm = math.min(math.max((p - 60) / 25, 0), 1)
  local hot = math.min(math.max((p - 85) / 15, 0), 1)
  return string.format('%d,%d,%d', 122 + 123 * warm - 5 * hot, 184 - 19 * warm - 83 * hot, 255 - 219 * warm + 46 * hot)
end

local function countdown(secs)
  if secs <= 0 then return 'reset' end
  local d, h, m = math.floor(secs / 86400), math.floor(secs % 86400 / 3600), math.floor(secs % 3600 / 60)
  if d > 0 then return d .. 'd ' .. h .. 'h' end
  if h > 0 then return h .. 'h ' .. m .. 'm' end
  return m .. 'm'
end

-- Clockwise ring arc from 12 o'clock covering pct of the circle, in pixels. Drawn as two halves:
-- a single arc of ~360 degrees starts and ends on the same point and draws nothing.
local function arc(cx, cy, pct)
  local r, a = 19 * S, math.rad(math.min(math.max(pct * 3.6, 0.5), 359.9))
  cx, cy = cx * S, cy * S
  return string.format('%.1f,%.1f | ArcTo %.1f,%.1f,%.1f,%.1f,0,0,0 | ArcTo %.1f,%.1f,%.1f,%.1f,0,0,0',
    cx, cy - r, cx + r * math.sin(a / 2), cy - r * math.cos(a / 2), r, r, cx + r * math.sin(a), cy - r * math.cos(a), r, r)
end

-- Reset time: "03:10" if it's today, otherwise "Mon 05:30".
local function clock(at)
  return os.date(os.date('%Y%j', at) == os.date('%Y%j') and '%H:%M' or '%a %H:%M', at)
end

-- A usage window from its percent and reset time (epoch; nil when no window is running yet).
local function usage(pct, at)
  if not pct then return nil end
  local now = os.time()
  if at and at <= now then return { pct = 0 } end   -- window has rolled over since it was read
  return { pct = pct, left = at and countdown(at - now), clock = at and clock(at) }
end

-- ISO 8601 timestamp with any offset ("...+00:00", "...+05:30", "...Z") to epoch seconds.
local function epoch(s)
  local y, mo, d, h, mi, sec = s:match('^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if not y then return nil end
  local sign, oh, om = s:match('([%+%-])(%d%d):?(%d%d)$')
  local offset = sign and (sign == '-' and -1 or 1) * (oh * 3600 + om * 60) or 0
  local now = os.time()
  local localOffset = os.time(os.date('*t', now)) - os.time(os.date('!*t', now))
  -- os.time reads the fields as local time; shift them to the string's own offset
  return os.time { year = y, month = mo, day = d, hour = h, min = mi, sec = sec } + localOffset - offset
end

local function window(obj)   -- one cswap usage window
  if not obj then return nil end
  local stamp = obj:match('"resetsAt"%s*:%s*"([^"]+)"')
  return usage(tonumber(obj:match('"pct"%s*:%s*([%d%.]+)')), stamp and epoch(stamp))
end

local function claudeRows(rows)
  local out = SKIN:GetMeasure('CSwap'):GetStringValue()
  local starts = {}
  for pos in out:gmatch('()"number"%s*:') do starts[#starts + 1] = pos end
  for n, from in ipairs(starts) do
    local chunk = out:sub(from, (starts[n + 1] or #out + 1) - 1)
    local email = chunk:match('"email"%s*:%s*"([^"]*)"') or 'account'
    local ok = chunk:match('"usageStatus"%s*:%s*"ok"')
    rows[#rows + 1] = {
      name = 'Claude',
      account = (chunk:match('"active"%s*:%s*true') and '[\\x25CF] ' or '') .. (email:match('^[^@]+') or email),
      a = ok and window(chunk:match('"fiveHour"%s*:%s*(%b{})')),
      b = ok and window(chunk:match('"sevenDay"%s*:%s*(%b{})')),
    }
  end
end

local function codexRow(rows)
  local function reg(m) return tonumber(SKIN:GetMeasure(m):GetStringValue()) end
  local five, week = reg('CodexFive'), reg('CodexWeek')
  if not five and not week then return end
  rows[#rows + 1] = { name = 'Codex', account = 'Codex CLI',
    a = usage(five, reg('CodexFiveReset')), b = usage(week, reg('CodexWeekReset')) }
end

function Update()
  if tick % 60 == 0 then SKIN:Bang('!CommandMeasure', 'CSwap', 'Run') end
  tick = tick + 1

  local rows = {}
  claudeRows(rows)
  codexRow(rows)
  local n = math.min(#rows, ROWS)
  local h = 214 / math.max(n, 1)   -- rows fill y 26..240, below the column headers

  for i = 1, ROWS do
    local r, p = rows[i], 'R' .. i
    if i <= n then
      local cy = 26 + (i - 0.5) * h
      set(p .. 'CY', string.format('%.1f', cy))
      set(p .. 'SepA', i > 1 and 16 or 0)
      set(p .. 'Name', r.name)
      set(p .. 'Acct', r.account)
      for side, x in pairs({ A = 160, B = 214 }) do
        local w = side == 'A' and r.a or r.b
        local q = p .. side
        if w and w.pct then
          set(q .. 'Arc', arc(x, cy - 5, w.pct))
          set(q .. 'C', tone(w.pct))
          set(q .. 'AA', 255)
          set(q .. 'Pct', string.format('%d', math.floor(w.pct + 0.5)))
          set(q .. 'Left', w.left or '[\\x2014]')
          set(q .. 'Clock', w.clock or '[\\x2014]')
        else
          set(q .. 'AA', 0)
          set(q .. 'Pct', '[\\x2014]')
          set(q .. 'Left', '[\\x2014]')
          set(q .. 'Clock', '[\\x2014]')
        end
      end
    end
    if shown[i] ~= (i <= n) then   -- only toggle rows when the count changes
      shown[i] = i <= n
      SKIN:Bang(shown[i] and '!ShowMeterGroup' or '!HideMeterGroup', p)
    end
  end
  return n
end
