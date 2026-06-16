_: {
  imports = [
    ./bind.nix
    ./noctalia.nix
    ./permission.nix
    ./slideIn.nix
    ./windowRule.nix
  ];

  options.wayland.windowManager.hyprland = { };

  config = { };
}
