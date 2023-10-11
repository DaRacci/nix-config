{ flake, ... }:
let
  inherit (flake) inputs outputs;
in
{
  imports = [
    ./auto-upgrade.nix
    ./btrfs.nix
    ./cooler_control.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./passwords.nix
    ./persistance.nix
    ./sops.nix
    ./security.nix
    ./zram.nix
  ] ++ (builtins.attrValues outputs.nixosModules);

  users.mutableUsers = false;

  # programs.nix-index.enable = true;
  # programs.nix-index-database.comma.enable = true;

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
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "unlimited";
    }
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1048576";
    }
  ];

  programs.nix-ld.enable = true;

  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub" # Maybe copy from repo?
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
