-- Shared-state bridge between the split-tree layout and the `split-tree-overlay`
-- Wayland client.
--
-- The layout serializes a "handoff" describing the active drag: the projected-box
-- drop map (computed once per tree change), the source window rect and the visual
-- style. The Rust client watches this file, samples the cursor over Hyprland IPC and
-- renders the preview. See `pkgs/split-tree-overlay`.

local M = {}

local function runtimeDir()
  return os.getenv("XDG_RUNTIME_DIR") or "/tmp"
end

local function instanceId()
  return os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "default"
end

function M.statePath()
  return runtimeDir() .. "/split-tree-overlay-" .. instanceId() .. ".json"
end

function M.lockPath()
  return runtimeDir() .. "/split-tree-overlay-" .. instanceId() .. ".lock"
end

local escapes = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function escapeString(value)
  return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(char)
    return escapes[char] or string.format("\\u%04x", char:byte())
  end) .. '"'
end

local function encodeNumber(value)
  if value ~= value or value == math.huge or value == -math.huge then
    return "0"
  end

  if value == math.floor(value) then
    return string.format("%d", value)
  end

  return string.format("%.6f", value)
end

local function isArray(value)
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    count = count + 1
  end

  return count == #value
end

local encode

encode = function(value)
  local kind = type(value)

  if value == nil then
    return "null"
  elseif kind == "boolean" then
    return value and "true" or "false"
  elseif kind == "number" then
    return encodeNumber(value)
  elseif kind == "string" then
    return escapeString(value)
  elseif kind == "table" then
    if isArray(value) then
      local parts = {}
      for index = 1, #value do
        parts[index] = encode(value[index])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end

    local parts = {}
    for key, entry in pairs(value) do
      parts[#parts + 1] = escapeString(key) .. ":" .. encode(entry)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end

  return "null"
end

function M.encode(value)
  return encode(value)
end

function M.write(path, payload)
  local handle = io.open(path, "w")
  if not handle then
    return false
  end

  handle:write(payload)
  handle:close()
  return true
end

-- Controller bound to one state path. `write` skips writes when the encoded payload is unchanged,
-- so a drag that does not alter the tree does not touch the file.
function M.new(path)
  path = path or M.statePath()
  local last = nil
  local api = {}

  function api.write(state)
    local payload = encode(state)
    if payload == last then
      return
    end

    last = payload
    M.write(path, payload)
  end

  function api.hide()
    api.write({ dragging = false })
  end

  return api
end

return M
