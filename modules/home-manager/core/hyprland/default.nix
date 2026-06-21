_: {
  imports = [
    ./noctalia.nix
    ./permission.nix
    ./slideIn.nix
    ./windowRule.nix
    ./input.nix
    ./lua.nix
  ];

  options.wayland.windowManager.hyprland = { };

  config = { };
}
