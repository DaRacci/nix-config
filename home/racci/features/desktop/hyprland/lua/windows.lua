require("helpers.workspaces")
require("helpers.windows")
require("tags")

ApplyToTag("corner-pinned", Tags.pictureInPicture, {
  pin = true,
  float = true,
  keep_aspect_ratio = true,
  opacity = "1.0",
  size = { "monitor_w * 0.25", "monitor_h * 0.25" },
  move = { "monitor_w * 0.73", "monitor_h * 0.72" },
})

ApplyToTag("popup", Tags.diaglogueModal, {
  float = true,
  center = true,
  pin = true,
  stay_focused = true,
})

ApplyToTag("popup", Tags.developmentUtility, {
  float = true
})

ApplyToTag("popout", Tags.child, {
  float = true,
})

ApplyToTag("game", Tags.game, {
  content = "game",
  idle_inhibit = "always",
  immediate = true,
  allows_input = true,
  no_blur = true,
  render_unfocused = true,
  suppress_event = "maximize",
  tile = false,
  fullscreen = true,
  float = false,
})

ApplyToTag("undecorate", Tags.contextMenu, {
  float = true,
  no_blur = true,
  border_size = 0,
  no_shadow = true,
})

ApplyToTag("hide-screenshare", Tags.sensitive, {
  no_screen_share = true
})

ApplyToTag("align-to-bar", Tags.barDropdown, {
  float = true,
  size = { "window_w * 0.33", "window_h * 0.33" },
  move = { "monitor_w * 0.63", "67" },
})

ApplyToTag("shadow-realm", Tags.silentBullshit, {
  workspace = NamedWorkspaces.shadowRealm,
  float = true,
  pin = true,
  no_focus = true,
  no_blur = true,
  no_shadow = true,
  border_size = 0,
  opacity = "0.0",
})
