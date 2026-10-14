local SplitTree = require("layout.split-tree")

local mod = "SUPER"
local workspaceCount = 10
local specialWorkspaceKey = "S"
local directions = {
  LEFT = { relative = "-", relativeNumber = -1, pixelAxis = "x" },
  RIGHT = { relative = "+", relativeNumber = 1, pixelAxis = "x" },
  UP = { relative = "-", relativeNumber = -1, pixelAxis = "y" },
  DOWN = { relative = "+", relativeNumber = 1, pixelAxis = "y" },
}
local mouse = {
  left = "mouse:272",
  middle = "mouse:274",
  right = "mouse:273",
}

-- ---------------------------------------------------------------------------
-- Window Management
-- ---------------------------------------------------------------------------
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SPACE", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + SPACE", SplitTree.toggleFloat)

for direction,_ in pairs(directions) do
  local lowerName = direction:lower()
  hl.bind(mod .. " + " .. direction, hl.dsp.focus({ direction = lowerName }))
  hl.bind(mod .. " + SHIFT + " .. direction, hl.dsp.layout("move " .. lowerName))
end

-- ---------------------------------------------------------------------------
-- Workspace Management
-- ---------------------------------------------------------------------------
hl.bind("SUPER + SHIFT + " .. specialWorkspaceKey, hl.dsp.window.move({ workspace = "special" }))
hl.bind("SUPER + " .. specialWorkspaceKey, hl.dsp.workspace.toggle_special(""))

for i = 1, workspaceCount do
  local trueIndex = i % 10 -- Map 10 to 0 for keybinds
  hl.bind(mod .. " + " .. trueIndex, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mod .. " + SHIFT + " .. trueIndex, hl.dsp.window.move({ workspace = tostring(i) }))
end

hl.bind(mod .. " + ALT + LEFT", hl.dsp.workspace.move({ monitor = "-1" }))
hl.bind(mod .. " + ALT + RIGHT", hl.dsp.workspace.move({ monitor = "+1" }))

-- ---------------------------------------------------------------------------
-- Mouse Bindings
-- ---------------------------------------------------------------------------
hl.bind(mod .. " + " .. mouse.left, SplitTree.beginMouseDrag, { mouse = true })
hl.bind(mod .. " + " .. mouse.left, SplitTree.endMouseDrag, { mouse = true, release = true })
hl.bind(mod .. " + " .. mouse.right, SplitTree.beginMouseResize, { mouse = true })
hl.bind(mod .. " + " .. mouse.right, SplitTree.endMouseResize, { mouse = true, release = true })
hl.bind(mouse.left, SplitTree.beginBorderResize, { auto_consuming = true, mouse = true })
hl.bind(mouse.left, SplitTree.endBorderResize, { auto_consuming = true, mouse = true, release = true })

-- ---------------------------------------------------------------------------
-- Submap: Resize
-- ---------------------------------------------------------------------------
hl.bind("ALT + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
  hl.bind("ESCAPE", hl.dsp.submap("reset"))

  for direction ,_ in pairs(directions) do
    local lowerName = direction:lower()
    hl.bind(direction, hl.dsp.layout("resize " .. lowerName))
  end
end)

-- ---------------------------------------------------------------------------
-- System
-- ---------------------------------------------------------------------------
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd([[
  sh -c '@zenity@ --question --title="Exit Hyprland?" --text="Are you sure you want to exit Hyprland?" --ok-label="Exit" --cancel-label="Cancel" && @hyprshutdown@ --post-cmd "uwsm exit"'
]]))

-- ---------------------------------------------------------------------------
-- Media
-- ---------------------------------------------------------------------------
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("@playerctl@ play-pause"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("@playerctl@ play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("@playerctl@ next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("@playerctl@ previous"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("@wpctl@ set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("@wpctl@ set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("@wpctl@ set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("@wpctl@ set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- ---------------------------------------------------------------------------
-- Applications
-- ---------------------------------------------------------------------------
local applicationBinds = @applicationBinds@ -- format: [{ bind = "SUPER+X", command = "/usr/bin/this --with args" }]
for _, app in ipairs(applicationBinds) do
  hl.bind(app.bind, hl.dsp.exec_cmd("@uwsmApp@ -s a -- " .. app.command))
end
