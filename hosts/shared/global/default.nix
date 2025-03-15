{ pkgs, lib, ... }:
{
  imports = [
    ./generators.nix
    ./hm-helper.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./sops.nix
    ./security.nix
    ./time.nix
    ./zram.nix
  ];

  environment = {
    enableAllTerminfo = false;
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };

  hardware.enableRedistributableFirmware = true;

  services.dbus.implementation = "broker";

  system.activationScripts.report-changes = ''
    LINKS=($(ls -dv /nix/var/nix/profiles/system-*-link))
    if [ $(echo $LINKS | wc -w) -gt 1 ]; then
      NEW=$(readlink -f ''${LINKS[-1]})
      CURRENT=$(readlink -f ''${LINKS[-2]})

      ${lib.getExe pkgs.nvd} diff $PREVIOUS $NEW
    fi
  '';
}
