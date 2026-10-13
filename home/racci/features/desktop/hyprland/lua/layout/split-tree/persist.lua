-- Persist the split-tree layout across Hyprland config reloads.
--
-- A reload recreates the Lua state, so without this the layout rebuilds a default tree and resizes
-- the existing windows on the first pass. Saving the tree (structure + ratios) and restoring it
-- before Hyprland lays out means place() reproduces the current geometry instead of enforcing
-- default proportions.
--
-- The file is keyed by the Hyprland instance signature, so it survives config reloads (same
-- process) but a fresh session starts clean.

local M = {}

local function runtimeDir()
  return os.getenv("XDG_RUNTIME_DIR") or "/tmp"
end

local function instanceId()
  return os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "default"
end

function M.path()
  return runtimeDir() .. "/split-tree-layout-" .. instanceId() .. ".lua"
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

function M.deserialize(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end

  local loader = load or loadstring
  if not loader then
    return nil
  end

  local chunk = loader(text)
  if not chunk then
    return nil
  end

  local ok, value = pcall(chunk)
  if not ok or type(value) ~= "table" then
    return nil
  end

  return value
end

-- Controller bound to one path. `save` skips writes when the snapshot is unchanged.
function M.new(path)
  path = path or M.path()
  local last = nil
  local api = {}

  function api.save(snapshot)
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
