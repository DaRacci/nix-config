-- format: [{ bind, name, position, width, height }]
local config = @slideInConfig@
local pyprClient = "@pyprClient@"

for _, entry in ipairs(config) do
  local cmd = pyprClient .. " toggle " .. entry.name
  hl.bind(entry.bind, hl.dsp.exec_cmd(cmd))
end
