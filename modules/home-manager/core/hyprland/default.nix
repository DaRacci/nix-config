_: {
  imports = [
    ./noctalia.nix
    ./permission.nix
    ./slideIn.nix
    ./windowRule.nix
    ./input.nix
    ./lua.nix
    ./workspaces.nix
  ];

  options.wayland.windowManager.hyprland = { };

  config = { };
}
