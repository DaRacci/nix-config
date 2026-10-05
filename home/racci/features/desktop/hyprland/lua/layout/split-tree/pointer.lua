local layout = require("layout.split-tree.layout")
local util = require("layout.split-tree.util")

local M = {}

local pointerPollMs = 16
local resizePixelThreshold = 12
local movePixelThreshold = 20

local noopOverlay = {
  hide = function() end,
  write = function() end,
}

local function configNumber(candidates, fallback)
  for _, key in ipairs(candidates) do
    local ok, value = pcall(hl.get_config, key)
    if ok and type(value) == "number" then
      return value
    end
  end

  return fallback
end

local function handoffStyle()
  -- 25% thicker than the configured border so the preview stands out from real windows.
  local borderWidth = math.max(1, math.floor(configNumber({ "general.border_size", "general:border_size" }, 2) * 1.25 + 0.5))
  local rounding = configNumber({ "decoration.rounding", "decoration:rounding" }, 8)

  -- Tokyo Night palette.
  return {
    border = "7dcfffcc",
    border_width = borderWidth,
    fill = "7aa2f733",
    rounding = rounding,
    source_border = "bb9af7aa",
    source_border_width = borderWidth,
  }
end

local function handoffHalfInset()
  return configNumber({ "general.gaps_in", "general:gaps_in" }, 5) / 2
end

function M.new(layouts, overlay)
  overlay = overlay or noopOverlay
  local pointerSession = nil
  local pointerTimer = nil

  local function sessionState(session)
    return session and layouts[session.workspace] or nil
  end

  local function windowBox(window)
    if not window then
      return nil
    end

    local at = window.at
    local size = window.size
    if type(at) ~= "table" or type(size) ~= "table" then
      return nil
    end

    local x = at.x or at[1]
    local y = at.y or at[2]
    local w = size.w or size.x or size[1]
    local h = size.h or size.y or size[2]

    if not x or not y or not w or not h then
      return nil
    end

    return {
      x = x,
      y = y,
      w = w,
      h = h,
    }
  end

  local function activeWorkspaceContext()
    local activeWorkspace = hl.get_active_workspace()
    local workspace = util.workspaceKeyFromWorkspace(activeWorkspace)
    local state = layouts[workspace]
    if not activeWorkspace or not state then
      return nil
    end

    return {
      activeWorkspace = activeWorkspace,
      state = state,
      workspace = workspace,
    }
  end

  local function findManagedTiledWindowAtPoint(point)
    if not point then
      return nil
    end

    local workspaceCtx = activeWorkspaceContext()
    if not workspaceCtx then
      return nil
    end

    for _, window in ipairs(hl.get_workspace_windows(workspaceCtx.activeWorkspace)) do
      if not window.floating then
        local windowId = window.stable_id and tostring(window.stable_id) or nil
        local box = windowId and workspaceCtx.state.boxes[windowId] or nil

        if box and util.pointInBox(box, point) then
          return {
            box = box,
            state = workspaceCtx.state,
            window = window,
            windowId = windowId,
            workspace = workspaceCtx.workspace,
          }
        end
      end
    end

    return nil
  end

  local function findFloatingWindowAtPoint(point)
    if not point then
      return nil
    end

    local workspaceCtx = activeWorkspaceContext()
    if not workspaceCtx then
      return nil
    end

    for _, window in ipairs(hl.get_workspace_windows(workspaceCtx.activeWorkspace)) do
      if window.floating then
        local box = windowBox(window)
        if box and util.pointInBox(box, point) then
          return window
        end
      end
    end

    return nil
  end

  -- Visible workspaces (one active workspace per monitor) that we could drop into.
  local function visibleStates()
    local states = {}

    local ok, monitors = pcall(hl.get_monitors)
    if ok and type(monitors) == "table" then
      for _, monitor in ipairs(monitors) do
        local workspace = monitor.active_workspace
        if workspace then
          local key = util.workspaceKeyFromWorkspace(workspace)
          local state = layouts[key]
          if state and (state.root or state.area) then
            states[key] = state
          end
        end
      end
    end

    return states
  end

  -- Emit (or clear) the handoff the Rust overlay consumes. Called on drag start, on every
  -- recalculate while a drag is active, and on drag end.
  local function emitHandoff()
    local session = pointerSession
    if not session or session.mode ~= "move" then
      overlay.hide()
      return
    end

    local state = sessionState(session)
    if not state or not state.root then
      overlay.hide()
      return
    end

    local states = visibleStates()
    states[session.workspace] = state

    local halfInset = handoffHalfInset()
    local dropMap = layout.buildDropMap(states, session.workspace, session.windowId, halfInset)
    if not dropMap then
      overlay.hide()
      return
    end

    local source = state.boxes[session.windowId]
    if source and state.root and state.root.box then
      source = layout.insetForGaps(source, state.root.box, halfInset)
    end

    overlay.write({
      dragging = true,
      draggingId = session.windowId,
      entries = dropMap.entries,
      regions = dropMap.regions,
      roots = dropMap.roots,
      source = source and util.copyBox(source) or nil,
      style = handoffStyle(),
      workspace = session.workspace,
    })
  end

  local function stopPointerSession()
    local session = pointerSession

    if pointerTimer then
      pointerTimer:set_enabled(false)
    end

    overlay.hide()
    pointerSession = nil
    return session
  end

  local function cancelPointerSession()
    stopPointerSession()
  end

  -- While a drag is active the tree is frozen, but unrelated events (a window opening/closing,
  -- a reload-triggered reflow) still run recalculate. Re-emit so the overlay's drop map tracks it.
  layout.onRecalculate(function(state)
    if pointerSession and sessionState(pointerSession) == state then
      emitHandoff()
    end
  end)

  local function pollPointerSession()
    if not pointerSession then
      return
    end

    local cursor = hl.get_cursor_pos()
    if not cursor then
      return
    end

    -- Move previews are computed by the Rust overlay; the Lua side only needs the resize polling.
    if pointerSession.mode == "move" then
      return
    end

    local dx = cursor.x - pointerSession.cursor.x
    local dy = cursor.y - pointerSession.cursor.y
    if dx == 0 and dy == 0 then
      return
    end

    local state = sessionState(pointerSession)
    if not state or not layout.contains(state.root, pointerSession.windowId) or not pointerSession.edges then
      pointerSession.cursor = { x = cursor.x, y = cursor.y }
      return
    end

    local nextCursorX = pointerSession.cursor.x
    local nextCursorY = pointerSession.cursor.y

    if pointerSession.edges.x and math.abs(dx) >= resizePixelThreshold then
      hl.dispatch(hl.dsp.layout(("resize_edge_px %s %s %.4f"):format(pointerSession.windowId, pointerSession.edges.x, dx)))
      nextCursorX = cursor.x
    end

    if pointerSession.edges.y and math.abs(dy) >= resizePixelThreshold then
      hl.dispatch(hl.dsp.layout(("resize_edge_px %s %s %.4f"):format(pointerSession.windowId, pointerSession.edges.y, dy)))
      nextCursorY = cursor.y
    end

    pointerSession.cursor = { x = nextCursorX, y = nextCursorY }
  end

  local function ensurePointerTimer()
    if pointerTimer then
      return pointerTimer
    end

    pointerTimer = hl.timer(pollPointerSession, {
      timeout = pointerPollMs,
      type = "repeat",
    })
    pointerTimer:set_enabled(false)

    return pointerTimer
  end

  local function startTiledSession(windowCtx, mode, edges)
    hl.dispatch(hl.dsp.focus({ window = windowCtx.window }))
    ensurePointerTimer()

    pointerSession = {
      cursor = { x = windowCtx.cursor.x, y = windowCtx.cursor.y },
      edges = edges,
      mode = mode,
      startCursor = { x = windowCtx.cursor.x, y = windowCtx.cursor.y },
      window = windowCtx.window,
      windowId = windowCtx.windowId,
      workspace = windowCtx.workspace,
    }

    if mode == "move" then
      emitHandoff()
      return { ok = true }
    end

    pointerTimer:set_enabled(true)
    return { ok = true }
  end

  local function managedWindowContext(cursor, opts)
    opts = opts or {}

    local hovered = nil
    if not opts.onlyActiveWindow then
      hovered = findManagedTiledWindowAtPoint(cursor)
      if hovered then
        hovered.cursor = cursor
        return hovered
      end
    end

    local window = hl.get_active_window()
    if not window then
      return nil
    end

    local windowId = window.stable_id and tostring(window.stable_id) or nil
    local workspace = util.workspaceKeyFromWindow(window)
    local state = layouts[workspace]
    if not windowId or not state or not layout.contains(state.root, windowId) then
      return nil
    end

    local box = state.boxes[windowId]
    if not box or (cursor and not util.pointInBox(box, cursor)) then
      return nil
    end

    return {
      box = box,
      cursor = cursor,
      state = state,
      window = window,
      windowId = windowId,
      workspace = workspace,
    }
  end

  local function beginSession(mode, opts)
    opts = opts or {}

    local cursor = hl.get_cursor_pos()

    local floatingUnder = findFloatingWindowAtPoint(cursor)
    local managed = nil
    if not floatingUnder then
      managed = managedWindowContext(cursor, opts)
    end

    if floatingUnder then
      if opts.passThroughOnMiss then
        return { ok = false }
      end

      hl.dispatch(hl.dsp.focus({ window = floatingUnder }))
      if mode == "move" then
        hl.dispatch(hl.dsp.window.drag())
      else
        hl.dispatch(hl.dsp.window.resize())
      end

      return { ok = true }
    end

    if managed then
      if mode == "resize" then
        local edges = layout.pickResizeEdges(managed.state, managed.windowId, cursor, opts.requireBorder)
        if not edges then
          return { ok = not opts.passThroughOnMiss }
        end

        return startTiledSession(managed, mode, edges)
      end

      return startTiledSession(managed, mode)
    end

    local window = hl.get_active_window()
    if window and window.floating then
      if opts.passThroughOnMiss then
        return { ok = false }
      end

      if mode == "move" then
        hl.dispatch(hl.dsp.window.drag())
      else
        hl.dispatch(hl.dsp.window.resize())
      end

      return { ok = true }
    end

    return { ok = not opts.passThroughOnMiss }
  end

  local api = {}

  function api.beginMouseDrag()
    if pointerSession then
      cancelPointerSession()
    end

    return beginSession("move")
  end

  function api.endMouseDrag()
    if pointerSession and pointerSession.mode == "move" then
      local session = stopPointerSession()
      local cursor = hl.get_cursor_pos() or session.cursor
      local dx = cursor and (cursor.x - session.startCursor.x) or 0
      local dy = cursor and (cursor.y - session.startCursor.y) or 0
      local apply = cursor and (math.abs(dx) >= movePixelThreshold or math.abs(dy) >= movePixelThreshold)

      if apply then
        local state = sessionState(session)
        local states = visibleStates()
        if state then
          states[session.workspace] = state
        end

        local key, targetId, direction = layout.resolveDrop(states, session.workspace, session.windowId, cursor)

        if key and key == session.workspace and state and state.root then
          local message = layout.moveMessageForBoxes(state.boxes, state.root.box, session.windowId, cursor)
          if message then
            hl.dispatch(hl.dsp.layout(message))
          end
        elseif key and direction then
          -- Cross-workspace drop: hand the window to the target workspace, focus it there, then
          -- reorder relative to the drop target within that workspace (skipped for empty
          -- workspaces, where the window simply becomes the only tile).
          local targetState = states[key]
          local targetHasWindows = targetState and targetState.root ~= nil

          hl.dispatch(hl.dsp.window.move({ window = session.window, workspace = key }))
          hl.dispatch(hl.dsp.focus({ window = session.window }))

          if targetHasWindows then
            local message = targetId
                and ("insert %s %s %s"):format(session.windowId, targetId, direction)
              or ("move %s %s"):format(direction, session.windowId)
            hl.dispatch(hl.dsp.layout(message))
          end
        end
      end
    end

    return { ok = true }
  end

  function api.toggleFloat()
    local window = hl.get_active_window()
    if not window then
      return { ok = false }
    end

    if window.floating then
      hl.dispatch(hl.dsp.window.float({ window = window, action = "toggle" }))
      return { ok = true }
    end

    local windowId = window.stable_id and tostring(window.stable_id) or nil
    local workspace = util.workspaceKeyFromWindow(window)
    local state = workspace and layouts[workspace] or nil
    local box = windowId and state and state.boxes[windowId] or nil

    hl.dispatch(hl.dsp.window.float({ window = window, action = "toggle" }))
    if box then
      hl.dispatch(hl.dsp.window.move({ window = window, x = box.x, y = box.y, relative = false }))
      hl.dispatch(hl.dsp.window.resize({ window = window, x = box.w, y = box.h, relative = false }))
    end

    return { ok = true }
  end

  function api.beginMouseResize()
    if pointerSession then
      cancelPointerSession()
    end

    return beginSession("resize")
  end

  function api.endMouseResize()
    if pointerSession and pointerSession.mode == "resize" then
      stopPointerSession()
    end

    return { ok = true }
  end

  function api.beginBorderResize()
    if pointerSession then
      cancelPointerSession()
    end

    return beginSession("resize", {
      onlyActiveWindow = true,
      passThroughOnMiss = true,
      requireBorder = true,
    })
  end

  function api.endBorderResize()
    if pointerSession and pointerSession.mode == "resize" then
      stopPointerSession()
      return { ok = true }
    end

    return { ok = false }
  end

  api._testing = {
    findWindowAtPointInWorkspace = function(workspace, x, y, ignoreId)
      local state = workspace and layouts[workspace] or nil
      if not state then
        return nil
      end

      return layout.findWindowAtPoint(state, x, y, ignoreId)
    end,
    windowBox = windowBox,
  }

  return api
end

return M
