local layout = require("layout.split-tree.layout")
local overlay = require("layout.split-tree.overlay")
local persist = require("layout.split-tree.persist")
local pointer = require("layout.split-tree.pointer")
local util = require("layout.split-tree.util")

local M = {}

local layouts = {}
local overlayController = overlay.new()
local pointerController = pointer.new(layouts, overlayController)
local layoutPersist = persist.new()

-- Restore the tree saved before the last reload so the first layout pass reproduces the existing
-- geometry instead of resizing windows to default proportions. Only accept states with a real tree
-- and give each a `boxes` table so `splitLeaf`/pointer paths can index it before the first
-- recalculate populates it.
local restored = layoutPersist.load()
if restored then
  for key, state in pairs(restored) do
    if type(state) == "table" and type(state.root) == "table" then
      state.boxes = state.boxes or {}
      layouts[key] = state
    end
  end
end

local function snapshot()
  local data = {}
  for key, state in pairs(layouts) do
    if state.root then
      data[key] = { root = state.root, lastActiveId = state.lastActiveId }
    end
  end
  return data
end

-- Hyprland has no pre-reload hook, so persist on a short throttle rather than on every change.
-- Tree changes mark the state dirty and a repeating timer flushes at most a couple of times a
-- second (writing only when the tree actually changed), disabling itself while idle. This keeps a
-- config reload from losing the tree without a write on every poll of an in-progress drag.
local SAVE_INTERVAL_MS = 500
local persistDirty = false
local saveTimer
local saveTimerEnabled = false

local function setSaveTimerEnabled(enabled)
  if saveTimer and saveTimerEnabled ~= enabled then
    saveTimerEnabled = enabled
    saveTimer:set_enabled(enabled)
  end
end

local function markPersistDirty()
  persistDirty = true
  setSaveTimerEnabled(true)
end

if hl and hl.timer then
  saveTimer = hl.timer(function()
    if not persistDirty then
      setSaveTimerEnabled(false)
      return
    end

    persistDirty = false
    layoutPersist.save(snapshot())
  end, { timeout = SAVE_INTERVAL_MS, type = "repeat" })
  saveTimer:set_enabled(false)
end

-- Drop a window's leaf from every workspace tree that still holds it. Used for closes and for
-- moves to another workspace, where the window is still mapped (so a target-set prune would keep
-- it) but no longer belongs to that workspace.
local function dropLeaf(id)
  local dropped = false

  for _, state in pairs(layouts) do
    if state.root and layout.contains(state.root, id) then
      state.root = select(1, layout.removeLeaf(state.root, id))
      dropped = true
    end
  end

  if dropped then
    markPersistDirty()
  end
end

local function windowId(window)
  return window and window.stable_id and tostring(window.stable_id)
end

if hl and hl.on then
  -- Hyprland emits `window.close` before removing the target (the window is still mapped then), so
  -- prune here to let the sibling reclaim the space on the recalculate that follows.
  hl.on("window.close", function(window)
    local id = windowId(window)
    if id then
      dropLeaf(id)
    end
  end)

  hl.on("window.move_to_workspace", function(window, workspace)
    local id = windowId(window)
    local target = util.workspaceKeyFromWorkspace(workspace)
    if not id then
      return
    end

    for key, state in pairs(layouts) do
      if key ~= target and state.root and layout.contains(state.root, id) then
        state.root = select(1, layout.removeLeaf(state.root, id))
        markPersistDirty()
      end
    end
  end)
end

local configuration = {
  exe = nil,
}

function M.configure(opts)
  opts = opts or {}
  configuration.exe = opts.overlay or configuration.exe
end

-- Launched on `hyprland.start` (and re-armed on reload). The Rust client enforces a single
-- instance with a file lock, so extra launches on reload are harmless no-ops.
function M.startOverlay()
  if not configuration.exe then
    return
  end

  local statePath = overlay.statePath()
  overlayController.write({ dragging = false })

  hl.exec_cmd(configuration.exe .. " --state " .. statePath)
end

function M.beginMouseDrag()
  return pointerController.beginMouseDrag()
end

function M.endMouseDrag()
  return pointerController.endMouseDrag()
end

function M.toggleFloat()
  return pointerController.toggleFloat()
end

function M.beginMouseResize()
  return pointerController.beginMouseResize()
end

function M.endMouseResize()
  return pointerController.endMouseResize()
end

function M.beginBorderResize()
  return pointerController.beginBorderResize()
end

function M.endBorderResize()
  return pointerController.endBorderResize()
end

function M.register()
  hl.layout.register("split-tree", {
    recalculate = function(ctx)
      layout.recalculate(layouts, ctx)
      markPersistDirty()
    end,

    layout_msg = function(ctx, msg)
      local result = layout.layoutMessage(layouts, ctx, msg)
      markPersistDirty()
      return result
    end,
  })
end

M._testing = {
  borderZoneHit = layout.borderZoneHit,
  buildDropMap = layout.buildDropMap,
  contains = layout.contains,
  contentBox = layout.contentBox,
  directionForPointInBox = layout.directionForPointInBox,
  dropTarget = layout.dropTarget,
  findWindowAtPointInWorkspace = function(store, workspace, x, y, ignoreId)
    local state = store[workspace]
    if not state then
      return nil
    end

    return layout.findWindowAtPoint(state, x, y, ignoreId)
  end,
  getState = util.getState,
  insertLeafBeside = layout.insertLeafBeside,
  isInCurvedCorner = layout.isInCurvedCorner,
  layoutMessage = layout.layoutMessage,
  moveLeafToEdge = layout.moveLeafToEdge,
  moveMessageForBoxes = layout.moveMessageForBoxes,
  moveMessageForPoint = layout.moveMessageForPoint,
  moveMessageForRoot = layout.moveMessageForRoot,
  moveWindowInDirection = layout.moveWindowInDirection,
  newStore = layout.newStore,
  onRecalculate = layout.onRecalculate,
  pickResizeEdge = layout.pickResizeEdge,
  pickResizeEdges = layout.pickResizeEdges,
  previewForMove = layout.previewForMove,
  projectedBoxes = layout.projectedBoxes,
  recalculate = layout.recalculate,
  removeLeaf = layout.removeLeaf,
  resizeByPixels = layout.resizeByPixels,
  resizeEdgeByPixels = layout.resizeEdgeByPixels,
  resizeForDirection = layout.resizeForDirection,
  resolveDrop = layout.resolveDrop,
  stateFor = util.stateFor,
  windowBox = pointerController._testing.windowBox,
}

return M
