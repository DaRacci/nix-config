{ config, lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) str nullOr;

  cfg = config.host;
in
{
  imports = [
    ./device.nix
    ./persistence.nix
  ];

  options.host = {
    name = mkOption {
      type = str;
      description = "The name of the host.";
    };

    system = mkOption {
      type = nullOr str;
      description = "The system architecture.";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "host.name is required.";
      }
      {
        assertion = cfg.system != null;
        message = "host.system is required.";
      }
    ];

    networking.hostName = cfg.name;
    system.name = cfg.name;
  };
}
