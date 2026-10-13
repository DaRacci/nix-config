local layout = require("layout.split-tree.layout")
local overlay = require("layout.split-tree.overlay")
local pointer = require("layout.split-tree.pointer")
local util = require("layout.split-tree.util")

local M = {}

local layouts = {}
local overlayController = overlay.new()
local pointerController = pointer.new(layouts, overlayController)

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
    end,

    layout_msg = function(ctx, msg)
      return layout.layoutMessage(layouts, ctx, msg)
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
