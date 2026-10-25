-- Task Manager style GPU % for one adapter: sum each engine's load across processes,
-- then report the busiest engine (summing all engines overcounts).
-- ponytail: reads the top 24 process/engine pairs across all GPUs; the rest are ~0.

local long = {
  ['3d'] = '3D rendering', videodecode = 'Video playback', videoencode = 'Video encoding',
  videoprocessing = 'Video processing', copy = 'Copying data', compute = 'Compute', cuda = 'CUDA',
}
local short = {
  ['3d'] = '3D', videodecode = 'Decode', videoencode = 'Encode',
  videoprocessing = 'Video', copy = 'Copy', compute = 'Compute', cuda = 'CUDA',
}

function Initialize()
  engines = {}
  for i = 1, 24 do engines[i] = SKIN:GetMeasure('Eng' .. i) end
  match = SELF:GetOption('Match'):lower()
end

-- "NVIDIA GeForce RTX 4050 Laptop GPU" -> "RTX 4050", "Intel(R) UHD Graphics" -> "Intel UHD"
local function shorten(d)
  d = d:gsub('%(R%)', ''):gsub('%(TM%)', ''):gsub('NVIDIA GeForce ', ''):gsub('AMD ', '')
       :gsub(' Laptop GPU', ''):gsub(' Graphics', ''):gsub('%s+', ' ')
  return (d:match('^%s*(.-)%s*$'))
end

-- LUIDs change every boot, so look this card's adapter up in
-- `reg query HKLM\SOFTWARE\Microsoft\DirectX /s` and match it by name.
local function findLuid()
  local desc, hex
  for line in SKIN:GetMeasure('Adapters'):GetStringValue():gmatch('[^\r\n]+') do
    if line:match('^HKEY') then
      desc, hex = nil, nil
    else
      desc = line:match('Description%s+REG_SZ%s+(.-)%s*$') or desc
      hex = line:match('AdapterLuid%s+REG_QWORD%s+(0x%x+)') or hex
      if desc and hex and desc:lower():find(match, 1, true) then
        local n = tonumber(hex)
        SKIN:Bang('!SetVariable', 'Label', shorten(desc))
        return string.format('0x%08x_0x%08x', math.floor(n / 2^32), n % 2^32)
      end
    end
  end
end

function Update()
  if not luid then
    luid = findLuid()
    if not luid then
      if not asked then SKIN:Bang('!CommandMeasure', 'Adapters', 'Run'); asked = true end
      return 0
    end
  end

  local load, kind = {}, {}
  for _, m in ipairs(engines) do
    local l, eng, t = m:GetStringValue():lower():match('luid_(.-)_phys_%d+_eng_(%d+)_engtype_(.+)$')
    if l == luid then
      load[eng] = (load[eng] or 0) + m:GetValue()
      kind[eng] = (t:gsub('_%d+$', ''))
    end
  end

  local busy = {}
  for e, v in pairs(load) do
    if v >= 1 then busy[#busy + 1] = { kind[e], v } end
  end
  table.sort(busy, function(a, b) return a[2] > b[2] end)

  local parts = {}
  for i = 1, math.min(2, #busy) do
    parts[i] = string.format('%s %d%%', short[busy[i][1]] or busy[i][1], busy[i][2] + 0.5)
  end
  SKIN:Bang('!SetVariable', 'Engine', busy[1] and (long[busy[1][1]] or busy[1][1]) or 'Idle')
  SKIN:Bang('!SetVariable', 'Breakdown', #parts > 0 and table.concat(parts, ', ') or 'Nothing busy')
  return busy[1] and math.min(busy[1][2], 100) or 0
end
