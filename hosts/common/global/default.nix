{ inputs, outputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    # inputs.impermanence.nixosModules.home-manager.impermanence

    ./auto-upgrade.nix
    ./locale.nix
    ./nix.nix
    # ./openssh.nix
  ] ++ (builtins.attrValues outputs.nixosModules);

  home-manager.extraSpecialArgs = { inherit inputs outputs; };

  environment.enableAllTerminfo = true;

  hardware.enableRedistributableFirmware = true;
}