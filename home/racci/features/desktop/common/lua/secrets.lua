hl.window_rule({
  name = "onepassword-quick-access",
  match = { title = "^(Quick Access — 1Password)$" },
  pin = true,
  center = true,
  stay_focused = true,
  no_close_for = 250,
})

