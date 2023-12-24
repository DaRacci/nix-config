{ config, lib, ... }: with lib; let cfg = config.host; in {
  imports = [
    ./device.nix
    ./drive.nix
    ./persistence.nix
  ];

  options.host = {
    name = mkOption {
      type = types.str;
      default = throw "host.name is required";
      description = "The name of the host.";
    };
  };

  config = {
    networking.hostName = cfg.name;
    system.name = cfg.name;
  };
}
