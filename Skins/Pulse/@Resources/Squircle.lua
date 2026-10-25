-- Apple-style continuous-curvature ("squircle") corners for a card (Width x Height), built once as a
-- Rainmeter Path and handed to the background meter through #CardPath#.
-- Bezier constants are the iOS 7 rounded-rect corner: each corner spans 1.52866 x radius.

-- One corner as (along-edge, into-corner) offsets in radii, drawn clockwise.
local CORNER = {
  { 'LineTo', 1.52866483, 0 },
  { 'CurveTo', 0.66993427, 0.06549600, 1.08849296, 0, 0.86840694, 0 },
  { 'LineTo', 0.63149399, 0.07491100 },
  { 'CurveTo', 0.07491100, 0.63149399, 0.37282392, 0.16905899, 0.16905899, 0.37282392 },
  { 'LineTo', 0.06549600, 0.66993427 },
  { 'CurveTo', 0, 1.52866483, 0, 0.86840694, 0, 1.08849296 },
}

function Initialize()
  local w, r = SELF:GetNumberOption('Width'), SELF:GetNumberOption('Radius')
  local h = SELF:GetNumberOption('Height', w)
  local lo, right, bottom = 0.5, w - 0.5, h - 0.5   -- half-pixel inset keeps the 1 px border crisp

  -- corners clockwise: corner point, direction along the incoming edge (u), outgoing edge (v)
  local corners = {
    { right, lo, 1, 0, 0, 1 }, { right, bottom, 0, 1, -1, 0 }, { lo, bottom, -1, 0, 0, -1 }, { lo, lo, 0, -1, 1, 0 },
  }
  local function pt(c, a, b)   -- corner - a*r*u + b*r*v
    return string.format('%.2f,%.2f', c[1] - a * r * c[3] + b * r * c[5], c[2] - a * r * c[4] + b * r * c[6])
  end

  local parts = { string.format('%.2f,%.2f', lo + 1.52866483 * r, lo) }
  for _, c in ipairs(corners) do
    for _, seg in ipairs(CORNER) do
      if seg[1] == 'LineTo' then
        parts[#parts + 1] = 'LineTo ' .. pt(c, seg[2], seg[3])
      else
        parts[#parts + 1] = 'CurveTo ' .. pt(c, seg[2], seg[3]) .. ',' .. pt(c, seg[4], seg[5]) .. ',' .. pt(c, seg[6], seg[7])
      end
    end
  end
  parts[#parts + 1] = 'ClosePath 1'
  SKIN:Bang('!SetVariable', 'CardPath', table.concat(parts, ' | '))
end

function Update() return 0 end
