{ pkgs, lib, ... }: {
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

  documentation.man.enable = false;

  system.activationScripts.report-changes = ''
    PATH=$PATH:${lib.makeBinPath [ pkgs.nvd pkgs.nix ]}
    nvd diff $(ls -dv /nix/var/nix/profiles/system-*-link | tail -2)
  '';

  time = {
    hardwareClockInLocalTime = true;
  };
}
