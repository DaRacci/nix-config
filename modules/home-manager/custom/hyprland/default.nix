_: {
  imports = [
    ./bind.nix
    ./slideIn.nix
    ./windowRule.nix
  ];

  options.wayland.windowManager.hyprland = { };

  config = { };
}
