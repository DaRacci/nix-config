hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("fluentDecel", {
  type = "bezier",
  points = {
    { 0,   0.2 },
    { 0.4, 1 },
  }
})
hl.curve("easeOutCirc", {
  type = "bezier",
  points = {
    { 0,    0.55 },
    { 0.45, 1 },
  }
})
hl.curve("easeOutCubic", {
  type = "bezier",
  points = {
    { 0.33, 1 },
    { 0.68, 1 },
  },
})
hl.curve("easeInOutSine", {
  type = "bezier",
  points = {
    { 0.37, 0 },
    { 0.63, 1 },
  },
})
hl.curve("springy", {
  type = "spring",
  mass = 1,
  stiffness = 65,
  dampening = 14,
})

-- Windows
hl.animation({
  leaf = "windowsIn",
  enabled = true,
  speed = 3,
  bezier = "easeOutCubic",
  style = "popin 30"
})
hl.animation({
  leaf = "windowsOut",
  enabled = true,
  speed = 3,
  bezier = "fluentDecel",
  style = "popin 70"
})
hl.animation({
  leaf = "windowsMove",
  enabled = true,
  speed = 2,
  bezier = "easeInOutSine",
  style = "slide"
})

-- Fades
hl.animation({
  leaf = "fadeIn",
  enabled = true,
  speed = 3,
  bezier = "easeOutCubic"
})
hl.animation({
  leaf = "fadeOut",
  enabled = true,
  speed = 2,
  bezier = "easeOutCubic"
})
hl.animation({
  leaf = "fadeSwitch",
  enabled = false,
  speed = 1,
  bezier = "easeOutCirc"
})
hl.animation({
  leaf = "fadeShadow",
  enabled = true,
  speed = 10,
  bezier = "easeOutCirc"
})
hl.animation({
  leaf = "fadeDim",
  enabled = true,
  speed = 4,
  bezier = "fluentDecel"
})

-- Borders
hl.animation({
  leaf = "border",
  enabled = true,
  speed = 2.7,
  bezier = "easeOutCirc"
})
hl.animation({
  leaf = "borderangle",
  enabled = true,
  speed = 30,
  bezier = "fluentDecel",
  style = "once"
})

-- Workspaces
hl.animation({
  leaf = "workspaces",
  enabled = true,
  speed = 4,
  bezier = "easeOutCubic",
  style = "fade"
})

hl.animation({
  leaf = "specialWorkspace",
  enabled = true,
  speed = 2,
  bezier = "easeOutCubic",
  style = "slidevert"
})
