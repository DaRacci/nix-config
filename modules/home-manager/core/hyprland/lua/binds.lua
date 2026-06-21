local mod = "SUPER"
local workspaceCount = 10
local specialWorkspaceKey = "S"
local pixelMoveScale = 50
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
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

for direction,_ in pairs(directions) do
  local lowerName = direction:lower()
  hl.bind(mod .. " + " .. direction, hl.plugin.hy3.move_focus(lowerName))
  hl.bind(mod .. " + SHIFT + " .. direction, hl.plugin.hy3.move_window(lowerName))
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
hl.bind(mod .. " + " .. mouse.left, hl.dsp.window.drag())
hl.bind(mod .. " + " .. mouse.right, hl.dsp.window.resize())

-- ---------------------------------------------------------------------------
-- Submap: Resize
-- ---------------------------------------------------------------------------
hl.bind("ALT + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
  hl.bind("ESCAPE", hl.dsp.submap("reset"))

  hl.bind("DOWN", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { ["e"] = true })
  hl.bind("LEFT", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { ["e"] = true })
  hl.bind("RIGHT", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { ["e"] = true })
  hl.bind("UP", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { ["e"] = true })
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
