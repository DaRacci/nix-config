{ inputs, outputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager

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

  # Increase open file limit for sudoers
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];
}
