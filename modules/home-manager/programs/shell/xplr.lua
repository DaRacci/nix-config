local function stat(node)
  return xplr.util.to_yaml(xplr.util.node(node.absolute_path))
end

local function read(path, height)
  local p = io.open(path)

  if p == nil then
    return nil
  end

  local i = 0
  local res = ""
  for line in p:lines() do
    if line:match("[^ -~\n\t]") then
      p:close()
      return
    end

    res = res .. line .. "\n"
    if i == height then
      break
    end
    i = i + 1
  end
  p:close()

  return res
end

xplr.fn.custom.preview_pane = {}
xplr.fn.custom.preview_pane.render = function(ctx)
  local title = nil
  local body = ""
  local n = ctx.app.focused_node
  if n and n.canonical then
    n = n.canonical
  end

  if n then
    title = { format = n.absolute_path, style = xplr.util.lscolor(n.absolute_path) }
    if n.is_file then
      body = read(n.absolute_path, ctx.layout_size.height) or stat(n)
    else
      body = stat(n)
    end
  end

  return { CustomParagraph = { ui = { title = title }, body = body } }
end

local preview_pane = { Dynamic = "custom.preview_pane.render" }
local split_preview = {
  Horizontal = {
    config = {
      constraints = {
        { Percentage = 60 },
        { Percentage = 40 },
      },
    },
    splits = {
      "Table",
      preview_pane,
    },
  },
}

xplr.config.layouts.builtin.default =
  xplr.util.layout_replace(xplr.config.layouts.builtin.default, "Table", split_preview)

xplr.config.modes.builtin.default.key_bindings.on_key["e"] = {
  help = "Open target in editor",
  messages = {
    { CallLua = "custom.edit_file" }
  },
}

xplr.fn.custom.edit_file = function(app)
  local node = app.focused_node
  if not node then
    return
  end

  local editor = os.getenv("EDITOR")
  if not editor then
    return {
      LogWarning = "No editor found, ensure $EDITOR is set"
    }
  end

  os.execute(editor .. " " .. xplr.util.shell_escape(node.absolute_path))
end

require("trash-cli").setup({
  trash_bin = "trash-put",
  trash_mode = "delete",
  trash_key = "d",

  empty_bin = "trash-empty",
  empty_mode = "delete",
  empty_key = "E",

  trash_list_bin = "trash-list",
  trash_list_selector = "fzf -m | cut -d' ' -f3-",

  restore_bin = "trash-restore",
  restore_key = "r",

  global_restore_mode = "delete",
  global_restore_key = "R"
})

require("dual-pane").setup()
require("find").setup()
require("map").setup()
require("tree-view").setup()
require("zoxide").setup()
