{ outputs, ... }: {
  imports = [
    ./nix.nix
    ./xdg.nix
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
