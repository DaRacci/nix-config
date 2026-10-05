-- format: { "1" = { name = "...", monitor = "...", cmds = "..." }, ... }
local workspaceConfig = @workspaceConfig@

local function workspaceSelector(workspace)
  return workspace and (workspace.addressable_name or workspace.name or (workspace.id and tostring(workspace.id))) or nil
end

local function knownWorkspaces()
  local result = {}
  local ok, workspaces = pcall(hl.get_workspaces)
  if not ok or type(workspaces) ~= "table" then
    return result
  end

  for _, workspace in ipairs(workspaces) do
    local selector = workspaceSelector(workspace)
    if selector then
      result[selector] = true
    end
  end

  return result
end

hl.on("hyprland.start", function()
  local activeMonitor = hl.get_active_monitor()
  local activeWorkspace = hl.get_active_workspace()
  local existing = knownWorkspaces()
  local workspaceIds = {}

  for id in pairs(workspaceConfig) do
    workspaceIds[#workspaceIds + 1] = id
  end

  table.sort(workspaceIds, function(left, right)
    local leftNumber = tonumber(left)
    local rightNumber = tonumber(right)
    if leftNumber and rightNumber then
      return leftNumber < rightNumber
    end

    return tostring(left) < tostring(right)
  end)

  for _, id in ipairs(workspaceIds) do
    local config = workspaceConfig[id]
    if config.monitor and not existing[id] then
      hl.dispatch(hl.dsp.focus({ monitor = config.monitor }))
      hl.dispatch(hl.dsp.focus({ workspace = id, on_current_monitor = true }))
    end
  end

  if activeMonitor and activeMonitor.name then
    hl.dispatch(hl.dsp.focus({ monitor = activeMonitor.name }))
  end

  local selector = workspaceSelector(activeWorkspace)
  if selector then
    hl.dispatch(hl.dsp.focus({ workspace = selector, on_current_monitor = true }))
  end
end)

for id, config in pairs(workspaceConfig) do
  local spec = {
    workspace = id,
  }

  if config.name ~= "" then
    spec.default_name = config.name
  end

  if config.cmds ~= "" then
    spec.on_created_empty = config.cmds
  end

  for key, value in pairs(config.extraRules or {}) do
    spec[key] = value
  end

  hl.workspace_rule(spec)
end
