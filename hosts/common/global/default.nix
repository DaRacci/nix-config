{ flake, ... }:
let
  inherit (flake) outputs;
in
{
  imports = [
    ./appimage.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./passwords.nix
    ./sops.nix
    ./security.nix
    ./zram.nix
  ] ++ (builtins.attrValues outputs.nixosModules);

  # programs.nix-index.enable = true;
  # programs.nix-index-database.comma.enable = true;

  environment = {
    enableAllTerminfo = true;
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  hardware.enableRedistributableFirmware = true;

  programs.nix-ld.enable = true;
}
