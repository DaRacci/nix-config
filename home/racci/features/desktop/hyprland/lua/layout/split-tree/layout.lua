local util = require("layout.split-tree.util")

local M = {}

local maxRatio = 0.9
local minRatio = 0.1
local resizeStep = 0.05
local defaultInsertRatio = 0.5

-- Border grab margin: `extend_border_grab_area + border_size`,
-- measured outside the content box.
local function configNumber(candidates, fallback)
  for _, key in ipairs(candidates) do
    local ok, value = pcall(function()
      return hl.get_config(key)
    end)
    if ok and type(value) == "number" then
      return value
    end
  end

  return fallback
end

local function borderSize()
  return configNumber({ "general.border_size", "general:border_size" }, 2)
end

local function gapsIn()
  return configNumber({ "general.gaps_in", "general:gaps_in" }, 5)
end

local function resizeEdgeMargin()
  local extend = configNumber({ "general.extend_border_grab_area", "general:extend_border_grab_area" }, 15)
  return extend + borderSize()
end

local recalcListeners = {}

function M.onRecalculate(listener)
  recalcListeners[#recalcListeners + 1] = listener
end

local function leaf(id)
  return { kind = "leaf", id = id }
end

function M.contains(node, id)
  if not node then
    return false
  end

  if node.kind == "leaf" then
    return node.id == id
  end

  return M.contains(node.first, id) or M.contains(node.second, id)
end

function M.firstLeafId(node)
  if not node then
    return nil
  end

  if node.kind == "leaf" then
    return node.id
  end

  return M.firstLeafId(node.first) or M.firstLeafId(node.second)
end

-- Ids whose close event fired while the window was fullscreen.
-- Closing a fullscreen window runs the fullscreen-exit recalculate before Hyprland
-- removes the target, so that pass still lists the dying window and would re-tile it.
-- The tombstone is forgotten once the id is no longer listed.
local closingIds = {}

function M.markClosing(id, window)
  if not id or not window then
    return
  end

  if (window.fullscreen or 0) == 0 and (window.fullscreen_client or 0) == 0 then
    return
  end

  closingIds[id] = true
end

local function collectTargets(ctx)
  local orderedIds = {}
  local present = {}
  local targets = {}
  local listed = {}

  for _, target in ipairs(ctx.targets) do
    local window = target.window
    if window then
      local id = tostring(window.stable_id)
      listed[id] = true

      if not closingIds[id] then
        present[id] = true
        targets[id] = target
        orderedIds[#orderedIds + 1] = id
      end
    end
  end

  -- Stable ids are never reused, so a tombstone can be cleared once its id is gone.
  -- Clearing when nothing else is listed covers a lone fullscreen window that was
  -- unmapped rather than closed: no tile is left to protect, and that window still
  -- has to be tiled again when it is remapped.
  for id in pairs(closingIds) do
    if not listed[id] or #orderedIds == 0 then
      closingIds[id] = nil
    end
  end

  return present, targets, orderedIds
end

local function hasAbsent(node, present)
  if not node then
    return false
  end

  if node.kind == "leaf" then
    return not present[node.id]
  end

  return hasAbsent(node.first, present) or hasAbsent(node.second, present)
end

-- Mapped, tiled windows keyed by id -> workspace.
-- A leaf whose window is still here but absent from the target list must be kept,
-- since Hyprland re-adds targets one at a time on a layout switch.
local function aliveWindowWorkspaces()
  local map = {}

  if not (hl and hl.get_windows) then
    return map
  end

  local ok, windows = pcall(hl.get_windows)
  if not ok or type(windows) ~= "table" then
    return map
  end

  for _, window in ipairs(windows) do
    local id = window.stable_id and tostring(window.stable_id)
    if id and not window.floating then
      map[id] = util.workspaceKeyFromWindow(window)
    end
  end

  return map
end

-- `keep` ids are retained despite being absent from the target list (temporarily detached).
-- That preserves structure and ratios.
local function prune(node, present, keep)
  if not node then
    return nil
  end

  if node.kind == "leaf" then
    if present[node.id] or (keep and keep[node.id]) then
      return node
    end

    return nil
  end

  node.first = prune(node.first, present, keep)
  node.second = prune(node.second, present, keep)

  if not node.first then
    return node.second
  end

  if not node.second then
    return node.first
  end

  return node
end

local function splitAxisFor(state, id)
  local box = state.boxes[id]
  if box then
    return box.w >= box.h and "x" or "y"
  end

  return "x"
end

local function splitLeaf(state, node, active, newId)
  if node.kind == "leaf" then
    if node.id ~= active then
      return node, false
    end

    return {
      kind = "split",
      axis = splitAxisFor(state, active),
      ratio = defaultInsertRatio,
      first = leaf(active),
      second = leaf(newId),
    }, true
  end

  local updated, changed = splitLeaf(state, node.first, active, newId)
  if changed then
    node.first = updated
    return node, true
  end

  updated, changed = splitLeaf(state, node.second, active, newId)
  if changed then
    node.second = updated
    return node, true
  end

  return node, false
end

local function addTarget(state, id, anchorId)
  if not state.root then
    state.root = leaf(id)
    return
  end

  local splitId = anchorId
  if not splitId or not M.contains(state.root, splitId) then
    splitId = M.firstLeafId(state.root)
  end

  local updated, changed = splitLeaf(state, state.root, splitId, id)
  if changed then
    state.root = updated
    return
  end

  local fallbackId = M.firstLeafId(state.root)
  if fallbackId then
    state.root = select(1, splitLeaf(state, state.root, fallbackId, id))
  end
end

local function syncTree(state, ctx)
  local present, targets, orderedIds = collectTargets(ctx)

  local keep = nil
  if hasAbsent(state.root, present) then
    local key = util.workspaceKey(ctx)
    for id, workspaceKey in pairs(aliveWindowWorkspaces()) do
      if not present[id] and workspaceKey == key then
        keep = keep or {}
        keep[id] = true
      end
    end
  end

  state.root = prune(state.root, present, keep)

  local anchorId = util.activeId(state, ctx)
  if not anchorId or not M.contains(state.root, anchorId) then
    anchorId = state.lastActiveId
  end
  if not anchorId or not M.contains(state.root, anchorId) then
    anchorId = M.firstLeafId(state.root)
  end

  for _, id in ipairs(orderedIds) do
    if not M.contains(state.root, id) then
      addTarget(state, id, anchorId)
      anchorId = id
    end
  end

  return targets
end

local function placeNode(state, ctx, node, box, targets)
  if not node then
    return
  end

  node.box = util.copyBox(box)

  if node.kind == "leaf" then
    state.boxes[node.id] = util.copyBox(box)

    local target = targets[node.id]
    if target then
      target:place(box)
    end
    return
  end

  local firstBox
  local secondBox

  if node.axis == "x" then
    firstBox = ctx:split(box, "left", node.ratio)
    secondBox = ctx:split(box, "right", 1.0 - node.ratio)
  else
    firstBox = ctx:split(box, "top", node.ratio)
    secondBox = ctx:split(box, "bottom", 1.0 - node.ratio)
  end

  placeNode(state, ctx, node.first, firstBox, targets)
  placeNode(state, ctx, node.second, secondBox, targets)
end

local function overlap(startA, lengthA, startB, lengthB)
  return math.max(0, math.min(startA + lengthA, startB + lengthB) - math.max(startA, startB))
end

local function nearestNeighbor(state, id, direction)
  local activeBox = state.boxes[id]
  if not activeBox then
    return nil
  end

  local activeCx = activeBox.x + activeBox.w / 2
  local activeCy = activeBox.y + activeBox.h / 2
  local bestId = nil
  local bestScore = nil
  local fallbackId = nil
  local fallbackScore = nil

  for otherId, otherBox in pairs(state.boxes) do
    if otherId ~= id then
      local otherCx = otherBox.x + otherBox.w / 2
      local otherCy = otherBox.y + otherBox.h / 2
      local primaryGap = nil
      local crossOverlap = 0
      local crossDistance = 0

      if direction == "left" and otherCx < activeCx then
        primaryGap = activeBox.x - (otherBox.x + otherBox.w)
        crossOverlap = overlap(activeBox.y, activeBox.h, otherBox.y, otherBox.h)
        crossDistance = math.abs(otherCy - activeCy)
      elseif direction == "right" and otherCx > activeCx then
        primaryGap = otherBox.x - (activeBox.x + activeBox.w)
        crossOverlap = overlap(activeBox.y, activeBox.h, otherBox.y, otherBox.h)
        crossDistance = math.abs(otherCy - activeCy)
      elseif direction == "up" and otherCy < activeCy then
        primaryGap = activeBox.y - (otherBox.y + otherBox.h)
        crossOverlap = overlap(activeBox.x, activeBox.w, otherBox.x, otherBox.w)
        crossDistance = math.abs(otherCx - activeCx)
      elseif direction == "down" and otherCy > activeCy then
        primaryGap = otherBox.y - (activeBox.y + activeBox.h)
        crossOverlap = overlap(activeBox.x, activeBox.w, otherBox.x, otherBox.w)
        crossDistance = math.abs(otherCx - activeCx)
      end

      if primaryGap then
        local score = math.max(primaryGap, 0) * 1000 + crossDistance
        if crossOverlap > 0 then
          if not bestScore or score < bestScore then
            bestId = otherId
            bestScore = score
          end
        elseif not fallbackScore or score < fallbackScore then
          fallbackId = otherId
          fallbackScore = score
        end
      end
    end
  end

  return bestId or fallbackId
end

local function swapLeafIds(node, firstId, secondId)
  if not node then
    return
  end

  if node.kind == "leaf" then
    if node.id == firstId then
      node.id = secondId
    elseif node.id == secondId then
      node.id = firstId
    end
    return
  end

  swapLeafIds(node.first, firstId, secondId)
  swapLeafIds(node.second, firstId, secondId)
end

function M.axisForDirection(direction)
  if direction == "left" or direction == "right" then
    return "x"
  end

  return "y"
end

function M.wantsFirst(direction)
  return direction == "left" or direction == "up"
end

function M.findLeafPath(node, id, path)
  path = path or {}
  if not node then
    return nil
  end

  if node.kind == "leaf" then
    return node.id == id and path or nil
  end

  path[#path + 1] = { node = node, branch = "first" }
  local found = M.findLeafPath(node.first, id, path)
  if found then
    return found
  end

  path[#path] = { node = node, branch = "second" }
  found = M.findLeafPath(node.second, id, path)
  if found then
    return found
  end

  path[#path] = nil
  return nil
end

local function findSplitEntry(state, id, axis)
  local path = M.findLeafPath(state.root, id, {})
  if not path then
    return nil
  end

  for index = #path, 1, -1 do
    local entry = path[index]
    if entry.node.axis == axis then
      return entry
    end
  end

  return nil
end

function M.findEdgeEntry(state, id, edge)
  local path = M.findLeafPath(state.root, id, {})
  if not path then
    return nil
  end

  for index = #path, 1, -1 do
    local entry = path[index]
    if edge == "left" and entry.node.axis == "x" and entry.branch == "second" then
      return entry
    elseif edge == "right" and entry.node.axis == "x" and entry.branch == "first" then
      return entry
    elseif edge == "up" and entry.node.axis == "y" and entry.branch == "second" then
      return entry
    elseif edge == "down" and entry.node.axis == "y" and entry.branch == "first" then
      return entry
    end
  end

  return nil
end

local function resizeAlongAxis(state, id, axis, delta)
  local entry = findSplitEntry(state, id, axis)
  if not entry then
    return false
  end

  local box = entry.node.box
  local size = axis == "x" and box and box.w or box and box.h
  if not size or size <= 0 then
    return false
  end

  entry.node.ratio = util.clamp(entry.node.ratio + delta, minRatio, maxRatio)
  return true
end

function M.resizeForDirection(state, id, direction)
  local axis = M.axisForDirection(direction)
  local delta = (direction == "left" or direction == "up") and -resizeStep or resizeStep
  return resizeAlongAxis(state, id, axis, delta)
end

function M.resizeByPixels(state, id, axis, deltaPx)
  local entry = findSplitEntry(state, id, axis)
  if not entry then
    return false
  end

  local box = entry.node.box
  local size = axis == "x" and box and box.w or box and box.h
  if not size or size <= 0 then
    return false
  end

  return resizeAlongAxis(state, id, axis, deltaPx / size)
end

function M.resizeEdgeByPixels(state, id, edge, deltaPx)
  local axis = M.axisForDirection(edge)
  -- The divider must actually sit on the grabbed edge.
  -- The axis-only split moved the wrong one.
  local entry = M.findEdgeEntry(state, id, edge)
  if not entry then
    return false
  end

  local box = entry.node.box
  local size = axis == "x" and box and box.w or box and box.h
  if not size or size <= 0 then
    return false
  end

  local dimensionDelta = (edge == "left" or edge == "up") and -deltaPx or deltaPx
  local ratioDelta = dimensionDelta / size
  if entry.branch == "second" then
    ratioDelta = -ratioDelta
  end

  entry.node.ratio = util.clamp(entry.node.ratio + ratioDelta, minRatio, maxRatio)
  return true
end

function M.removeLeaf(node, id)
  if not node then
    return nil, nil, false
  end

  if node.kind == "leaf" then
    if node.id == id then
      return nil, node, true
    end

    return node, nil, false
  end

  local updatedFirst, removed, found = M.removeLeaf(node.first, id)
  if found then
    node.first = updatedFirst
    if not node.first then
      return node.second, removed, true
    end

    return node, removed, true
  end

  local updatedSecond
  updatedSecond, removed, found = M.removeLeaf(node.second, id)
  if found then
    node.second = updatedSecond
    if not node.second then
      return node.first, removed, true
    end

    return node, removed, true
  end

  return node, nil, false
end

local function insertBeside(node, targetId, newNode, direction, ratio)
  if not node then
    return nil, false
  end

  if node.kind == "leaf" then
    if node.id ~= targetId then
      return node, false
    end

    local first = M.wantsFirst(direction) and newNode or node
    local second = M.wantsFirst(direction) and node or newNode
    return {
      kind = "split",
      axis = M.axisForDirection(direction),
      ratio = ratio or defaultInsertRatio,
      first = first,
      second = second,
    }, true
  end

  local updated, changed = insertBeside(node.first, targetId, newNode, direction, ratio)
  if changed then
    node.first = updated
    return node, true
  end

  updated, changed = insertBeside(node.second, targetId, newNode, direction, ratio)
  if changed then
    node.second = updated
    return node, true
  end

  return node, false
end

local function ratioForEdgePull(state, id, direction)
  local box = state.boxes[id]
  local rootBox = state.root and state.root.box or nil
  local axis = M.axisForDirection(direction)
  local size = axis == "x" and box and box.w or box and box.h
  local total = axis == "x" and rootBox and rootBox.w or rootBox and rootBox.h

  if not size or not total or total <= 0 then
    return defaultInsertRatio
  end

  local rawRatio = size / total
  if rawRatio >= maxRatio or rawRatio <= minRatio then
    return defaultInsertRatio
  end

  local movedRatio = util.clamp(rawRatio, minRatio, maxRatio)
  if M.wantsFirst(direction) then
    return movedRatio
  end

  return util.clamp(1 - movedRatio, minRatio, maxRatio)
end

function M.moveLeafToEdge(state, id, direction)
  local remainder, removed, found = M.removeLeaf(state.root, id)
  if not found or not removed then
    return false
  end

  if not remainder then
    state.root = removed
    return true
  end

  state.root = {
    kind = "split",
    axis = M.axisForDirection(direction),
    ratio = ratioForEdgePull(state, id, direction),
    first = M.wantsFirst(direction) and removed or remainder,
    second = M.wantsFirst(direction) and remainder or removed,
  }

  return true
end

function M.insertLeafBeside(state, movingId, targetId, direction)
  if movingId == targetId then
    return false
  end

  local remainder, removed, found = M.removeLeaf(state.root, movingId)
  if not found then
    remainder = state.root
    removed = nil
  elseif not remainder then
    state.root = removed
    return false
  end

  if not remainder or not M.contains(remainder, targetId) then
    state.root = remainder or state.root
    return false
  end

  local movingLeaf = removed or leaf(movingId)
  local updated, inserted = insertBeside(remainder, targetId, movingLeaf, direction, defaultInsertRatio)
  state.root = updated or remainder
  return inserted
end

function M.moveWindowInDirection(state, id, direction)
  local neighborId = nearestNeighbor(state, id, direction)
  if neighborId then
    swapLeafIds(state.root, id, neighborId)
    return true
  end

  return M.moveLeafToEdge(state, id, direction)
end

local function findWindowAtPointInBoxes(boxes, x, y, ignoreId)
  local bestId = nil
  local bestArea = nil

  for id, box in pairs(boxes) do
    if id ~= ignoreId and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h then
      local area = box.w * box.h
      if not bestArea or area < bestArea then
        bestId = id
        bestArea = area
      end
    end
  end

  return bestId
end

function M.findWindowAtPoint(state, x, y, ignoreId)
  return findWindowAtPointInBoxes(state.boxes, x, y, ignoreId)
end

function M.directionForPointInBox(box, point)
  if not box or not point then
    return nil
  end

  -- Normalize per axis so wide tiles don't bias toward up/down splits.
  local halfW = box.w / 2
  local halfH = box.h / 2
  local nx = halfW > 0 and (point.x - (box.x + halfW)) / halfW or 0
  local ny = halfH > 0 and (point.y - (box.y + halfH)) / halfH or 0

  if math.abs(nx) >= math.abs(ny) then
    return nx < 0 and "left" or "right"
  end

  return ny < 0 and "up" or "down"
end

local function distanceToEdge(box, point, edge)
  if edge == "left" then
    return math.abs(point.x - box.x)
  elseif edge == "right" then
    return math.abs((box.x + box.w) - point.x)
  elseif edge == "up" then
    return math.abs(point.y - box.y)
  end

  return math.abs((box.y + box.h) - point.y)
end

-- Nearest edge with a real divider.
-- A dead edge is ignored, not swapped for the opposite side.
local function pickAxisEdge(state, id, box, point, lowEdge, highEdge, margin)
  local lowDistance = distanceToEdge(box, point, lowEdge)
  local highDistance = distanceToEdge(box, point, highEdge)

  local nearest, nearestDistance, other, otherDistance
  if lowDistance <= highDistance then
    nearest, nearestDistance, other, otherDistance = lowEdge, lowDistance, highEdge, highDistance
  else
    nearest, nearestDistance, other, otherDistance = highEdge, highDistance, lowEdge, lowDistance
  end

  if M.findEdgeEntry(state, id, nearest) then
    return nearest, nearestDistance
  end

  if otherDistance <= margin and M.findEdgeEntry(state, id, other) then
    return other, otherDistance
  end

  return nil, nil
end

-- Hyprland draws the window (and tests border grabs) against the content box:
-- the tiled region inset by `border_size` on workspace edges,
-- and by `border_size + gaps_in` on interior edges.
function M.contentBox(state, id)
  local box = state and state.boxes and state.boxes[id]
  if not box then
    return nil
  end

  local border = borderSize()
  local inner = border + gapsIn()
  local area = state.area

  local left, top, right, bottom = border, border, border, border
  if area then
    left = (box.x <= area.x + 0.5) and border or inner
    right = (box.x + box.w >= area.x + area.w - 0.5) and border or inner
    top = (box.y <= area.y + 0.5) and border or inner
    bottom = (box.y + box.h >= area.y + area.h - 0.5) and border or inner
  end

  return {
    x = box.x + left,
    y = box.y + top,
    w = box.w - left - right,
    h = box.h - top - bottom,
  }
end

-- Shortest distance from `point` to `box`.
-- Zero when the point is inside.
function M.distanceToBox(box, point)
  if not box or not point then
    return math.huge
  end

  local dx = math.max(box.x - point.x, 0, point.x - (box.x + box.w))
  local dy = math.max(box.y - point.y, 0, point.y - (box.y + box.h))
  return math.sqrt(dx * dx + dy * dy)
end

-- Mirrors CWindow::isInCurvedCorner:
-- a corner-clipped point inside the content box still counts.
function M.isInCurvedCorner(box, x, y)
  local rounding = configNumber({ "decoration.rounding", "decoration:rounding" }, 8)
  local power = configNumber({ "decoration.rounding_power", "decoration:rounding_power" }, 2)
  if rounding <= 0 or borderSize() >= rounding then
    return false
  end

  local x0 = box.x + rounding
  local y0 = box.y + rounding
  local x1 = box.x + box.w - rounding
  local y1 = box.y + box.h - rounding

  local function outside(dx, dy)
    return dx ^ power + dy ^ power > rounding ^ power
  end

  if x < x0 and y < y0 then
    return outside(x0 - x, y0 - y)
  elseif x > x1 and y < y0 then
    return outside(x - x1, y0 - y)
  elseif x < x0 and y > y1 then
    return outside(x0 - x, y - y1)
  elseif x > x1 and y > y1 then
    return outside(x - x1, y - y1)
  end

  return false
end

-- Border grab zone Hyprland uses:
-- within `extend_border_grab_area + border_size` outside the content box,
-- or a clipped rounded corner.
function M.borderZoneHit(state, id, point)
  local content = M.contentBox(state, id)
  if not content or not point then
    return false
  end

  local margin = resizeEdgeMargin()
  if not util.pointInBox({
    x = content.x - margin,
    y = content.y - margin,
    w = content.w + margin * 2,
    h = content.h + margin * 2,
  }, point) then
    return false
  end

  if util.pointInBox(content, point) then
    return M.isInCurvedCorner(content, point.x, point.y)
  end

  return true
end

function M.pickResizeEdges(state, id, point, requireBorder)
  local content = M.contentBox(state, id)
  if not content or not point then
    return nil
  end

  local margin = resizeEdgeMargin()
  local xEdge, xDistance = pickAxisEdge(state, id, content, point, "left", "right", margin)
  local yEdge, yDistance = pickAxisEdge(state, id, content, point, "up", "down", margin)
  local edges = {}

  if requireBorder then
    if xEdge and xDistance <= margin then
      edges.x = xEdge
    end
    if yEdge and yDistance <= margin then
      edges.y = yEdge
    end
  elseif xEdge and yEdge and xDistance <= margin and yDistance <= margin then
    edges.x = xEdge
    edges.y = yEdge
  elseif xEdge and (not yEdge or xDistance <= yDistance) then
    edges.x = xEdge
  elseif yEdge then
    edges.y = yEdge
  end

  if not edges.x and not edges.y then
    return nil
  end

  return edges
end

function M.pickResizeEdge(state, id, point, requireBorder)
  local edges = M.pickResizeEdges(state, id, point, requireBorder)
  if not edges then
    return nil, nil
  end

  if edges.x then
    return edges.x, "x"
  end

  return edges.y, "y"
end

local function cloneNode(node)
  if not node then
    return nil
  end

  local cloned = {
    kind = node.kind,
  }

  if node.box then
    cloned.box = util.copyBox(node.box)
  end

  if node.kind == "leaf" then
    cloned.id = node.id
    return cloned
  end

  cloned.axis = node.axis
  cloned.ratio = node.ratio
  cloned.first = cloneNode(node.first)
  cloned.second = cloneNode(node.second)
  return cloned
end

local function projectBoxes(node, box, boxes)
  if not node or not box then
    return
  end

  node.box = util.copyBox(box)

  if node.kind == "leaf" then
    boxes[node.id] = util.copyBox(box)
    return
  end

  local firstBox
  local secondBox

  if node.axis == "x" then
    firstBox = { x = box.x, y = box.y, w = box.w * node.ratio, h = box.h }
    secondBox = {
      x = box.x + box.w * node.ratio,
      y = box.y,
      w = box.w * (1.0 - node.ratio),
      h = box.h,
    }
  else
    firstBox = { x = box.x, y = box.y, w = box.w, h = box.h * node.ratio }
    secondBox = {
      x = box.x,
      y = box.y + box.h * node.ratio,
      w = box.w,
      h = box.h * (1.0 - node.ratio),
    }
  end

  projectBoxes(node.first, firstBox, boxes)
  projectBoxes(node.second, secondBox, boxes)
end

M.cloneNode = cloneNode

function M.projectedBoxes(root, movingId)
  if not root then
    return nil, nil
  end

  local rootBox = root.box
  if not rootBox then
    return nil, nil
  end

  local projectedRoot = select(1, M.removeLeaf(cloneNode(root), movingId))
  if not projectedRoot then
    return {}, rootBox
  end

  local boxes = {}
  projectBoxes(projectedRoot, rootBox, boxes)
  return boxes, rootBox
end

function M.dropTarget(boxes, rootBox, movingId, cursor)
  if not boxes or not cursor then
    return nil, nil
  end

  local targetId = findWindowAtPointInBoxes(boxes, cursor.x, cursor.y, movingId)
  if targetId then
    return targetId, M.directionForPointInBox(boxes[targetId], cursor)
  end

  -- Still over the dragged window:
  -- stays put, so a release without crossing a tile is a no-op.
  local movingBox = boxes[movingId]
  if movingBox and util.pointInBox(movingBox, cursor) then
    return nil, nil
  end

  if util.pointInBox(rootBox, cursor) then
    return nil, M.directionForPointInBox(rootBox, cursor)
  end

  return nil, nil
end

function M.moveMessageForBoxes(boxes, rootBox, movingId, cursor)
  local targetId, direction = M.dropTarget(boxes, rootBox, movingId, cursor)
  if not direction then
    return nil
  end

  if targetId then
    return ("insert %s %s %s"):format(movingId, targetId, direction)
  end

  return ("move %s %s"):format(direction, movingId)
end

function M.moveMessageForRoot(root, movingId, cursor)
  local boxes, rootBox = M.projectedBoxes(root, movingId)
  return M.moveMessageForBoxes(boxes, rootBox, movingId, cursor)
end

function M.moveMessageForPoint(state, movingId, cursor)
  if not state or not state.root or not cursor then
    return nil
  end

  return M.moveMessageForRoot(state.root, movingId, cursor)
end

-- Tile the moving window would occupy if dropped at `cursor`,
-- for the overlay preview.
function M.previewForMove(state, movingId, cursor)
  if not state or not state.root or not cursor then
    return nil
  end

  local rootBox = state.root.box
  if not rootBox then
    return nil
  end

  local targetId, direction = M.dropTarget(state.boxes, rootBox, movingId, cursor)
  if not direction then
    return nil
  end

  local simulated = { root = cloneNode(state.root), boxes = state.boxes }
  if targetId then
    M.insertLeafBeside(simulated, movingId, targetId, direction)
  else
    M.moveLeafToEdge(simulated, movingId, direction)
  end

  if not simulated.root then
    return nil
  end

  local projected = {}
  projectBoxes(simulated.root, rootBox, projected)
  return projected[movingId], targetId, direction
end

-- Inset by half the inner gap so the preview lines up with real borders;
-- root edges stay flush.
local function gapInsetBox(box, rootBox, halfInset)
  if not box or not rootBox or not halfInset or halfInset <= 0 then
    return util.copyBox(box)
  end

  local left = (box.x <= rootBox.x + 0.5) and 0 or halfInset
  local right = (box.x + box.w >= rootBox.x + rootBox.w - 0.5) and 0 or halfInset
  local top = (box.y <= rootBox.y + 0.5) and 0 or halfInset
  local bottom = (box.y + box.h >= rootBox.y + rootBox.h - 0.5) and 0 or halfInset

  return {
    h = box.h - top - bottom,
    w = box.w - left - right,
    x = box.x + left,
    y = box.y + top,
  }
end

M.insetForGaps = gapInsetBox

-- Precompute every drop outcome for one dragged window across visible workspaces.
-- Returns { regions, roots, entries },
-- with region/root ids namespaced as `<ws>:<leaf>` / `<ws>:root`.
function M.buildDropMap(states, draggedKey, movingId, halfInset)
  if not states or not movingId then
    return nil
  end

  halfInset = halfInset or 0

  local directions = { "left", "right", "up", "down" }
  local regions = {}
  local roots = {}
  local entries = {}

  local function project(state, rootBox, apply)
    local simulated = { root = cloneNode(state.root), boxes = state.boxes }
    apply(simulated)
    if not simulated.root then
      return nil
    end

    local projected = {}
    projectBoxes(simulated.root, rootBox, projected)
    return projected[movingId]
  end

  local function wrapRoot(state, rootBox, direction)
    local node = {
      kind = "split",
      axis = M.axisForDirection(direction),
      ratio = defaultInsertRatio,
      first = M.wantsFirst(direction) and leaf(movingId) or cloneNode(state.root),
      second = M.wantsFirst(direction) and cloneNode(state.root) or leaf(movingId),
    }

    local projected = {}
    projectBoxes(node, rootBox, projected)
    return projected[movingId]
  end

  for key, state in pairs(states) do
    if state then
      local rootBox = state.root and state.root.box or state.area
      if rootBox then
        roots[#roots + 1] = { id = key .. ":root", box = util.copyBox(rootBox) }

        if state.root then
          local regionIds = {}
          for id, box in pairs(state.boxes) do
            if not (key == draggedKey and id == movingId) then
              regions[#regions + 1] = { id = key .. ":" .. id, box = util.copyBox(box) }
              regionIds[#regionIds + 1] = id
            end
          end

          table.sort(regionIds)

          for _, id in ipairs(regionIds) do
            for _, direction in ipairs(directions) do
              local box = project(state, rootBox, function(simulated)
                M.insertLeafBeside(simulated, movingId, id, direction)
              end)
              if box then
                entries[key .. ":" .. id .. "|" .. direction] = gapInsetBox(box, rootBox, halfInset)
              end
            end
          end

          for _, direction in ipairs(directions) do
            local box
            if key == draggedKey then
              box = project(state, rootBox, function(simulated)
                M.moveLeafToEdge(simulated, movingId, direction)
              end)
            else
              box = wrapRoot(state, rootBox, direction)
            end

            if box then
              entries[key .. ":root|" .. direction] = gapInsetBox(box, rootBox, halfInset)
            end
          end
        else
          -- Empty visible workspace:
          -- the dropped window becomes the only tile and fills it.
          local box = gapInsetBox(rootBox, rootBox, halfInset)
          for _, direction in ipairs(directions) do
            entries[key .. ":root|" .. direction] = box
          end
        end
      end
    end
  end

  return {
    entries = entries,
    regions = regions,
    roots = roots,
  }
end

-- Resolve where a drop at `cursor` lands across visible workspaces.
-- Returns `workspaceKey, targetId|nil, direction|nil`.
-- A nil workspace means "no drop".
function M.resolveDrop(states, draggedKey, movingId, cursor)
  if not states or not cursor then
    return nil
  end

  local bestKey = nil
  local bestId = nil
  local bestArea = nil
  for key, state in pairs(states) do
    if state and state.root then
      for id, box in pairs(state.boxes) do
        if not (key == draggedKey and id == movingId) and util.pointInBox(box, cursor) then
          local area = box.w * box.h
          if not bestArea or area < bestArea then
            bestKey, bestId, bestArea = key, id, area
          end
        end
      end
    end
  end

  if bestId then
    return bestKey, bestId, M.directionForPointInBox(states[bestKey].boxes[bestId], cursor)
  end

  local dragged = states[draggedKey]
  local movingBox = dragged and dragged.boxes[movingId]
  if movingBox and util.pointInBox(movingBox, cursor) then
    return nil
  end

  local rootKey = nil
  local rootBox = nil
  local rootArea = nil
  for key, state in pairs(states) do
    local box = state and (state.root and state.root.box or state.area)
    if box and util.pointInBox(box, cursor) then
      local area = box.w * box.h
      if not rootArea or area < rootArea then
        rootKey, rootBox, rootArea = key, box, area
      end
    end
  end

  if rootKey then
    return rootKey, nil, M.directionForPointInBox(rootBox, cursor)
  end

  return nil
end

function M.recalculate(store, ctx)
  local state = util.stateFor(store, ctx)
  state.area = util.copyBox(ctx.area)
  if #ctx.targets == 0 then
    state.boxes = {}
    state.lastActiveId = nil
    return state
  end

  local targets = syncTree(state, ctx)
  state.boxes = {}
  placeNode(state, ctx, state.root, ctx.area, targets)

  local currentActiveId = util.activeId(state, ctx)
  if currentActiveId and targets[currentActiveId] then
    state.lastActiveId = currentActiveId
  else
    state.lastActiveId = M.firstLeafId(state.root)
  end

  for _, listener in ipairs(recalcListeners) do
    listener(state, ctx)
  end

  return state, targets
end

function M.layoutMessage(store, ctx, msg)
  local state = util.stateFor(store, ctx)
  local words = {}
  for word in msg:gmatch("%S+") do
    words[#words + 1] = word
  end

  local command = words[1]
  local currentActiveId = util.activeId(state, ctx)

  if command == "move" then
    local direction = words[2]
    local windowId = words[3] or currentActiveId
    if windowId then
      M.moveWindowInDirection(state, windowId, direction)
    end
  elseif command == "resize" then
    local direction = words[2]
    local windowId = words[3] or currentActiveId
    if windowId then
      M.resizeForDirection(state, windowId, direction)
    end
  elseif command == "resize_px" then
    local windowId = words[2] or currentActiveId
    local axis = words[3]
    local deltaPx = tonumber(words[4])

    if not windowId or not axis or not deltaPx then
      return "split-tree: expected resize_px <window-id> <x|y> <delta-px>"
    end

    M.resizeByPixels(state, windowId, axis, deltaPx)
  elseif command == "resize_edge_px" then
    local windowId = words[2] or currentActiveId
    local edge = words[3]
    local deltaPx = tonumber(words[4])

    if not windowId or not edge or not deltaPx then
      return "split-tree: expected resize_edge_px <window-id> <left|right|up|down> <delta-px>"
    end

    M.resizeEdgeByPixels(state, windowId, edge, deltaPx)
  elseif command == "insert" then
    local movingId = words[2]
    local targetId = words[3]
    local direction = words[4]

    if not movingId or not targetId or not direction then
      return "split-tree: expected insert <moving-id> <target-id> <left|right|up|down>"
    end

    M.insertLeafBeside(state, movingId, targetId, direction)
  else
    return "split-tree: expected move <dir> [window-id], resize <dir> [window-id], resize_px <window-id> <x|y> <delta-px>, resize_edge_px <window-id> <dir> <delta-px>, or insert <moving-id> <target-id> <dir>"
  end

  return true
end

function M.newStore()
  return {}
end

return M
