{ pkgs, ... }: {
  imports = [
    ./hm-helper.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./passwords.nix
    ./sops.nix
    ./security.nix
    ./zram.nix
  ];

  environment = {
    enableAllTerminfo = true;
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };

  hardware.enableRedistributableFirmware = true;

  programs.nix-ld.enable = true;

  system.activationScripts.report-changes = /*sh*/ ''
    LINKS=($(ls -dv /nix/var/nix/profiles/system-*-link))
    if [ $(echo $LINKS | wc -w) -gt 1 ]; then
      NEW=$(readlink -f ''${LINKS[-1]})
      CURRENT=$(readlink -f ''${LINKS[-2]})

      ${pkgs.nvd}/bin/nvd diff $PREVIOUS $NEW
    fi
  '';

  time = {
    hardwareClockInLocalTime = true;
  };
}
