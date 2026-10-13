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
-- geometry instead of resizing windows to default proportions.
local restored = layoutPersist.load()
if restored then
  for key, state in pairs(restored) do
    layouts[key] = state
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
