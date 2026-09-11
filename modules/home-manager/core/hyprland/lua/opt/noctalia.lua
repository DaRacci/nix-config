hl.layer_rule({
  name = "noctalia-blur",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd)$",
  },
  blur = true,
  ignore_alpha = 0.5,
  blur_popups = true,
})

