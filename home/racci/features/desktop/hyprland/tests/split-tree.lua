package.path = table.concat({
  "home/racci/features/desktop/hyprland/lua/?.lua",
  "home/racci/features/desktop/hyprland/lua/?/init.lua",
  package.path,
}, ";")

local SplitTree = require("layout.split-tree")
local testing = SplitTree._testing

local function fail(message)
  error(message, 0)
end

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
  end
end

local function assertClose(actual, expected, epsilon, message)
  if math.abs(actual - expected) > epsilon then
    fail(string.format("%s: expected %.6f, got %.6f", message, expected, actual))
  end
end

local function split(_, box, side, ratio)
  if side == "left" then
    return { x = box.x, y = box.y, w = box.w * ratio, h = box.h }
  elseif side == "right" then
    return { x = box.x + box.w * (1 - ratio), y = box.y, w = box.w * ratio, h = box.h }
  elseif side == "top" then
    return { x = box.x, y = box.y, w = box.w, h = box.h * ratio }
  elseif side == "bottom" then
    return { x = box.x, y = box.y + box.h * (1 - ratio), w = box.w, h = box.h * ratio }
  end

  fail("unknown split side: " .. tostring(side))
end

local function ctx(workspace, windows)
  local targets = {}

  for index, spec in ipairs(windows) do
    targets[#targets + 1] = {
      index = index,
      window = {
        active = spec.active or false,
        stable_id = spec.id,
        workspace = {
          addressable_name = workspace,
          name = workspace,
        },
      },
      place = function() end,
    }
  end

  return {
    area = { x = 0, y = 0, w = 1000, h = 1000 },
    targets = targets,
    split = split,
  }
end

local function recalc(store, workspace, windows)
  local value = ctx(workspace, windows)
  testing.recalculate(store, value)
  return value, testing.getState(store, workspace)
end

local function test_keyboard_resize_moves_split_in_arrow_direction()
  local store = testing.newStore()

  local context, state = recalc(store, "1", {
    { id = "a", active = true },
    { id = "b" },
  })

  assertEqual(state.root.axis, "x", "two windows start as horizontal split")
  assertClose(state.root.ratio, 0.5, 0.0001, "initial split ratio")

  testing.layoutMessage(store, context, "resize left")
  assertClose(state.root.ratio, 0.45, 0.0001, "left resize moves split left")

  testing.layoutMessage(store, context, "resize right")
  assertClose(state.root.ratio, 0.5, 0.0001, "right resize moves split right")
end

local function test_keyboard_resize_keeps_direction_for_second_branch()
  local store = testing.newStore()

  local context, state = recalc(store, "2", {
    { id = "a" },
    { id = "b", active = true },
  })

  testing.layoutMessage(store, context, "resize left")
  assertClose(state.root.ratio, 0.45, 0.0001, "left resize still moves split left for second branch")

  testing.layoutMessage(store, context, "resize right")
  assertClose(state.root.ratio, 0.5, 0.0001, "right resize still moves split right for second branch")
end

local function test_vertical_resize_after_reorient()
  local store = testing.newStore()

  local context, state = recalc(store, "3", {
    { id = "a", active = true },
    { id = "b" },
  })

  testing.layoutMessage(store, context, "move up")
  testing.recalculate(store, context)

  assertEqual(state.root.axis, "y", "move up reorients split vertically")

  testing.layoutMessage(store, context, "resize up")
  assertClose(state.root.ratio, 0.45, 0.0001, "up resize moves split up")

  testing.layoutMessage(store, context, "resize down")
  assertClose(state.root.ratio, 0.5, 0.0001, "down resize moves split down")
end

local function test_workspace_state_survives_switching()
  local store = testing.newStore()

  local workspaceSix = {
    { id = "a", active = true },
    { id = "b" },
  }

  local contextSix, stateSix = recalc(store, "6", workspaceSix)
  testing.layoutMessage(store, contextSix, "move up")
  testing.recalculate(store, contextSix)
  assertEqual(stateSix.root.axis, "y", "workspace six reoriented before switch")

  recalc(store, "1", {
    { id = "main", active = true },
  })

  _, stateSix = recalc(store, "6", workspaceSix)
  assertEqual(stateSix.root.axis, "y", "workspace six keeps split tree after switch")
end

local function test_pixel_resize_changes_ratio_by_container_size()
  local store = testing.newStore()

  local context, state = recalc(store, "4", {
    { id = "a", active = true },
    { id = "b" },
  })

  testing.layoutMessage(store, context, "resize_px a x 100")
  assertClose(state.root.ratio, 0.6, 0.0001, "100px drag on 1000px container adds 0.1 ratio")
end

local function test_move_left_pulls_window_out_to_workspace_edge()
  local store = testing.newStore()

  local context, state = recalc(store, "5", {
    { id = "1" },
    { id = "2", active = true },
    { id = "3" },
    { id = "4" },
  })

  state.root = {
    kind = "split",
    axis = "y",
    ratio = 0.5,
    first = { kind = "leaf", id = "1" },
    second = {
      kind = "split",
      axis = "x",
      ratio = 0.5,
      first = { kind = "leaf", id = "2" },
      second = {
        kind = "split",
        axis = "y",
        ratio = 0.5,
        first = { kind = "leaf", id = "3" },
        second = { kind = "leaf", id = "4" },
      },
    },
  }

  testing.recalculate(store, context)
  testing.layoutMessage(store, context, "move left")
  testing.recalculate(store, context)

  assertEqual(state.root.axis, "x", "move left makes workspace split horizontal")
  assertEqual(state.root.first.kind, "leaf", "moved window becomes direct left branch")
  assertEqual(state.root.first.id, "2", "window 2 pulled to left edge")
  assertEqual(state.root.second.axis, "y", "remaining windows stay stacked on right")
  assertEqual(state.root.second.first.id, "1", "window 1 stays top of right branch")
end

local function test_insert_reparents_window_relative_to_drop_target()
  local store = testing.newStore()

  local context, state = recalc(store, "6", {
    { id = "1", active = true },
    { id = "2" },
  })

  testing.layoutMessage(store, context, "insert 1 2 down")
  testing.recalculate(store, context)

  assertEqual(state.root.axis, "y", "drop below target creates vertical split")
  assertEqual(state.root.first.id, "2", "target stays above")
  assertEqual(state.root.second.id, "1", "moved window lands below target")
end

local function test_pick_resize_edge_uses_closest_controllable_edge()
  local store = testing.newStore()

  local _, state = recalc(store, "7", {
    { id = "1", active = true },
    { id = "2" },
  })

  local edge, axis = testing.pickResizeEdge(state, "1", { x = 495, y = 500 }, false)
  assertEqual(edge, "right", "right edge chosen for first branch")
  assertEqual(axis, "x", "horizontal split resizes on x axis")
end

local function test_pick_resize_edge_requires_border_when_requested()
  local store = testing.newStore()

  local _, state = recalc(store, "8", {
    { id = "1", active = true },
    { id = "2" },
  })

  local edge, axis = testing.pickResizeEdge(state, "1", { x = 250, y = 500 }, true)
  assertEqual(edge, nil, "center click does not start border resize")
  assertEqual(axis, nil, "center click yields no resize axis")
end

local function test_move_message_targets_window_edge_under_cursor()
  local store = testing.newStore()

  local _, state = recalc(store, "9", {
    { id = "1", active = true },
    { id = "2" },
  })

  local message = testing.moveMessageForPoint(state, "1", { x = 750, y = 995 })
  assertEqual(message, "insert 1 2 down", "cursor near target bottom inserts below target")
end

local function test_move_message_projects_drop_target_after_removing_moving_top_leaf()
  local store = testing.newStore()

  local context, state = recalc(store, "9b", {
    { id = "1" },
    { id = "2", active = true },
    { id = "3" },
  })

  state.root = {
    kind = "split",
    axis = "x",
    ratio = 0.5,
    first = { kind = "leaf", id = "1" },
    second = {
      kind = "split",
      axis = "y",
      ratio = 0.5,
      first = { kind = "leaf", id = "2" },
      second = { kind = "leaf", id = "3" },
    },
  }

  testing.recalculate(store, context)

  local message = testing.moveMessageForPoint(state, "2", { x = 520, y = 250 })
  assertEqual(message, "insert 2 3 left", "drop hit-test uses projected tree after moving leaf is removed")
end

local function test_move_message_projects_drop_target_for_nested_bottom_leaf()
  local store = testing.newStore()

  local context, state = recalc(store, "9c", {
    { id = "1" },
    { id = "2" },
    { id = "3", active = true },
  })

  state.root = {
    kind = "split",
    axis = "x",
    ratio = 0.5,
    first = { kind = "leaf", id = "1" },
    second = {
      kind = "split",
      axis = "y",
      ratio = 0.5,
      first = { kind = "leaf", id = "2" },
      second = { kind = "leaf", id = "3" },
    },
  }

  testing.recalculate(store, context)

  local message = testing.moveMessageForPoint(state, "3", { x = 600, y = 750 })
  assertEqual(message, "insert 3 2 left", "drop hit-test uses projected sibling geometry for nested bottom leaf")
end

local function test_resize_edge_px_ignores_outer_edge_with_no_divider()
  local store = testing.newStore()

  local context, state = recalc(store, "10", {
    { id = "1" },
    { id = "2", active = true },
  })

  -- Window 2 is the rightmost column, so its right edge is the workspace edge with no divider.
  -- Dragging it must not move the left divider (which would shrink window 2 from the left).
  testing.layoutMessage(store, context, "resize_edge_px 2 right 100")
  assertClose(state.root.ratio, 0.5, 0.0001, "outer edge with no divider is a no-op")

  -- Its left edge is the divider, so that one does resize (moving the divider left grows window 2).
  testing.layoutMessage(store, context, "resize_edge_px 2 left -100")
  assertClose(state.root.ratio, 0.4, 0.0001, "left edge of second branch drags the divider")
end

local function test_resize_edge_px_ignores_outer_bottom_edge_with_no_divider()
  local store = testing.newStore()

  local context, state = recalc(store, "11", {
    { id = "1", active = true },
    { id = "2" },
  })

  testing.layoutMessage(store, context, "move down")
  testing.recalculate(store, context)

  -- Window 1 ends up in the lower branch, so its bottom edge is the workspace edge, not a divider.
  testing.layoutMessage(store, context, "resize_edge_px 1 down 100")
  assertClose(state.root.ratio, 0.5, 0.0001, "outer bottom edge with no divider is a no-op")
end

local function test_resize_edge_px_targets_divider_on_grabbed_side()
  local store = testing.newStore()

  local context, state = recalc(store, "15", {
    { id = "1" },
    { id = "2", active = true },
    { id = "3" },
  })

  -- Left-leaning columns: ((1 | 2) | 3). Window 2's right divider is the root split; its left
  -- divider is the nested split. Grabbing the right edge must move the root divider, not the
  -- nested one (the old axis-only lookup moved the left divider instead).
  state.root = {
    kind = "split",
    axis = "x",
    ratio = 0.5,
    first = {
      kind = "split",
      axis = "x",
      ratio = 0.5,
      first = { kind = "leaf", id = "1" },
      second = { kind = "leaf", id = "2" },
    },
    second = { kind = "leaf", id = "3" },
  }

  testing.recalculate(store, context)

  testing.layoutMessage(store, context, "resize_edge_px 2 right 100")
  assertClose(state.root.ratio, 0.6, 0.0001, "right edge moves the root divider, growing window 2")
  assertClose(state.root.first.ratio, 0.5, 0.0001, "left divider is untouched")

  testing.recalculate(store, context)
  testing.layoutMessage(store, context, "resize_edge_px 2 left -100")
  assertClose(state.root.first.ratio, 0.5 - 100 / 600, 0.0001, "left edge moves the nested divider")
end

local function test_pick_resize_edges_returns_corner_axes()
  local store = testing.newStore()

  local context, state = recalc(store, "12", {
    { id = "1" },
    { id = "2", active = true },
    { id = "3" },
    { id = "4" },
  })

  -- Window 2 has a real divider on both its right and below, so a corner grab captures both axes.
  state.root = {
    kind = "split",
    axis = "x",
    ratio = 0.5,
    first = {
      kind = "split",
      axis = "y",
      ratio = 0.5,
      first = {
        kind = "split",
        axis = "x",
        ratio = 0.5,
        first = { kind = "leaf", id = "2" },
        second = { kind = "leaf", id = "1" },
      },
      second = { kind = "leaf", id = "3" },
    },
    second = { kind = "leaf", id = "4" },
  }

  testing.recalculate(store, context)

  local box = state.boxes["2"]
  local edges = testing.pickResizeEdges(state, "2", { x = box.x + box.w - 2, y = box.y + box.h - 2 }, false)
  assertEqual(edges.x, "right", "corner grab captures right edge")
  assertEqual(edges.y, "down", "corner grab captures bottom edge")
end

local function test_border_zone_hit_covers_gap_around_window()
  local store = testing.newStore()

  local _, state = recalc(store, "16", {
    { id = "1", active = true },
    { id = "2" },
  })

  local box = state.boxes["1"]
  local middleY = box.y + box.h / 2

  assertEqual(
    testing.borderZoneHit(state, "1", { x = box.x - 3, y = middleY }),
    true,
    "cursor just outside the edge (in the gap) counts as a border grab"
  )
  assertEqual(
    testing.borderZoneHit(state, "1", { x = box.x + 3, y = middleY }),
    false,
    "cursor just inside the edge is not a border grab"
  )
  assertEqual(
    testing.borderZoneHit(state, "1", { x = box.x + box.w / 2, y = middleY }),
    false,
    "cursor in the window body is not a border grab"
  )
end

-- Hyprland places the drawn window (the box it tests for border grabs) inside the tiled region:
-- `border_size` on workspace-area edges and `border_size + gaps_in` on interior split edges.
local function test_content_box_matches_hyprland_insets()
  local store = testing.newStore()

  local _, state = recalc(store, "21", {
    { id = "1", active = true },
    { id = "2" },
  })

  local first = testing.contentBox(state, "1")
  assertClose(first.x, 2, 0.0001, "workspace-edge side insets by border_size only")
  assertClose(first.x + first.w, 493, 0.0001, "interior split side insets by border_size + gaps_in")

  local second = testing.contentBox(state, "2")
  assertClose(second.x, 507, 0.0001, "interior split side insets by border_size + gaps_in")
  assertClose(second.x + second.w, 998, 0.0001, "workspace-edge side insets by border_size only")
end

-- A point clipped by a rounded corner still counts as a border grab in Hyprland.
local function test_border_zone_hit_allows_rounded_corner_inside()
  local store = testing.newStore()

  local _, state = recalc(store, "22", {
    { id = "1", active = true },
    { id = "2" },
  })

  assertEqual(testing.borderZoneHit(state, "1", { x = 3, y = 3 }), true, "rounded corner counts as a border grab")
  assertEqual(testing.borderZoneHit(state, "1", { x = 3, y = 500 }), false, "straight edge inside the body is not a grab")
end

local function test_persisted_tree_restores_without_resizing()
  local persist = require("layout.split-tree.persist")

  local store = testing.newStore()
  local context, state = recalc(store, "17", {
    { id = "1", active = true },
    { id = "2" },
    { id = "3" },
  })

  -- Move a divider off the default so a default rebuild would visibly resize.
  testing.layoutMessage(store, context, "resize_edge_px 1 right 100")
  testing.recalculate(store, context)

  local before = {}
  for id, box in pairs(state.boxes) do
    before[id] = { box.x, box.y, box.w, box.h }
  end

  local snapshot = {}
  for key, entry in pairs(store) do
    if entry.root then
      snapshot[key] = { root = entry.root, lastActiveId = entry.lastActiveId }
    end
  end

  local restored = persist.deserialize(persist.serialize(snapshot))
  local fresh = {}
  for key, entry in pairs(restored) do
    fresh[key] = entry
  end

  testing.recalculate(fresh, context)

  for id, box in pairs(before) do
    local after = fresh["17"].boxes[id]
    assertClose(after.x, box[1], 0.0001, "restored tree keeps x for " .. id)
    assertClose(after.y, box[2], 0.0001, "restored tree keeps y for " .. id)
    assertClose(after.w, box[3], 0.0001, "restored tree keeps width for " .. id)
    assertClose(after.h, box[4], 0.0001, "restored tree keeps height for " .. id)
  end
end

local function test_find_window_at_point_prefers_active_workspace_over_stale_hidden_workspace()
  local store = testing.newStore()

  local _, stateOne = recalc(store, "1", {
    { id = "one-a", active = true },
  })
  stateOne.boxes = {
    ["one-a"] = { x = 0, y = 0, w = 1000, h = 1000 },
  }

  local _, stateTwo = recalc(store, "2", {
    { id = "two-a", active = true },
  })
  stateTwo.boxes = {
    ["two-a"] = { x = 0, y = 0, w = 1000, h = 1000 },
  }

  local picked = testing.findWindowAtPointInWorkspace(store, "2", 100, 100, nil)
  assertEqual(picked, "two-a", "active workspace hit-test ignores stale hidden workspace boxes")
end

local function test_window_box_reads_named_at_and_size_fields()
  local box = testing.windowBox({
    at = { x = 10, y = 20 },
    size = { x = 300, y = 400 },
  })

  assertEqual(box.x, 10, "window box reads named at.x")
  assertEqual(box.y, 20, "window box reads named at.y")
  assertEqual(box.w, 300, "window box reads named size.x as width")
  assertEqual(box.h, 400, "window box reads named size.y as height")
end

local function test_window_box_reads_array_at_and_size_fields()
  local box = testing.windowBox({
    at = { 10, 20 },
    size = { 300, 400 },
  })

  assertEqual(box.x, 10, "window box reads array at[1]")
  assertEqual(box.y, 20, "window box reads array at[2]")
  assertEqual(box.w, 300, "window box reads array size[1] as width")
  assertEqual(box.h, 400, "window box reads array size[2] as height")
end

local function test_window_box_returns_nil_without_geometry()
  assertEqual(testing.windowBox({ floating = true }), nil, "window box is nil when geometry is absent")
  assertEqual(testing.windowBox(nil), nil, "window box is nil for missing window")
end

local function test_projected_boxes_drops_moving_leaf_and_reproportions()
  local store = testing.newStore()
  local _, state = recalc(store, "13", {
    { id = "1" },
    { id = "2" },
    { id = "3", active = true },
  })

  state.root = {
    kind = "split",
    axis = "x",
    ratio = 0.5,
    box = { x = 0, y = 0, w = 1000, h = 1000 },
    first = { kind = "leaf", id = "1" },
    second = {
      kind = "split",
      axis = "y",
      ratio = 0.5,
      first = { kind = "leaf", id = "2" },
      second = { kind = "leaf", id = "3" },
    },
  }

  local boxes = testing.projectedBoxes(state.root, "3")
  assertEqual(boxes["3"], nil, "moving leaf is absent from projected boxes")
  assertEqual(boxes["1"].w, 500, "left branch keeps half width")
  assertClose(boxes["2"].w, 500, 0.0001, "remaining sibling takes full right width")
  assertClose(boxes["2"].h, 1000, 0.0001, "remaining sibling takes full height after split collapse")
end

local function test_insert_leaf_beside_adds_absent_moving_leaf()
  local store = testing.newStore()
  local context, state = recalc(store, "14", {
    { id = "1", active = true },
    { id = "2" },
  })

  testing.layoutMessage(store, context, "insert 9 2 down")

  assertEqual(state.root.axis, "x", "existing horizontal split is preserved")
  assertEqual(state.root.second.axis, "y", "absent moving leaf inserts as vertical split beside target")
  assertEqual(state.root.second.first.id, "2", "target stays above")
  assertEqual(state.root.second.second.id, "9", "absent moving leaf lands below target")
end

local pointer = require("layout.split-tree.pointer")

local function makeFakeHl(windows)
  local dispatches = {}
  local timers = {}

  local function windowById(id)
    for _, window in ipairs(windows) do
      if tostring(window.stable_id) == tostring(id) then
        return window
      end
    end
    return nil
  end

  local fake = {
    cursor = { x = 0, y = 0 },
    activeWindow = windows[1],
    dispatches = dispatches,
    timers = timers,
    workspace = { addressable_name = "1", name = "1", id = 1 },
  }

  function fake.get_active_workspace()
    return fake.workspace
  end

  function fake.get_active_window()
    return fake.activeWindow
  end

  function fake.get_cursor_pos()
    return fake.cursor
  end

  function fake.get_monitor_at_cursor()
    return { name = "TEST", x = 0, y = 0 }
  end

  function fake.get_workspace_windows()
    return windows
  end

  function fake.get_window(selector)
    return windowById(selector:match("stableid:(.*)$") or selector)
  end

  function fake.dispatch(dispatcher)
    dispatches[#dispatches + 1] = dispatcher
  end

  function fake.timer(cb, opts)
    local timer = { cb = cb, enabled = false, opts = opts }
    function timer.set_enabled(_, value)
      timer.enabled = value
    end
    function timer.set_timeout(_, value)
      timer.timeout = value
    end
    timers[#timers + 1] = timer
    return timer
  end

  fake.dsp = {
    focus = function(spec)
      return { kind = "focus", spec = spec }
    end,
    layout = function(msg)
      if fake.onLayoutDispatch then
        fake.onLayoutDispatch(msg)
      end
      return { kind = "layout", msg = msg }
    end,
    window = {
      drag = function()
        return { kind = "drag" }
      end,
      resize = function(spec)
        return { kind = "resize", spec = spec }
      end,
      float = function(spec)
        return { kind = "float", spec = spec }
      end,
      move = function(spec)
        return { kind = "move", spec = spec }
      end,
      set_prop = function(spec)
        return { kind = "set_prop", spec = spec }
      end,
    },
  }

  return fake
end

local function fakeWindowsFromBoxes(boxes, specs)
  local windows = {}
  for _, spec in ipairs(specs) do
    local box = boxes[spec.id]
    windows[#windows + 1] = {
      stable_id = spec.id,
      floating = false,
      at = { x = box.x, y = box.y },
      size = { x = box.w, y = box.h },
      workspace = { addressable_name = "1", name = "1", id = 1 },
    }
  end
  return windows
end

local function lastLayoutDispatch(fake)
  local message = nil
  for _, dispatcher in ipairs(fake.dispatches) do
    if dispatcher.kind == "layout" then
      message = dispatcher.msg
    end
  end
  return message
end

local function repeatTimerOf(fake)
  for _, timer in ipairs(fake.timers) do
    if timer.opts and timer.opts.type == "repeat" then
      return timer
    end
  end
  return nil
end

local function hasPropValue(fake, value)
  for _, dispatcher in ipairs(fake.dispatches) do
    if dispatcher.kind == "set_prop" and dispatcher.spec.value == value then
      return true
    end
  end
  return false
end

local function makeFakeOverlay()
  local overlay = { hidden = 0, writes = {} }

  function overlay.write(state)
    overlay.writes[#overlay.writes + 1] = state
  end

  function overlay.hide()
    overlay.hidden = overlay.hidden + 1
    overlay.write({ dragging = false })
  end

  return overlay
end

local function lastOverlayWrite(overlay)
  return overlay.writes[#overlay.writes]
end

local function test_pointer_move_drag_dispatches_insert_on_release()
  local store = testing.newStore()
  local specs = { { id = "a", active = true }, { id = "b" }, { id = "c" } }
  local _, state = recalc(store, "1", specs)

  local windows = fakeWindowsFromBoxes(state.boxes, specs)
  local fake = makeFakeHl(windows)
  _G.hl = fake

  local controller = pointer.new(store, makeFakeOverlay())
  local boxA = state.boxes["a"]
  local boxB = state.boxes["b"]
  fake.cursor = { x = boxA.x + boxA.w / 2, y = boxA.y + boxA.h / 2 }

  local started = controller.beginMouseDrag()
  assertEqual(started.ok, true, "move drag begins over a tiled window")

  fake.cursor = { x = boxB.x + boxB.w / 2, y = boxB.y + boxB.h / 2 }
  controller.endMouseDrag()

  local message = lastLayoutDispatch(fake)
  assertEqual(message ~= nil, true, "release dispatches the drop")
  assertEqual(message:match("^insert a b ") ~= nil, true, "drop targets the hovered window")
end

local function test_pointer_writes_dropmap_handoff_during_drag()
  local store = testing.newStore()
  local specs = { { id = "a", active = true }, { id = "b" }, { id = "c" } }
  local _, state = recalc(store, "1", specs)

  local windows = fakeWindowsFromBoxes(state.boxes, specs)
  local fake = makeFakeHl(windows)
  _G.hl = fake

  local overlay = makeFakeOverlay()
  local controller = pointer.new(store, overlay)
  local boxA = state.boxes["a"]
  fake.cursor = { x = boxA.x + boxA.w / 2, y = boxA.y + boxA.h / 2 }
  controller.beginMouseDrag()

  local handoff = lastOverlayWrite(overlay)
  assertEqual(handoff.dragging, true, "handoff marks a drag in progress")
  assertEqual(handoff.source ~= nil, true, "handoff carries the source window box")
  assertEqual(type(handoff.regions), "table", "handoff carries drop regions")
  assertEqual(type(handoff.roots), "table", "handoff carries workspace roots")
  assertEqual(handoff.roots[1] ~= nil, true, "handoff carries at least one root")
  assertEqual(handoff.entries["1:root|left"] ~= nil, true, "handoff carries workspace-qualified root entries")

  controller.endMouseDrag()
  assertEqual(lastOverlayWrite(overlay).dragging, false, "handoff clears on release")
end

local function test_pointer_reemits_handoff_on_recalculate()
  local store = testing.newStore()
  local specs = { { id = "a", active = true }, { id = "b" }, { id = "c" } }
  local context, state = recalc(store, "1", specs)

  local windows = fakeWindowsFromBoxes(state.boxes, specs)
  local fake = makeFakeHl(windows)
  _G.hl = fake

  local overlay = makeFakeOverlay()
  local controller = pointer.new(store, overlay)
  local boxA = state.boxes["a"]
  fake.cursor = { x = boxA.x + boxA.w / 2, y = boxA.y + boxA.h / 2 }
  controller.beginMouseDrag()

  local before = #overlay.writes
  testing.recalculate(store, ctx("1", { { id = "a", active = true }, { id = "b" } }))
  assertEqual(#overlay.writes > before, true, "recalculate re-emits the handoff while dragging")

  controller.endMouseDrag()
end

-- A border grab in the gap between two tiles must pick the nearer window's shared divider.
local function test_border_grab_targets_nearest_window_edge()
  local store = testing.newStore()
  local specs = { { id = "a", active = true }, { id = "b" } }
  local _, state = recalc(store, "1", specs)

  local windows = fakeWindowsFromBoxes(state.boxes, specs)
  local fake = makeFakeHl(windows)
  _G.hl = fake

  local controller = pointer.new(store, makeFakeOverlay())
  fake.cursor = { x = 496, y = 500 }

  local started = controller.beginBorderResize()
  assertEqual(started.ok, true, "a grab in the gap starts a resize session")

  fake.cursor = { x = 506, y = 500 }
  repeatTimerOf(fake).cb()

  local message = lastLayoutDispatch(fake)
  assertEqual(message ~= nil, true, "dragging the grabbed edge dispatches a resize")
  assertEqual(message:match("^resize_edge_px a right ") ~= nil, true, "the nearer window's inner edge is resized")
end

local function test_pointer_toggle_float_keeps_tiled_geometry()
  local store = testing.newStore()
  local specs = { { id = "a", active = true }, { id = "b" }, { id = "c" } }
  local _, state = recalc(store, "1", specs)

  local windows = fakeWindowsFromBoxes(state.boxes, specs)
  local fake = makeFakeHl(windows)
  _G.hl = fake

  local controller = pointer.new(store, makeFakeOverlay())
  fake.activeWindow = windows[1]
  controller.toggleFloat()

  local box = state.boxes["a"]
  local resized = false
  for _, dispatcher in ipairs(fake.dispatches) do
    if dispatcher.kind == "resize" and dispatcher.spec.x == box.w and dispatcher.spec.y == box.h then
      resized = true
    end
  end

  assertEqual(resized, true, "floating a tiled window keeps its tiled size")
end

for _, test in ipairs({
  test_keyboard_resize_moves_split_in_arrow_direction,
  test_keyboard_resize_keeps_direction_for_second_branch,
  test_vertical_resize_after_reorient,
  test_workspace_state_survives_switching,
  test_pixel_resize_changes_ratio_by_container_size,
  test_move_left_pulls_window_out_to_workspace_edge,
  test_insert_reparents_window_relative_to_drop_target,
  test_pick_resize_edge_uses_closest_controllable_edge,
  test_pick_resize_edge_requires_border_when_requested,
  test_move_message_targets_window_edge_under_cursor,
  test_move_message_projects_drop_target_after_removing_moving_top_leaf,
  test_move_message_projects_drop_target_for_nested_bottom_leaf,
  test_resize_edge_px_ignores_outer_edge_with_no_divider,
  test_resize_edge_px_ignores_outer_bottom_edge_with_no_divider,
  test_resize_edge_px_targets_divider_on_grabbed_side,
  test_pick_resize_edges_returns_corner_axes,
  test_border_zone_hit_covers_gap_around_window,
  test_content_box_matches_hyprland_insets,
  test_border_zone_hit_allows_rounded_corner_inside,
  test_border_grab_targets_nearest_window_edge,
  test_persisted_tree_restores_without_resizing,
  test_find_window_at_point_prefers_active_workspace_over_stale_hidden_workspace,
  test_window_box_reads_named_at_and_size_fields,
  test_window_box_reads_array_at_and_size_fields,
  test_window_box_returns_nil_without_geometry,
  test_projected_boxes_drops_moving_leaf_and_reproportions,
  test_insert_leaf_beside_adds_absent_moving_leaf,
  test_pointer_move_drag_dispatches_insert_on_release,
  test_pointer_writes_dropmap_handoff_during_drag,
  test_pointer_reemits_handoff_on_recalculate,
  test_pointer_toggle_float_keeps_tiled_geometry,
}) do
  test()
end

print("split-tree tests: ok")
