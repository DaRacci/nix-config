{ flake, ... }:
let
  inherit (flake) inputs outputs;
in
{
  imports = [
    inputs.nur.hmModules.nur
    inputs.sops-nix.homeManagerModule
    inputs.anyrun.homeManagerModules.default
  ] ++ [
    ./dynamic-linker.nix
    ./nix.nix
    ./sops.nix
    ./xdg.nix
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
