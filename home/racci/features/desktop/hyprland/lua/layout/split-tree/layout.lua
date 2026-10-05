local util = require("layout.split-tree.util")

local M = {}

local maxRatio = 0.9
local minRatio = 0.1
local resizeStep = 0.05
local defaultInsertRatio = 0.5
local edgeActivationMargin = 18

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

local function collectTargets(ctx)
  local orderedIds = {}
  local present = {}
  local targets = {}

  for _, target in ipairs(ctx.targets) do
    local id = util.targetId(target)
    present[id] = true
    targets[id] = target
    orderedIds[#orderedIds + 1] = id
  end

  return present, targets, orderedIds
end

local function prune(node, present)
  if not node then
    return nil
  end

  if node.kind == "leaf" then
    return present[node.id] and node or nil
  end

  node.first = prune(node.first, present)
  node.second = prune(node.second, present)

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

  state.root = prune(state.root, present)

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
  local entry = findSplitEntry(state, id, axis)
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

  -- Compare the cursor offset from each axis, normalized by that axis' half-size. A plain
  -- nearest-edge comparison biases wide (full-width) tiles toward up/down splits because their
  -- top/bottom edges are physically closer, making it hard to insert a column split. Normalizing
  -- makes each axis compete on equal footing.
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

function M.pickResizeEdges(state, id, point, requireBorder)
  local box = state.boxes[id]
  if not box or not point then
    return nil
  end

  local xCandidate = {
    distance = math.min(distanceToEdge(box, point, "left"), distanceToEdge(box, point, "right")),
    edge = distanceToEdge(box, point, "left") <= distanceToEdge(box, point, "right") and "left" or "right",
  }
  local yCandidate = {
    distance = math.min(distanceToEdge(box, point, "up"), distanceToEdge(box, point, "down")),
    edge = distanceToEdge(box, point, "up") <= distanceToEdge(box, point, "down") and "up" or "down",
  }

  local hasX = findSplitEntry(state, id, "x") ~= nil
  local hasY = findSplitEntry(state, id, "y") ~= nil
  local edges = {}

  if requireBorder then
    if hasX and xCandidate.distance <= edgeActivationMargin then
      edges.x = xCandidate.edge
    end
    if hasY and yCandidate.distance <= edgeActivationMargin then
      edges.y = yCandidate.edge
    end
  elseif hasX and hasY and xCandidate.distance <= edgeActivationMargin and yCandidate.distance <= edgeActivationMargin then
    edges.x = xCandidate.edge
    edges.y = yCandidate.edge
  elseif hasX and (not hasY or xCandidate.distance <= yCandidate.distance) then
    edges.x = xCandidate.edge
  elseif hasY then
    edges.y = yCandidate.edge
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

  -- Cursor still over the dragged window: treat it as "stays put" rather than pulling it to a
  -- workspace edge, so releasing without crossing into another tile is a no-op.
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

-- Compute the tile the moving window would occupy if dropped at the cursor. Used by the
-- overlay client to preview the pending placement without reflowing the real windows. Returns
-- the projected box (global coordinates), the drop target id and the drop direction.
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

-- Inset a projected box by half the inner gap, leaving sides flush with the workspace root
-- (the workspace area already excludes outer gaps). Used so the preview lines up with real borders.
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

-- Precompute every possible drop outcome for one dragged window across all visible workspaces.
-- `states` maps workspace key -> layout state (a state may be windowless but still expose `area`).
-- `halfInset` insets projected boxes by half the inner gap so the preview lines up with real
-- window borders (root-edge sides are left flush; the workspace area already excludes outer gaps).
-- Returns { regions = { { id, box } }, roots = { { id, box } }, entries = { ["<id|dir>"] = box } }
-- where region/root ids are namespaced with the workspace key (`<ws>:<leaf>` / `<ws>:root`).
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
          -- Empty visible workspace: the dropped window becomes the only tile and fills it.
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
