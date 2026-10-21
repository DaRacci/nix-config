-- Persist the split-tree layout across config reloads.
-- A reload recreates the Lua state,
-- so the saved tree is restored to keep windows from reflowing to default proportions.

local M = {}

local function runtimeDir()
  local dir = os.getenv("XDG_RUNTIME_DIR")
  if not dir or dir == "" then
    return nil
  end

  return dir
end

local function instanceId()
  return os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "default"
end

-- Per-user runtime dir only.
-- No /tmp fallback (predictable path = plant/symlink risk).
function M.path()
  if _G.SPLIT_TREE_STATE_PATH then
    return _G.SPLIT_TREE_STATE_PATH
  end

  local dir = runtimeDir()
  if not dir then
    return nil
  end

  return dir .. "/split-tree-layout-" .. instanceId() .. ".lua"
end

local function serialize(value)
  local kind = type(value)

  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return "0"
    end
    return string.format("%.17g", value)
  elseif kind == "string" then
    return string.format("%q", value)
  elseif kind == "boolean" then
    return value and "true" or "false"
  elseif kind == "table" then
    local parts = {}
    for key, entry in pairs(value) do
      local encodedEntry = serialize(entry)
      if encodedEntry ~= nil then
        local encodedKey = type(key) == "number" and ("[" .. key .. "]")
          or ("[" .. string.format("%q", tostring(key)) .. "]")
        parts[#parts + 1] = encodedKey .. "=" .. encodedEntry
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end

  return nil
end

-- Encode a table as a loadable Lua chunk (`return {...}`).
function M.serialize(store)
  return "return " .. (serialize(store) or "{}")
end

-- Sandboxed text-only load with an empty environment.
function M.deserialize(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end

  local chunk = load(text, "split-tree-state", "t", {})
  if not chunk then
    return nil
  end

  local ok, value = pcall(chunk)
  if not ok or type(value) ~= "table" then
    return nil
  end

  return value
end

-- Controller bound to one path.
-- Save skips unchanged snapshots; both no-op without a path.
function M.new(path)
  path = path or M.path()
  local last = nil
  local api = {}

  function api.save(snapshot)
    if not path then
      return
    end

    local text = M.serialize(snapshot)
    if text == last then
      return
    end

    local handle = io.open(path, "w")
    if not handle then
      return
    end

    handle:write(text)
    handle:close()
    last = text
  end

  function api.load()
    if not path then
      return nil
    end

    local handle = io.open(path, "r")
    if not handle then
      return nil
    end

    local text = handle:read("a")
    handle:close()
    return M.deserialize(text)
  end

  return api
end

return M
