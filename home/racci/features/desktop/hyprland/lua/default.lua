hl.config({
  debug = {
    disable_logs = true,
  },

  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
    enforce_permissions = true,
  },

  general = {
    resize_on_border = true,
    no_focus_fallback = true,
    layout = "hy3",
    allow_tearing = true,
    snap = { enabled = true },
  },

  misc = {
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
    focus_on_activate = true,
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,
    allow_session_lock_restore = true,
    initial_workspace_tracking = 1,
    middle_click_paste = false,
  },
})

for _, ns in ipairs({ "walker", "selection", "overview", "anyrun", "gauntlet", "indicator.*", "osk", "hyprpicker", "noanim" }) do
  hl.layer_rule({
    name = "no-anim-" .. ns,
    match = { namespace = ns },
    no_anim = true
  })
end

hl.layer_rule({ name = "sideleft-slide", match = { namespace = "sideleft.*" }, animation = "slide top" })
hl.layer_rule({ name = "sideright-slide", match = { namespace = "sideright.*" }, animation = "slide top" })
hl.layer_rule({ name = "session-blur", match = { namespace = "session" }, blur = true })

for _, ns in ipairs({ "bar", "corner.*", "dock", "indicator.*", "indicator*", "overview", "cheatsheet", "sideright", "sideleft", "osk" }) do
  hl.layer_rule({
    name = "blur-" .. ns,
    match = { namespace = ns },
    blur = true
  })
  hl.layer_rule({
    name = "ignore-alpha-" .. ns,
    match = { namespace = ns },
    ignore_alpha = 0.6
  })
end
