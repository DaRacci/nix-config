{
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    "${modulesPath}/profiles/headless.nix"

    ./reduce.nix
  ];

  services = {
    getty.autologinUser = "root";

    metrics = {
      enable = true;
      upgradeStatus = {
        enable = true;
        uptimeKuma.enable = true;
      };
      hacompanion = {
        enable = true;
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
