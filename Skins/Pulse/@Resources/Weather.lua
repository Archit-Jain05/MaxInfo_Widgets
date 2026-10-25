-- Weather card: condition text and a composed icon from the Open-Meteo WMO weather code, and
-- follows the laptop's location. Segoe Fluent has sun, moon and cloud but no rain, storm or snow,
-- so those are a cloud plus drawn drops, a bolt or a snowflake.

local TEXT = {
  [0] = 'Clear', [1] = 'Mostly clear', [2] = 'Partly cloudy', [3] = 'Cloudy', [45] = 'Fog', [48] = 'Fog',
  [51] = 'Light drizzle', [53] = 'Drizzle', [55] = 'Heavy drizzle', [56] = 'Freezing drizzle', [57] = 'Freezing drizzle',
  [61] = 'Light rain', [63] = 'Rain', [65] = 'Heavy rain', [66] = 'Freezing rain', [67] = 'Freezing rain',
  [71] = 'Light snow', [73] = 'Snow', [75] = 'Heavy snow', [77] = 'Snow grains',
  [80] = 'Light showers', [81] = 'Showers', [82] = 'Heavy showers', [85] = 'Snow showers', [86] = 'Snow showers',
  [95] = 'Thunderstorm', [96] = 'Thunderstorm, hail', [99] = 'Thunderstorm, hail',
}

local function kind(code)
  if code <= 1 then return 'clear' end
  if code == 2 then return 'partly' end
  if code == 3 then return 'cloudy' end
  if code == 45 or code == 48 then return 'fog' end
  if (code >= 71 and code <= 77) or code == 85 or code == 86 then return 'snow' end
  if code >= 95 then return 'thunder' end
  return 'rain'
end

local sent = {}
local function set(name, value)
  if sent[name] ~= value then sent[name] = value; SKIN:Bang('!SetVariable', name, value) end
end

-- Reload with new coordinates when the laptop has moved more than ~1 km.
local function followLocation()
  local lat = tonumber(SKIN:GetMeasure('GeoLat'):GetStringValue())
  local lon = tonumber(SKIN:GetMeasure('GeoLon'):GetStringValue())
  if not lat or not lon then return end
  local curLat, curLon = tonumber(SKIN:GetVariable('Lat')), tonumber(SKIN:GetVariable('Lon'))
  if math.abs(lat - curLat) > 0.01 or math.abs(lon - curLon) > 0.01 then
    local file = SKIN:GetVariable('@') .. 'Location.inc'
    SKIN:Bang('!WriteKeyValue', 'Variables', 'Lat', string.format('%.4f', lat), file)
    SKIN:Bang('!WriteKeyValue', 'Variables', 'Lon', string.format('%.4f', lon), file)
    SKIN:Bang('!Refresh')
  end
end

local tick = 0
function Update()
  if tick % 60 == 0 then followLocation() end
  tick = tick + 1

  local raw = SKIN:GetMeasure('Code'):GetStringValue()
  local code = tonumber(raw)
  if not code then
    set('WxText', raw == '' and 'Updating' or 'Unavailable')
    return 0
  end
  local day = SKIN:GetMeasure('IsDay'):GetValue() == 1
  local k = kind(code)
  local sky = day and '[\\xE706]' or '[\\xE708]'

  set('WxText', TEXT[code] or 'Weather')
  set('WxMain', k == 'clear' and sky or '[\\xE753]')
  set('WxMainY', (k == 'clear' or k == 'cloudy') and 27 or (k == 'partly' and 29 or 23))
  -- small badge: sun/moon behind a partial cloud, bolt or snowflake under a cloud
  local badge, font, bx, by = '', 'Segoe Fluent Icons', 93, 38
  if k == 'partly' then badge, bx, by = sky, 101, 19
  elseif k == 'thunder' then badge = '[\\xE945]'
  elseif k == 'snow' then badge, font = '[\\x2744]', 'Segoe UI Symbol' end
  set('WxBadge', badge); set('WxBadgeFont', font); set('WxBadgeX', bx); set('WxBadgeY', by)
  set('WxDropsA', k == 'rain' and 255 or 0)
  set('WxFogA', k == 'fog' and 255 or 0)
  return code
end
