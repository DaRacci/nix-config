{
  modulesPath,
  lib,
  ...
}:
let
  inherit (lib) mkDefault;
in
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    "${modulesPath}/profiles/headless.nix"

    ./reduce.nix
  ];

  services = {
    getty.autologinUser = "root";

    metrics = {
      enable = mkDefault true;
      upgradeStatus = {
        enable = mkDefault true;
        uptimeKuma.enable = mkDefault true;
      };
      hacompanion = {
        enable = mkDefault true;
        sensor = {
          cpu_usage.enable = true;
          uptime.enable = true;
          memory.enable = true;
          load_avg.enable = true;
        };
      };
    };
  };

  proxmoxLXC = {
    manageNetwork = true;
    manageHostName = true;
  };
  networking = {
    domain = "localdomain";
  };
}
