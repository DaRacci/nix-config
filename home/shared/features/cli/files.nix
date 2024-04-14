{ pkgs, ... }: {
  programs.xplr = {
    enable = true;
    package = pkgs.xplr;
    extraConfig = ''
      local home = os.getenv("HOME")
      local xpm_path = home .. "/.local/share/xplr/dtomvan/xpm.xplr"
      local xpm_url = "https://github.com/dtomvan/xpm.xplr"

      package.path = package.path
      .. ";"
      .. xpm_path
      .. "/?.lua;"
      .. xpm_path
      .. "/?/init.lua"

      os.execute(string.format(
        "[ -e '%s' ] || git clone '%s' '%s'",
        xpm_path,
        xpm_url,
        xpm_path
      ))

      require("xpm").setup({
        plugins = {
          'dtomvan/xpm.xplr',
          'sayanarijit/map.xplr',
          'dtomvan/paste-rs.xplr',
          'sayanarijit/trash-cli.xplr',
          'sayanarijit/zoxide.xplr',

        },
        auto_install = true,
        auto_cleanup = true,
      })

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

      xplr.config.modes.builtin.default.key_bindings.on_key.T = {
        help = "tere nav",
        messages = {
          { BashExec0 = [["$XPLR" -m 'ChangeDirectory: %q' "$(tere)"]] },
        },
      }
    '';
  };
}
