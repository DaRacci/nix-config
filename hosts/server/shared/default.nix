{
  flake,
  config,
  lib,
  ...
}:
{
  imports = [ "${flake}/hosts/shared/optional/tailscale.nix" ];

  services = {
    getty.autologinUser = "root";
    resolved.enable = lib.mkForce false;
    journald.extraConfig = ''
      SystemMaxUse=256M
    '';
  };

  nix = {
    distributedBuilds = true;
    buildMachines = lib.mkIf (config.system.name != "nixserv") [
      {
        hostName = flake.nixosConfigurations.nixserv.config.system.name;
        system = "x86_64-linux";
        protocol = "ssh-ng";
        sshUser = "builder";
        sshKey = config.sops.secrets.SSH_PRIVATE_KEY.path;
        supportedFeatures = [
          "kvm"
          "nixos-test"
          "big-parallel"
          "benchmark"
        ];
      }
    ];
  };
}
