local M = { }

---@param t1 table
---@param t2? table
---@return table
local function merge_tables(t1, t2)
  if t2 == nil then
    return t1
  end

  local merged = {}
  for k, v in pairs(t1) do
    merged[k] = v
  end
  for k, v in pairs(t2) do
    merged[k] = v
  end

  return merged
end

---@param pattern string The regex pattern to escape.
---@param escape? boolean Whether to escape the regex pattern (default: true).
---@return string
local function regex(pattern, escape)
  escape = escape == nil and true or escape
  if escape then
    pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  end

  return "^((?i)" .. pattern .. ")$"
end

--- @param class_name string The class name of the window to match.
--- @param extProp? table A table of additional properties to merge with the match.
--- @param escapeRegex? boolean Whether to escape the regex pattern (default: true).
--- @return table A table containing the match and any additional properties.
function M.Class(class_name, extProp, escapeRegex)
  local match = merge_tables({ class = regex(class_name, escapeRegex) }, extProp)
  return match
end

--- @param title_name string The title name of the window to match.
--- @param extProp? table<string, string|boolean|integer> A table of additional properties to merge with the match.
--- @param escapeRegex? boolean Whether to escape the regex pattern (default: true).
--- @return table A table containing the match and any additional properties.
function M.Title(title_name, extProp, escapeRegex)
  local match = merge_tables({ title = regex(title_name, escapeRegex) }, extProp)
  return match
end

--- @param tag_name string The tag name to assign to the matched windows.
--- @param matches table<integer, table> A table of match tables to apply the tag to.
--- @return table<integer, HL.WindowRule> A table of window rules that assign the tag to the matched windows.
function M.TagByMatch(tag_name, matches)
  local hlRules = {}
  for _, match in ipairs(matches) do
    hlRules[#hlRules + 1] = hl.window_rule({
      match = match,
      tag = tag_name
    })
  end

  return hlRules
end

--- @param namePrefix string The prefix to use for the rule name.
--- @param obj table<string, string> A table containing the type and value for the match.
--- @return table<integer, HL.WindowRule> A table containing the rule name and match.
function M.ToWindowRule(namePrefix, obj)
  local type = obj.type
  local value = obj.value
  local pattern = "^(" .. value .. ")$"

  local formattedName = value:gsub(" ", "-"):gsub("_", "-"):lower()
  local name = namePrefix .. "-" .. formattedName

  return {
    name = name,
    match = { [type] = pattern },
  }
end

--- @param namePrefix string The prefix to use for the rule name.
--- @param rules table A table of rule objects to register.
--- @param extraProperties table<string, string|boolean|integer> A table of additional properties to merge with each rule.
 ---@return table<integer, HL.WindowRule> A table of window rules that assign the tag to the matched windows.
function M.RegisterWindowRules(namePrefix, rules, extraProperties)
  local hlRules = {}
  for _, obj in ipairs(rules) do
    local rule = M.ToWindowRule(namePrefix, obj)
    rule = merge_tables(rule, extraProperties)
    hlRules[#hlRules + 1] = hl.window_rule(rule)
  end

  return hlRules
end

-- Apply a property to multiple tagged windows
--- @param namePrefix string The prefix to use for the rule name.
--- @param tagName string The tag name to apply the properties to.
--- @param properties table<string, string|boolean|integer|table> A table of properties to apply to the tagged windows.
--- @return HL.WindowRule
function M.ApplyToTag(namePrefix, tagName, properties)
  local rule = merge_tables({
    name = namePrefix .. "-" .. tagName,
    match = { tag = tagName }
  }, properties)

  return hl.window_rule(rule)
end

_G.Class = M.Class
_G.Title = M.Title
_G.TagByMatch = M.TagByMatch
_G.ToWindowRule = M.ToWindowRule
_G.RegisterWindowRules = M.RegisterWindowRules
_G.ApplyToTag = M.ApplyToTag

return M
