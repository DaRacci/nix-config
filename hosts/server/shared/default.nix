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
      upgradeStatus.uptimeKuma.enable = true;
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
