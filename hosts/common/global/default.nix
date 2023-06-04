{ inputs, outputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    # inputs.nix-index-database.nixosModules.nix-index

    # ./auto-upgrade.nix
    ./locale.nix
    ./nix.nix
    # ./openssh.nix
    ./passwords.nix
  ] ++ (builtins.attrValues outputs.nixosModules);

  # programs.nix-index.enable = true;
  # programs.nix-index-database.comma.enable = true;
  programs.fuse.userAllowOther = true;
  home-manager.extraSpecialArgs = { inherit inputs outputs; };

  environment.enableAllTerminfo = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  hardware.enableRedistributableFirmware = true;
}
