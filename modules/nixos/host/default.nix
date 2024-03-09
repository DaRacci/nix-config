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

    system = mkOption {
      type = types.str;
      default = throw "host.system is required";
      description = "The system type.";
    };
  };

  config = {
    networking.hostName = cfg.name;
    system.name = cfg.name;
  };
}
