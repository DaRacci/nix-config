-- format: { "1" = { name = "...", monitor = "...", cmds = "..." }, ... }
local workspaceConfig = @workspaceConfig@

hl.on("hyprland.start", function()
  for id, config in pairs(workspaceConfig) do
    if config.monitor then
      hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = config.monitor }))
    end
  end
end)

for id, config in pairs(workspaceConfig) do
  local spec = {
    workspace = id,
    persistent = true,
  }

  if config.name ~= "" then
    spec.default_name = config.name
  end

  if config.cmds ~= "" then
    spec.on_created_empty = config.cmds
  end

  hl.workspace_rule(spec)
end
