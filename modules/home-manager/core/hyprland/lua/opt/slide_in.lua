-- format: [{ bind, name, position, width, height }]
local config = @slideInConfig@
local pyprClient = "@pyprClient@"
local pyprServiceReload = "@pyprServiceReload@"

hl.on("hyprland.start", function()
  hl.exec_cmd(pyprServiceReload)
end)

for _, entry in ipairs(config) do
  local cmd = pyprClient .. " toggle " .. entry.name
  hl.bind(entry.bind, hl.dsp.exec_cmd(cmd))
end
