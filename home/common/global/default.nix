{ flake, ... }:
let
  inherit (flake) inputs outputs;
in
{
  imports = [
    inputs.nur.hmModules.nur
    inputs.sops-nix.homeManagerModule
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-colours.homeManagerModules.default
  ] ++ [
    ./audio.nix
    ./nix.nix
    ./sops.nix
    ./xdg.nix
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
