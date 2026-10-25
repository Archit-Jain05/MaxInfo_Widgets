-- Control bar: a row of six icons. Clicking power plan, Legion mode, temp files or Galaxy Buds
-- swaps the row for that item's options inside the same card; clicking anywhere else (the skin
-- loses focus) or the highlighted icon brings the row back. Also keeps the options live: active
-- plan / Legion mode, temp folder size, Galaxy Buds battery. Clicks run PulseAct.exe (Control.ini).

local SECTIONS = { 'plan', 'legion', 'temp', 'buds' }   -- icons 1-4, same order as Control.ini
local PLANS = {   -- must match the plan buttons in Control.ini
  'e63bdd3d-4372-4537-9ece-1137799f525d',   -- Power saver
  '381b4222-f694-41f0-9685-ff5bb260df2e',   -- Balanced
  '52521609-efc9-4268-b9ba-67dea73f18b2',   -- Legion Performance Mode
}
local ON_FILL, ON_TEXT = '255,255,255,235', '10,12,16'
local OFF_FILL, OFF_TEXT = '255,255,255,16', '237,238,240'

local sent, tick, freedUntil, open = {}, 0, 0, nil

local function set(name, value)
  if sent[name] ~= value then sent[name] = value; SKIN:Bang('!SetVariable', name, value) end
end

local function str(m) return SKIN:GetMeasure(m):GetStringValue() end

local function measureTemp()
  SKIN:Bang('["' .. SKIN:GetVariable('@') .. 'PulseTemps\\PulseAct.exe" temp-size]')
end

local function size(bytes)
  if bytes >= 1024 ^ 3 then return string.format('%.1f GB', bytes / 1024 ^ 3) end
  return string.format('%d MB', math.floor(bytes / 1024 ^ 2 + 0.5))
end

local function segments(prefix, active)
  for i = 1, 3 do
    set(prefix .. i .. 'Fill', i == active and ON_FILL or OFF_FILL)
    set(prefix .. i .. 'Text', i == active and ON_TEXT or OFF_TEXT)
  end
end

-- Open/close animation: v runs 0 (icon row) -> 1 (options) over FRAMES ActionTimer frames.
-- The icon row and the options sit in the IconBox / SecBox containers, whose opacity and x
-- offset follow v. Reversing mid-way just turns v around. The hidden side is hidden at the ends
-- so its buttons can't be clicked.
local FRAMES = 12
local v, target = 0, 0

local function ease(x) return x < 0.5 and 4 * x ^ 3 or 1 - (-2 * x + 2) ^ 3 / 2 end

local function draw()
  local t = ease(v)
  SKIN:Bang('!SetVariable', 'IconA', math.floor(255 * (1 - t) + 0.5))
  SKIN:Bang('!SetVariable', 'IconDX', string.format('%.1f', -10 * t))
  SKIN:Bang('!SetVariable', 'SecA', math.floor(255 * t + 0.5))
  SKIN:Bang('!SetVariable', 'SecDX', string.format('%.1f', 18 * (1 - t)))
  SKIN:Bang('!UpdateMeter', 'IconBox')
  SKIN:Bang('!UpdateMeter', 'SecBox')
  SKIN:Bang('!Redraw')
end

local function animate(to)
  target = to
  SKIN:Bang('!ShowMeterGroup', to == 1 and open or 'Icons')
  SKIN:Bang('!CommandMeasure', 'Anim', 'Stop 1')
  SKIN:Bang('!CommandMeasure', 'Anim', 'Execute 1')
end

function Frame()
  if v == target then return end
  v = target > v and math.min(1, v + 1 / FRAMES) or math.max(0, v - 1 / FRAMES)
  draw()
  if v == 1 then SKIN:Bang('!HideMeterGroup', 'Icons') end
  if v == 0 then
    for _, s in ipairs(SECTIONS) do SKIN:Bang('!HideMeterGroup', s) end
    open = nil
  end
end

function Open(n)
  if open == SECTIONS[n] and target == 1 then return animate(0) end
  for _, s in ipairs(SECTIONS) do SKIN:Bang('!HideMeterGroup', s) end
  open = SECTIONS[n]
  if open == 'temp' then measureTemp() end
  animate(1)
end

function Collapse()
  if open and target == 1 then animate(0) end
end

function Update()
  if tick % 600 == 0 then measureTemp() end   -- and every 10 minutes
  tick = tick + 1

  local plan, p = str('ActivePlan'):lower(), 0
  for i, g in ipairs(PLANS) do if g == plan then p = i end end
  segments('P', p)
  segments('L', tonumber(str('LegionMode')) or 0)

  local busy = tonumber(str('TempBusy')) == 1
  local bytes, freed = tonumber(str('TempBytes')), tonumber(str('TempFreed'))
  if busy then freedUntil = tick + 8 end   -- keep "Freed" up for a few seconds after a clean
  if busy then set('TempText', 'Cleaning...')
  elseif freed and tick < freedUntil then set('TempText', 'Freed ' .. size(freed))
  else set('TempText', bytes and size(bytes) or '[\\x2014]') end

  local buds = 'Offline'
  for name, level, kind in str('Devices'):gmatch('([^;|]+)|(%d+)|(%a+)|%d') do
    if kind == 'earbuds' or name:lower():find('bud') then buds = level .. '% battery' end
  end
  set('BudsText', buds)
  return 0
end
