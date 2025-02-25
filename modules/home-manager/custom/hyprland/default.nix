_: {
  imports = [
    ./bind.nix
    ./windowRule.nix
  ];

  options.wayland.windowManager.hyprland = { };

  config = { };
}
