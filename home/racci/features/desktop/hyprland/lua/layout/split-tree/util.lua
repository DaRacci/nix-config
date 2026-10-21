local M = {}

function M.clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

function M.copyBox(box)
  return {
    x = box.x,
    y = box.y,
    w = box.w,
    h = box.h,
  }
end

function M.pointInBox(box, point)
  return box
    and point
    and point.x >= box.x
    and point.x <= box.x + box.w
    and point.y >= box.y
    and point.y <= box.y + box.h
end

-- Workspaces are keyed by id: names are not unique,
-- so two workspaces can share one name and would otherwise share one tree.
function M.workspaceKeyFromWorkspace(workspace)
  if not workspace then
    return "__default"
  end

  if workspace.id ~= nil then
    return tostring(workspace.id)
  end

  return workspace.name or workspace.addressable_name or "__default"
end

-- Workspace selector for a dispatch.
-- Special workspaces carry a negative id and are addressed by name.
function M.workspaceSelector(workspace)
  if not workspace then
    return nil
  end

  if (workspace.id or 0) >= 0 then
    return tostring(workspace.id)
  end

  return workspace.addressable_name or workspace.name
end

function M.workspaceKey(ctx)
  for _, target in ipairs(ctx.targets) do
    local window = target.window
    local workspace = window and window.workspace
    if workspace then
      return M.workspaceKeyFromWorkspace(workspace)
    end
  end

  return "__default"
end

function M.workspaceKeyFromWindow(window)
  return M.workspaceKeyFromWorkspace(window and window.workspace)
end

function M.targetId(target)
  local window = target.window
  return window and tostring(window.stable_id) or tostring(target.index)
end

function M.getState(store, key)
  if not store[key] then
    store[key] = {
      area = nil,
      boxes = {},
      lastActiveId = nil,
      root = nil,
    }
  end

  return store[key]
end

function M.stateFor(store, ctx)
  return M.getState(store, M.workspaceKey(ctx))
end

function M.activeId(state, ctx)
  for _, target in ipairs(ctx.targets) do
    local window = target.window
    if window and window.active then
      return M.targetId(target)
    end
  end

  return state.lastActiveId
end

return M
