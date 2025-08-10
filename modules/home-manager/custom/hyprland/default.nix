_: {
  imports = [
    ./bind.nix
    ./permission.nix
    ./slideIn.nix
    ./windowRule.nix
  ];

  options.wayland.windowManager.hyprland = { };

  config = { };
}
