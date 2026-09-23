hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    gaps_workspaces = 50,
    border_size = 2,
  },

  decoration = {
    active_opacity = 1,
    inactive_opacity = 1,
    fullscreen_opacity = 1,
    rounding = 20,
    rounding_power = 2,

    blur = {
      enabled = true,
      xray = true,
      special = true,
      new_optimizations = true,
      size = 3,
      passes = 2,
      vibrancy = 0.1696,
      brightness = 1,
      noise = 0.01,
      contrast = 1,
      popups = false,
    },

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      offset = { 0, 2 },
    },

    dim_inactive = false,
    dim_strength = 0.1,
    dim_special = 0,
  },
})

hl.window_rule({
  name = "pin-border",
  match = { pin = true },
  border_color = "rgba(ffabf1AA) rgba(ffabf177)"
})
