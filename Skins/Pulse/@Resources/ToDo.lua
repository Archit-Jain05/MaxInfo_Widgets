-- To Do card (wide), laid out like the calendar: on the left the list name (accent), the number of
-- open tasks in big type and a muted line under it; on the right that list's tasks as a continuous
-- list (4 visible), each with a check circle, its title and its due date (blue today, red overdue;
-- a yellow star when important), with hairlines between rows and a thin scrollbar.
-- Each wheel notch glides the list one row (quick notches add up). The rows are recycled: 6 row
-- meters in ToDo.ini are refilled from the list as it scrolls, so a list can be any length.
-- Clicking the left side swaps the list for the lists (the shown one filled blue); clicking one
-- shows it (remembered in ToDo.ini); clicking anywhere else closes the picker.
-- Data comes from PulseTemps (HKCU\Software\Pulse ToDo / ToDoLists / ToDoSynced), read from the
-- To Do app's own database, so it's as fresh as the app's last sync.
-- This file is saved as UTF-16 so Rainmeter hands Lua UTF-8: titles keep emoji and any script.

local SLOTS, VISIBLE = 6, 4                -- row meters in ToDo.ini, rows that fit
local TOP, PITCH = 19, 24                  -- first row's text top, row pitch
local TITLE_W = 120                        -- title width with nothing on the right
local BAR_TOP, BAR_H = 14, 92              -- scrollbar track
local BLUE, RED, MUTED = '10,132,255', '255,69,58', '150,155,164'
local DURATION = 0.2                       -- glide per notch, seconds (on the Anim ActionTimer)

local sent, S = {}, nil
local items = {}                           -- rows to show: { title, right, rightColor, fill }
local pos, target = 0, 0                   -- scroll offset in rows (pos animates toward target)
local from, start, sliding = 0, 0, false
local picking = false                      -- showing the list picker instead of tasks
local loaded = 0                           -- os.clock() at load
local lists = {}                           -- { id, name, open, default } in the app's order

local function set(name, value)
  if sent[name] ~= value then sent[name] = value; SKIN:Bang('!SetVariable', name, value) end
end

local function str(m) return SKIN:GetMeasure(m):GetStringValue() end

local function records(s, fields)
  local out = {}
  for rec in (s .. '\30'):gmatch('([^\30]*)\30') do
    local f = {}
    for v in (rec .. '\31'):gmatch('([^\31]*)\31') do f[#f + 1] = v end
    if #f == fields then out[#out + 1] = f end
  end
  return out
end

local function maxPos() return math.max(0, #items - VISIBLE) end

-- "Today", "Tomorrow", a weekday within the week, else "12 Nov"; and its colour.
local function due(d)
  local y, m, dd = d:match('^(%d+)-(%d+)-(%d+)$')
  if not y then return nil end
  local t = os.time { year = y, month = m, day = dd, hour = 12 }
  local now = os.date('*t')
  local days = math.floor((t - os.time { year = now.year, month = now.month, day = now.day, hour = 12 }) / 86400 + 0.5)
  local text = days == 0 and 'Today' or days == 1 and 'Tomorrow' or (days > 1 and days < 7) and os.date('%a', t)
    or (tonumber(os.date('%d', t)) .. os.date(' %b', t))
  return text, days < 0 and RED or days == 0 and BLUE or MUTED
end

local function ago(secs)
  if secs < 3600 then return math.floor(secs / 60) .. 'm' end
  if secs < 86400 then return math.floor(secs / 3600) .. 'h' end
  return math.floor(secs / 86400) .. 'd'
end

-- The list being shown: the remembered one if it still exists, else the default list.
local function current()
  local id = SKIN:GetVariable('ListId')
  for _, l in ipairs(lists) do if l[1] == id then return l end end
  for _, l in ipairs(lists) do if l[4] == '1' then return l end end
  return lists[1]
end

-- Fills the row slots from the items for the current scroll offset, positions them, and sets the
-- scrollbar. Slot k shows item floor(pos) + k; the fraction of pos shifts them all up.
local function render()
  local base = math.floor(pos)
  local frac = pos - base
  for k = 1, SLOTS do
    local idx, it = base + k, items[base + k]
    set('Y' .. k, string.format('%.1f', (TOP + (k - 1 - frac) * PITCH) * S))
    if it then
      local changed = sent['R' .. k] ~= it[2]
      set('R' .. k, it[2])
      if changed then SKIN:Bang('!UpdateMeter', 'R' .. k) end
      local rw = it[2] == '' and 0 or SKIN:GetMeter('R' .. k):GetW()
      set('T' .. k, it[1])
      set('TW' .. k, string.format('%.1f', TITLE_W * S - (rw > 0 and rw + 6 * S or 0)))
      set('RC' .. k, it[3])
      set('CF' .. k, it[4])
      set('A' .. k, 255)
      set('LA' .. k, idx > 1 and 18 or 0)   -- hairline above every row but the first
    else
      set('T' .. k, ''); set('R' .. k, ''); set('A' .. k, 0); set('LA' .. k, 0)
    end
  end
  local n = #items
  if n > VISIBLE then
    local h = math.max(BAR_H * VISIBLE / n, 12)
    set('BarA', 90)
    set('BarH', string.format('%.1f', h * S))
    set('BarY', string.format('%.1f', (BAR_TOP + (BAR_H - h) * pos / maxPos()) * S))
  else
    set('BarA', 0)
  end
end

-- Builds the items (the current list's tasks, or the lists while picking) and the left side.
local function fill()
  local list = current()
  items = {}
  if picking then
    for _, l in ipairs(lists) do
      items[#items + 1] = { l[2], l[3], MUTED, (list and l[1] == list[1]) and BLUE or '0,0,0,0' }
    end
  elseif list then
    for _, t in ipairs(records(str('Tasks'), 4)) do
      if t[2] == list[1] then
        local text, color = due(t[3])
        items[#items + 1] = { t[1], (t[4] == '1' and '[\\x2605] ' or '') .. (text or ''), color or MUTED, '0,0,0,0' }
      end
    end
  end

  local synced = tonumber(str('Synced')) or 0
  local age = synced > 0 and os.time() - synced or 0
  if picking then
    set('Title', 'Lists  [\\x25B4]')
    set('Big', tostring(#lists))
    set('Sub', 'pick one')
  else
    local open = list and tonumber(list[3]) or 0
    set('Title', (list and list[2] or 'To Do') .. '  [\\x25BE]')
    set('Big', tostring(open))
    set('Sub', (open == 0 and 'all done' or 'open') .. (age > 86400 and ('  [\\x00B7]  ' .. ago(age) .. ' ago') or ''))
  end
end

local function easeOut(x) return 1 - (1 - x) ^ 3 end

local function glideTo(p)
  p = math.max(0, math.min(maxPos(), p))
  if p == target and (sliding or pos == p) then return end
  from, target, start, sliding = pos, p, os.clock(), true
  SKIN:Bang('!CommandMeasure', 'Anim', 'Stop 1')
  SKIN:Bang('!CommandMeasure', 'Anim', 'Execute 1')
end

local function jumpTop()
  SKIN:Bang('!CommandMeasure', 'Anim', 'Stop 1')
  pos, target, sliding = 0, 0, false
end

-- Mouse wheel: one row per notch; notches during a glide add to where it's heading. Ignored for a
-- second after loading (a reload with the cursor over the card sometimes receives a stray scroll).
function Scroll(n)
  if os.clock() - loaded < 1 then return end
  glideTo(target + n)
end

function Frame()
  if not sliding then return end
  local t = math.min(1, (os.clock() - start) / DURATION)
  pos = from + (target - from) * easeOut(t)
  if t == 1 then pos = target; sliding = false; SKIN:Bang('!CommandMeasure', 'Anim', 'Stop 1') end
  render()
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

-- Left side click: open or close the list picker.
function Pick()
  picking = not picking
  jumpTop(); fill(); render()
  SKIN:Bang('!UpdateMeter', '*'); SKIN:Bang('!Redraw')
end

-- The card lost focus (a click anywhere else): close the picker.
function Close()
  if picking then Pick() end
end

-- Row click (slot k): in the picker, show that list (and remember it); otherwise open To Do.
function Click(k)
  local idx = math.floor(pos) + k   -- slot k shows item floor(pos) + k (see render)
  if not picking then
    if items[idx] then SKIN:Bang('["shell:AppsFolder\\Microsoft.Todos_8wekyb3d8bbwe!App"]') end
    return
  end
  local l = lists[idx]
  if not l then return end
  SKIN:Bang('!SetVariable', 'ListId', l[1])
  SKIN:Bang('!WriteKeyValue', 'Variables', 'ListId', l[1])
  Pick()
end

function Initialize()
  S = tonumber(SKIN:GetVariable('S'))
  loaded = os.clock()
end

function Update()
  lists = records(str('Lists'), 4)
  fill()
  if target > maxPos() then glideTo(maxPos()) end
  render()
  return #items
end
