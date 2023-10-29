{ flake, ... }:
let
  inherit (flake) inputs outputs;
in
{
  imports = [
    inputs.nur.hmModules.nur
    inputs.sops-nix.homeManagerModule
    inputs.nix-colours.homeManagerModules.default
  ] ++ [
    ./nix.nix
    ./sops.nix
    ./xdg.nix
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
