hl.bind("CTRL + ALT + SPACE", hl.dsp.exec_cmd("vicinae toggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("vicinae vicinae://launch/clipboard/history"))

hl.layer_rule({
  name = "vicinae-blur",
  match = { namespace = "vicinae" },
  blur = true,
  ignore_alpha = 0
})
hl.layer_rule({
  name = "vicinae-no-animation",
  match = { namespace = "vicinae" },
  no_anim = true
})
